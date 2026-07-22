"""Login, logout, refresh (with rotation + reuse detection), password
reset framework, branch switching, and device-session management.

Every outcome that matters for security (successful/failed login,
lockout, password reset, session revocation) is written to the audit
log via AuditService — this is the "audit login history" requirement,
implemented as a generic action log rather than a bespoke table.
"""

import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core import security
from app.core.config import Settings, get_settings
from app.core.exceptions import NotFoundException, UnauthorizedException, ValidationException
from app.core.logging import get_logger
from app.modules.audit.service import AuditService
from app.modules.auth.models import RefreshToken
from app.modules.auth.repository import (
    PasswordResetTokenRepository,
    RefreshTokenRepository,
    hash_token,
)
from app.modules.auth.schemas import LoginRequest, TokenResponse
from app.modules.company.models import Branch
from app.modules.company.repository import BranchRepository
from app.modules.users_roles_permissions.models import User
from app.modules.users_roles_permissions.repository import UserRepository
from app.modules.users_roles_permissions.service import UserService

logger = get_logger(__name__)


class RequestContext:
    """Everything about the caller that's worth recording, not carried on
    the JWT itself."""

    def __init__(self, ip_address: str | None, user_agent: str | None) -> None:
        self.ip_address = ip_address
        self.user_agent = user_agent


