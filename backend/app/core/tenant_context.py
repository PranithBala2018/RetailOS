"""Request-scoped tenant/actor context.

Per SPRINT0.md §15 and docs/adr/0003: this is the plumbing point a future
`SET LOCAL app.current_company_id` (once RLS is enabled in Sprint 3)
will hook into. For now it's read by services to enforce application-
layer tenant isolation — every repository call for a company-scoped
table takes the `company_id` from here, never from a client-supplied
request field.
"""

from contextvars import ContextVar
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True, slots=True)
class TenantContext:
    user_id: UUID
    company_id: UUID
    branch_id: UUID | None


_tenant_context: ContextVar[TenantContext | None] = ContextVar("tenant_context", default=None)


def set_tenant_context(context: TenantContext) -> None:
    _tenant_context.set(context)


def get_tenant_context() -> TenantContext:
    context = _tenant_context.get()
    if context is None:
        raise RuntimeError(
            "get_tenant_context() called outside an authenticated request — "
            "this is a bug in the calling code, not a runtime user error."
        )
    return context


def get_tenant_context_or_none() -> TenantContext | None:
    return _tenant_context.get()
