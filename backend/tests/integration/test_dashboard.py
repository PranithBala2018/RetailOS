from httpx import AsyncClient


async def test_dashboard_shell_reports_company_and_system_status(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.get("/api/v1/dashboard/shell", headers=signed_up_owner["headers"])

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["company_name"] == "Acme Retail"
    assert data["user_full_name"] == "Ada Owner"
    assert data["role_names"] == ["Super Admin"]
    assert data["api_status"] == "ok"
    assert data["database_status"] == "ok"
    assert data["api_version"]


async def test_dashboard_shell_reflects_the_switched_branch(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    switched = await client.post(
        "/api/v1/auth/switch-branch",
        json={"branch_id": signed_up_owner["branch_id"]},
        headers=signed_up_owner["headers"],
    )
    new_headers = {"Authorization": f"Bearer {switched.json()['data']['access_token']}"}

    response = await client.get("/api/v1/dashboard/shell", headers=new_headers)

    assert response.status_code == 200
    assert response.json()["data"]["branch_name"] == "Head Office"
