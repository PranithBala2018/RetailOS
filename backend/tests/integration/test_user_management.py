from httpx import AsyncClient


async def _get_role_id(client: AsyncClient, headers: dict, role_name: str) -> str:
    response = await client.get("/api/v1/roles", headers=headers)
    role = next(r for r in response.json()["data"] if r["name"] == role_name)
    return role["id"]


async def test_owner_can_list_and_create_users(client: AsyncClient, signed_up_owner: dict) -> None:
    listed = await client.get("/api/v1/users", headers=signed_up_owner["headers"])
    assert listed.status_code == 200
    assert len(listed.json()["data"]) == 1  # just the owner so far

    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    created = await client.post(
        "/api/v1/users",
        json={
            "email": "cashier@acmeretail-example.com",
            "password": "cashier-password-123",
            "full_name": "Casey Cashier",
            "default_branch_id": signed_up_owner["branch_id"],
            "assigned_branch_ids": [signed_up_owner["branch_id"]],
            "role_ids": [cashier_role_id],
        },
        headers=signed_up_owner["headers"],
    )
    assert created.status_code == 200, created.text
    assert created.json()["data"]["email"] == "cashier@acmeretail-example.com"


async def test_creating_a_user_with_a_duplicate_email_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/users",
        json={
            "email": signed_up_owner["email"],
            "password": "another-password-123",
            "full_name": "Duplicate Owner",
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_admin_reset_password_forces_change_on_next_login(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    created = await client.post(
        "/api/v1/users",
        json={
            "email": "cashier2@acmeretail-example.com",
            "password": "cashier-password-123",
            "full_name": "Casey Two",
            "role_ids": [cashier_role_id],
        },
        headers=signed_up_owner["headers"],
    )
    user_id = created.json()["data"]["id"]

    reset = await client.post(
        f"/api/v1/users/{user_id}/reset-password",
        json={"new_password": "admin-set-password-456"},
        headers=signed_up_owner["headers"],
    )
    assert reset.status_code == 200

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "cashier2@acmeretail-example.com", "password": "admin-set-password-456"},
    )
    assert login.status_code == 200
    me = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {login.json()['data']['access_token']}"},
    )
    # must_change_password isn't in MeResponse by design (session claims,
    # not account state) — verified via the users list instead.
    users = await client.get("/api/v1/users", headers=signed_up_owner["headers"])
    cashier = next(u for u in users.json()["data"] if u["id"] == user_id)
    assert cashier["must_change_password"] is True
    assert me.status_code == 200


async def test_disable_user_prevents_future_login(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    created = await client.post(
        "/api/v1/users",
        json={
            "email": "cashier3@acmeretail-example.com",
            "password": "cashier-password-123",
            "full_name": "Casey Three",
            "role_ids": [cashier_role_id],
        },
        headers=signed_up_owner["headers"],
    )
    user_id = created.json()["data"]["id"]

    disable = await client.delete(f"/api/v1/users/{user_id}", headers=signed_up_owner["headers"])
    assert disable.status_code == 200

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "cashier3@acmeretail-example.com", "password": "cashier-password-123"},
    )
    assert login.status_code == 401


async def test_cashier_role_cannot_create_a_branch(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    await client.post(
        "/api/v1/users",
        json={
            "email": "cashier4@acmeretail-example.com",
            "password": "cashier-password-123",
            "full_name": "Casey Four",
            "role_ids": [cashier_role_id],
        },
        headers=signed_up_owner["headers"],
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "cashier4@acmeretail-example.com", "password": "cashier-password-123"},
    )
    cashier_headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

    response = await client.post(
        "/api/v1/branches", json={"name": "Nope", "code": "NOPE"}, headers=cashier_headers
    )
    assert response.status_code == 403


async def test_cashier_role_can_still_read_the_dashboard(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    await client.post(
        "/api/v1/users",
        json={
            "email": "cashier5@acmeretail-example.com",
            "password": "cashier-password-123",
            "full_name": "Casey Five",
            "role_ids": [cashier_role_id],
        },
        headers=signed_up_owner["headers"],
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": "cashier5@acmeretail-example.com", "password": "cashier-password-123"},
    )
    cashier_headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

    response = await client.get("/api/v1/dashboard/shell", headers=cashier_headers)
    assert response.status_code == 200


async def test_list_permissions_returns_the_seeded_catalog(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.get("/api/v1/permissions", headers=signed_up_owner["headers"])
    assert response.status_code == 200
    codes = {p["code"] for p in response.json()["data"]}
    assert "company.read" in codes
    assert "dashboard.read" in codes
