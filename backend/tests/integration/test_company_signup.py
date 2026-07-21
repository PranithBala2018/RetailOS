from httpx import AsyncClient


async def test_signup_creates_company_branch_warehouse_and_owner(
    client: AsyncClient, signup_payload: dict
) -> None:
    response = await client.post("/api/v1/companies", json=signup_payload)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["success"] is True
    data = body["data"]
    assert data["company"]["name"] == "Acme Retail"
    assert data["branch"]["name"] == "Head Office"
    assert data["warehouse"]["name"] == "Main Warehouse"
    assert data["access_token"]
    assert data["refresh_token"]


async def test_signup_then_login_succeeds(client: AsyncClient, signup_payload: dict) -> None:
    await client.post("/api/v1/companies", json=signup_payload)

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "owner@acmeretail-example.com", "password": "correct-horse-battery-staple"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["data"]["access_token"]


async def test_signup_then_me_returns_super_admin_permissions(
    client: AsyncClient, signup_payload: dict
) -> None:
    signup = await client.post("/api/v1/companies", json=signup_payload)
    access_token = signup.json()["data"]["access_token"]

    response = await client.get(
        "/api/v1/auth/me", headers={"Authorization": f"Bearer {access_token}"}
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["email"] == "owner@acmeretail-example.com"
    assert "company.read" in data["permissions"]
    assert "roles.create" in data["permissions"]