class AuthService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._user_service = UserService(session, self._settings)
        self._user_repo = UserRepository(session)
        self._refresh_repo = RefreshTokenRepository(session)
        self._reset_repo = PasswordResetTokenRepository(session)
        self._audit = AuditService(session)

    async def _issue_token_pair(
        self,
        user: User,
        *,
        branch_id: UUID | None,
        remember_me: bool,
        request: RequestContext,
        device_id: str | None,
        device_name: str | None,
    ) -> TokenResponse:
        access_token = security.create_access_token(
            str(user.id),
            company_id=str(user.company_id),
            branch_id=str(branch_id) if branch_id else None,
            settings=self._settings,
        )
        refresh_expires_delta = timedelta(
            days=self._settings.refresh_token_expire_days
            if remember_me
            else self._settings.refresh_token_expire_days_session
        )
        raw_refresh_token = security.create_refresh_token(
            str(user.id),
            company_id=str(user.company_id),
            branch_id=str(branch_id) if branch_id else None,
            settings=self._settings,
            expires_delta=refresh_expires_delta,
        )
        await self._refresh_repo.create(
            user_id=user.id,
            raw_token=raw_refresh_token,
            expires_at=datetime.now(UTC) + refresh_expires_delta,
            device_id=device_id,
            device_name=device_name,
            ip_address=request.ip_address,
            user_agent=request.user_agent,
        )
        return TokenResponse(access_token=access_token, refresh_token=raw_refresh_token)

    async def issue_initial_tokens(self, user: User, request: RequestContext) -> TokenResponse:
        """Auto-login right after the company-signup flow creates the
        owner account — the caller already proved who they are by
        providing the password used to create the account in the same
        request, so this skips the login credential check entirely."""
        await self._audit.log(
            "auth.login.success",
            company_id=user.company_id,
            user_id=user.id,
            ip_address=request.ip_address,
            user_agent=request.user_agent,
        )
        return await self._issue_token_pair(
            user,
            branch_id=user.default_branch_id,
            remember_me=True,
            request=request,
            device_id=None,
            device_name=None,
        )

    async def login(self, data: LoginRequest, request: RequestContext) -> TokenResponse:
        user = await self._user_service.get_by_email_for_login(data.email)

        if user is None:
            await self._audit.log(
                "auth.login.failed", ip_address=request.ip_address, user_agent=request.user_agent
            )
            raise UnauthorizedException("Invalid email or password")

        if self._user_service.is_locked(user):
            await self._audit.log(
                "auth.login.failed",
                company_id=user.company_id,
                user_id=user.id,
                ip_address=request.ip_address,
                user_agent=request.user_agent,
            )
            raise UnauthorizedException(
                "This account is temporarily locked due to repeated failed sign-in attempts. "
                "Try again later."
            )

        if not user.is_active or not security.verify_password(data.password, user.password_hash):
            await self._user_service.record_failed_login(user)
            await self._audit.log(
                "auth.login.failed",
                company_id=user.company_id,
                user_id=user.id,
                ip_address=request.ip_address,
                user_agent=request.user_agent,
            )
            # Commit before raising: `get_db_session` rolls back on any
            # exception, and the failed-login counter must durably
            # persist even though this request ends in a 401 — otherwise
            # account lockout can never trigger (see the "production bug
            # fix" note in CHANGELOG.md for how this was found).
            await self._session.commit()
            raise UnauthorizedException("Invalid email or password")

        await self._user_service.record_successful_login(user)
        await self._audit.log(
            "auth.login.success",
            company_id=user.company_id,
            user_id=user.id,
            ip_address=request.ip_address,
            user_agent=request.user_agent,
        )
        return await self._issue_token_pair(
            user,
            branch_id=user.default_branch_id,
            remember_me=data.remember_me,
            request=request,
            device_id=data.device_id,
            device_name=data.device_name,
        )

    async def logout(self, raw_refresh_token: str) -> None:
        token = await self._refresh_repo.get_by_token_hash(hash_token(raw_refresh_token))
        if token is not None and token.revoked_at is None:
            await self._refresh_repo.revoke(token, revoked_at=datetime.now(UTC))
            await self._audit.log("auth.logout", user_id=token.user_id)

    async def refresh(self, raw_refresh_token: str, request: RequestContext) -> TokenResponse:
        payload = security.decode_token(
            raw_refresh_token, expected_type=security.TokenType.REFRESH, settings=self._settings
        )
        token = await self._refresh_repo.get_by_token_hash(hash_token(raw_refresh_token))
        if token is None:
            raise UnauthorizedException("Invalid refresh token")

        if token.revoked_at is not None:
            # Someone is presenting a token we already rotated away from —
            # the only way that happens is if a refresh token was copied
            # (stolen) and used after the legitimate client rotated it.
            # Treat as compromise: kill every session for this user.
            logger.warning("refresh_token_reuse_detected", user_id=str(token.user_id))
            await self._refresh_repo.revoke_all_for_user(
                token.user_id, revoked_at=datetime.now(UTC)
            )
            await self._audit.log("auth.refresh_token_reuse_detected", user_id=token.user_id)
            # Commit before raising — same reasoning as login()'s
            # failed-attempt counter above: the revocation must durably
            # persist even though this request ends in a 401, otherwise
            # the stolen token (and its rotated replacement) stay valid.
            await self._session.commit()
            raise UnauthorizedException("This session is no longer valid. Please sign in again.")

        if token.expires_at < datetime.now(UTC):
            raise UnauthorizedException("This session has expired. Please sign in again.")

        user = await self._user_repo.get_by_id_unscoped(token.user_id)
        if user is None or not user.is_active:
            raise UnauthorizedException("Account is no longer active")

        now = datetime.now(UTC)
        branch_id = UUID(payload.branch_id) if payload.branch_id else None
        new_tokens = await self._issue_token_pair(
            user,
            branch_id=branch_id,
            remember_me=(token.expires_at - token.issued_at) > timedelta(days=2),
            request=request,
            device_id=token.device_id,
            device_name=token.device_name,
        )
        await self._refresh_repo.revoke(token, revoked_at=now)
        new_token_row = await self._refresh_repo.get_by_token_hash(
            hash_token(new_tokens.refresh_token)
        )
        if new_token_row is not None:
            token.replaced_by_token_id = new_token_row.id
            await self._session.flush()
        return new_tokens

    async def forgot_password(self, email: str) -> None:
        """Always succeeds from the caller's point of view — never
        reveals whether the email is registered (SPRINT0.md §16)."""
        user = await self._user_service.get_by_email_for_login(email)
        if user is None:
            return

        raw_token = secrets.token_urlsafe(32)
        expires_at = datetime.now(UTC) + timedelta(hours=1)
        await self._reset_repo.create(user_id=user.id, raw_token=raw_token, expires_at=expires_at)
        await self._audit.log(
            "auth.password_reset_requested", company_id=user.company_id, user_id=user.id
        )

        # No notifications module exists yet (out of scope this sprint —
        # see SPRINT0.md §26 Sprint 12). Logging the raw token is a
        # deliberate, temporary stand-in so the reset flow is testable
        # end-to-end; it must be replaced by an actual email/SMS send
        # before this ships to real users. Tracked as a known issue.
        logger.info(
            "password_reset_token_issued_no_delivery_channel_yet",
            user_id=str(user.id),
            reset_token=raw_token,
        )

    async def reset_password(self, raw_token: str, new_password: str) -> None:
        token = await self._reset_repo.get_by_token_hash(hash_token(raw_token))
        if token is None or token.used_at is not None or token.expires_at < datetime.now(UTC):
            raise ValidationException("This password reset link is invalid or has expired")

        user = await self._user_repo.get_by_id_unscoped(token.user_id)
        if user is None:
            raise NotFoundException("User not found")

        user.password_hash = security.hash_password(new_password)
        user.must_change_password = False
        user.version += 1
        await self._reset_repo.mark_used(token, used_at=datetime.now(UTC))
        await self._refresh_repo.revoke_all_for_user(user.id, revoked_at=datetime.now(UTC))
        await self._session.flush()
        await self._audit.log(
            "auth.password_reset_completed", company_id=user.company_id, user_id=user.id
        )

    async def change_password(self, user: User, current_password: str, new_password: str) -> None:
        if not security.verify_password(current_password, user.password_hash):
            raise ValidationException("Current password is incorrect", field="current_password")
        user.password_hash = security.hash_password(new_password)
        user.version += 1
        await self._session.flush()
        await self._audit.log("auth.password_changed", company_id=user.company_id, user_id=user.id)

    async def switch_branch(self, user: User, target_branch_id: UUID) -> str:
        assigned = await self._user_repo.get_assigned_branch_ids(user.id)
        if target_branch_id not in assigned:
            raise ValidationException("You are not assigned to this branch", field="branch_id")
        return security.create_access_token(
            str(user.id),
            company_id=str(user.company_id),
            branch_id=str(target_branch_id),
            settings=self._settings,
        )

    async def list_my_branches(self, user: User) -> list[Branch]:
        """The branches *this* user is assigned to — deliberately not
        gated behind the `branches.read` admin permission. Every
        authenticated user needs this to pick a branch at login/switch
        time regardless of role (a Cashier can't manage branches but
        must still be able to see and select their own)."""
        branch_repo = BranchRepository(self._session)
        assigned_ids = await self._user_repo.get_assigned_branch_ids(user.id)
        branches = []
        for branch_id in assigned_ids:
            branch = await branch_repo.get_by_id(user.company_id, branch_id)
            if branch is not None:
                branches.append(branch)
        return branches

    async def list_sessions(self, user_id: UUID) -> list[RefreshToken]:
        return await self._refresh_repo.list_active_for_user(user_id)

    async def revoke_session(self, user_id: UUID, session_id: UUID) -> None:
        for token in await self._refresh_repo.list_active_for_user(user_id):
            if token.id == session_id:
                await self._refresh_repo.revoke(token, revoked_at=datetime.now(UTC))
                return
        raise NotFoundException("Session not found")
