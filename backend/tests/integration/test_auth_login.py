from httpx import AsyncClient


async def test_login_with_wrong_password_fails(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": "wrong-password"},
    )
    assert response.status_code == 401
    body = response.json()
    assert body["success"] is False


async def test_login_with_unknown_email_fails_generically(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@acmeretail-example.com", "password": "whatever12345"},
    )
    assert response.status_code == 401
    # Must not reveal whether the email exists — same message either way.
    assert "invalid email or password" in response.json()["message"].lower()


async def test_account_locks_after_configured_failed_attempts(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    # Default is 5 (API_MAX_FAILED_LOGIN_ATTEMPTS) — see core/config.py.
    for _ in range(5):
        await client.post(
            "/api/v1/auth/login",
            json={"email": signed_up_owner["email"], "password": "wrong-password"},
        )

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": signed_up_owner["password"]},
    )

    assert response.status_code == 401
    assert "locked" in response.json()["message"].lower()


async def test_successful_login_resets_failed_attempt_counter(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    for _ in range(3):
        await client.post(
            "/api/v1/auth/login",
            json={"email": signed_up_owner["email"], "password": "wrong-password"},
        )

    ok_response = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": signed_up_owner["password"]},
    )
    assert ok_response.status_code == 200

    # Three more failures afterward should not be enough to lock the
    # account — the counter must have reset on the successful login.
    for _ in range(3):
        await client.post(
            "/api/v1/auth/login",
            json={"email": signed_up_owner["email"], "password": "wrong-password"},
        )
    still_ok = await client.post(
        "/api/v1/auth/login",
        json={"email": signed_up_owner["email"], "password": signed_up_owner["password"]},
    )
    assert still_ok.status_code == 200
