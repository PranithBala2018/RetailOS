from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import RefreshToken


async def test_refresh_issues_a_new_token_pair(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": signed_up_owner["refresh_token"]}
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["access_token"]
    assert data["refresh_token"] != signed_up_owner["refresh_token"]


async def test_refreshed_access_token_works_against_a_protected_endpoint(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    refreshed = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": signed_up_owner["refresh_token"]}
    )
    new_access_token = refreshed.json()["data"]["access_token"]

    response = await client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {new_access_token}"}
    )
    assert response.status_code == 200


async def test_reusing_a_rotated_refresh_token_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    original_refresh_token = signed_up_owner["refresh_token"]

    first = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": original_refresh_token}
    )
    assert first.status_code == 200

    # The original token was rotated away by the first refresh — presenting
    # it again must look like theft, not a harmless retry.
    second = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": original_refresh_token}
    )
    assert second.status_code == 401


async def test_refresh_token_reuse_revocation_persists_despite_the_request_ending_in_401(
    client: AsyncClient, signed_up_owner: dict, db_session: AsyncSession
) -> None:
    """Regression test for a production bug: `refresh()` calls
    `revoke_all_for_user(...)` on detected reuse, then raises
    `UnauthorizedException` right after — without an explicit commit in
    between, `get_db_session`'s rollback-on-exception undid the
    revocation before it ever reached the database. Asserts directly via
    the DB that every session for the user is actually revoked, not just
    via the eventual "the old token doesn't work anymore" behavior other
    tests check."""
    original_refresh_token = signed_up_owner["refresh_token"]

    first = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": original_refresh_token}
    )
    assert first.status_code == 200

    # Reuse the original (already-rotated-away) token to trigger
    # compromise detection.
    await client.post("/api/v1/auth/refresh", json={"refresh_token": original_refresh_token})

    tokens = (
        (
            await db_session.execute(
                select(RefreshToken).where(RefreshToken.user_id == signed_up_owner["owner_user_id"])
            )
        )
        .scalars()
        .all()
    )
    assert tokens, "expected at least one refresh token row for the owner"
    assert all(t.revoked_at is not None for t in tokens)


async def test_refresh_token_reuse_revokes_the_rotated_replacement_too(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    """Once reuse is detected, every session for that user is killed —
    including the very token that replaced the reused one."""
    original_refresh_token = signed_up_owner["refresh_token"]

    first = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": original_refresh_token}
    )
    new_refresh_token = first.json()["data"]["refresh_token"]

    await client.post("/api/v1/auth/refresh", json={"refresh_token": original_refresh_token})

    blocked = await client.post("/api/v1/auth/refresh", json={"refresh_token": new_refresh_token})
    assert blocked.status_code == 401


async def test_logout_revokes_the_refresh_token(client: AsyncClient, signed_up_owner: dict) -> None:
    await client.post(
        "/api/v1/auth/logout", json={"refresh_token": signed_up_owner["refresh_token"]}
    )

    response = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": signed_up_owner["refresh_token"]}
    )
    assert response.status_code == 401
