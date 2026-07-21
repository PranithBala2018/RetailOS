from httpx import AsyncClient


async def _get_role_id(client: AsyncClient, headers: dict, role_name: str) -> str:
    response = await client.get("/api/v1/roles", headers=headers)
    role = next(r for r in response.json()["data"] if r["name"] == role_name)
    return role["id"]


async def test_owner_sees_their_assigned_branch(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.get("/api/v1/auth/my-branches", headers=signed_up_owner["headers"])
    assert response.status_code == 200
    names = [b["name"] for b in response.json()["data"]]
    assert names == ["Head Office"]


async def test_cashier_without_branches_read_can_still_see_their_own_branches(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    """This is the whole point of the endpoint: Cashier has no
    branches.read permission but must still be able to list branches to
    switch between."""
    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    await client.post(
        "/api/v1/users",
        json={
            "email": "cashier-branches@acmeretail-example.com",
            "password": "cashier-password-123",
            "full_name": "Casey Branches",
            "default_branch_id": signed_up_owner["branch_id"],
            "assigned_branch_ids": [signed_up_owner["branch_id"]],
            "role_ids": [cashier_role_id],
        },
        headers=signed_up_owner["headers"],
    )
    login = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "cashier-branches@acmeretail-example.com",
            "password": "cashier-password-123",
        },
    )
    cashier_headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

    # Confirm the Cashier really can't hit the admin endpoint...
    admin_only = await client.get("/api/v1/branches", headers=cashier_headers)
    assert admin_only.status_code == 403

    # ...but can still see their own assigned branches.
    response = await client.get("/api/v1/auth/my-branches", headers=cashier_headers)
    assert response.status_code == 200
    names = [b["name"] for b in response.json()["data"]]
    assert names == ["Head Office"]
