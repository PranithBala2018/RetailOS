from httpx import AsyncClient


async def test_forgot_password_always_returns_generic_success(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    known = await client.post(
        "/api/v1/auth/forgot-password", json={"email": signed_up_owner["email"]}
    )
    unknown = await client.post(
        "/api/v1/auth/forgot-password", json={"email": "nobody@acmeretail-example.com"}
    )

    assert known.status_code == 200
    assert unknown.status_code == 200
    assert known.json()["message"] == unknown.json()["message"]


async def test_reset_password_then_login_with_new_password(
    client: AsyncClient, signed_up_owner: dict, monkeypatch
) -> None:
    # The reset token isn't retrievable from the DB (only its hash is
    # stored, by design) and isn't emailed yet (no notifications module —
    # see the Known Issues note in auth/service.py). Pinning the generator
    # is the direct, robust way to get the raw token in a test.
    monkeypatch.setattr(
        "app.modules.auth.service.secrets.token_urlsafe", lambda n: "fixed-test-reset-token"
    )

    await client.post("/api/v1/auth/forgot-password", json={"email": signed_up_owner["email"]})

    reset_response = await client.post(
        "/api/v1/auth/reset-password",
        json={"token": "fixed-test-reset-token", "new_password": "brand-new-password-123"},
    )
    assert reset_response.status_code == 200, reset_response.text

    old_password_login = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": signed_up_owner["password"]},
    )
    assert old_password_login.status_code == 401

    new_password_login = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": "brand-new-password-123"},
    )
    assert new_password_login.status_code == 200


async def test_reset_password_token_cannot_be_reused(
    client: AsyncClient, signed_up_owner: dict, monkeypatch
) -> None:
    monkeypatch.setattr(
        "app.modules.auth.service.secrets.token_urlsafe", lambda n: "fixed-test-reset-token"
    )
    await client.post("/api/v1/auth/forgot-password", json={"email": signed_up_owner["email"]})
    await client.post(
        "/api/v1/auth/reset-password",
        json={"token": "fixed-test-reset-token", "new_password": "brand-new-password-123"},
    )

    second_attempt = await client.post(
        "/api/v1/auth/reset-password",
        json={"token": "fixed-test-reset-token", "new_password": "yet-another-password-456"},
    )
    assert second_attempt.status_code == 422


async def test_reset_password_revokes_existing_sessions(
    client: AsyncClient, signed_up_owner: dict, monkeypatch
) -> None:
    monkeypatch.setattr(
        "app.modules.auth.service.secrets.token_urlsafe", lambda n: "fixed-test-reset-token"
    )
    await client.post("/api/v1/auth/forgot-password", json={"email": signed_up_owner["email"]})
    await client.post(
        "/api/v1/auth/reset-password",
        json={"token": "fixed-test-reset-token", "new_password": "brand-new-password-123"},
    )

    refresh_with_old_session = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": signed_up_owner["refresh_token"]}
    )
    assert refresh_with_old_session.status_code == 401


async def test_reset_password_with_invalid_token_is_rejected(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/reset-password",
        json={"token": "not-a-real-token", "new_password": "whatever-1234"},
    )
    assert response.status_code == 422


async def test_change_password_requires_correct_current_password(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "wrong-current", "new_password": "new-password-123"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_change_password_succeeds_and_allows_login_with_new_password(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": signed_up_owner["password"],
            "new_password": "another-new-password-456",
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": "another-new-password-456"},
    )
    assert login.status_code == 200
