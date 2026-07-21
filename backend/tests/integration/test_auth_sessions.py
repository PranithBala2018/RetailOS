from httpx import AsyncClient


async def test_list_sessions_includes_the_session_from_signup(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.get("/api/v1/auth/sessions", headers=signed_up_owner["headers"])

    assert response.status_code == 200
    sessions = response.json()["data"]
    assert len(sessions) == 1


async def test_login_from_a_second_device_adds_a_second_session(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    await client.post(
        "/api/v1/auth/login",
        json={
            "email": signed_up_owner["email"],
            "password": signed_up_owner["password"],
            "device_name": "Second Device",
        },
    )

    response = await client.get("/api/v1/auth/sessions", headers=signed_up_owner["headers"])
    sessions = response.json()["data"]
    assert len(sessions) == 2


async def test_revoke_session_removes_it_from_the_list(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    login = await client.post(
        "/api/v1/auth/login",
        json={
            "email": signed_up_owner["email"],
            "password": signed_up_owner["password"],
            "device_name": "Second Device",
        },
    )
    second_refresh_token = login.json()["data"]["refresh_token"]

    sessions_before = (
        await client.get("/api/v1/auth/sessions", headers=signed_up_owner["headers"])
    ).json()["data"]
    second_session_id = next(
        s["id"] for s in sessions_before if s["device_name"] == "Second Device"
    )

    revoke_response = await client.delete(
        f"/api/v1/auth/sessions/{second_session_id}", headers=signed_up_owner["headers"]
    )
    assert revoke_response.status_code == 200

    sessions_after = (
        await client.get("/api/v1/auth/sessions", headers=signed_up_owner["headers"])
    ).json()["data"]
    assert len(sessions_after) == 1

    refresh_revoked = await client.post(
        "/api/v1/auth/refresh", json={"refresh_token": second_refresh_token}
    )
    assert refresh_revoked.status_code == 401


async def test_revoking_a_nonexistent_session_returns_404(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.delete(
        "/api/v1/auth/sessions/00000000-0000-0000-0000-000000000000",
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 404


async def test_switch_branch_to_an_unassigned_branch_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/auth/switch-branch",
        json={"branch_id": "00000000-0000-0000-0000-000000000000"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_switch_branch_to_the_default_branch_succeeds(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/auth/switch-branch",
        json={"branch_id": signed_up_owner["branch_id"]},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200
    assert response.json()["data"]["access_token"]
