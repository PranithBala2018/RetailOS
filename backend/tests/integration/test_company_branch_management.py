from httpx import AsyncClient


async def test_get_company_returns_the_callers_own_company(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.get(
        f"/api/v1/companies/{signed_up_owner['company_id']}", headers=signed_up_owner["headers"]
    )
    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Acme Retail"


async def test_update_company_succeeds_with_correct_version(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.put(
        f"/api/v1/companies/{signed_up_owner['company_id']}?expected_version=1",
        json={"brand_name": "Acme"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["brand_name"] == "Acme"
    assert response.json()["data"]["version"] == 2


async def test_update_company_with_stale_version_returns_conflict(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    await client.put(
        f"/api/v1/companies/{signed_up_owner['company_id']}?expected_version=1",
        json={"brand_name": "First edit"},
        headers=signed_up_owner["headers"],
    )

    stale_edit = await client.put(
        f"/api/v1/companies/{signed_up_owner['company_id']}?expected_version=1",
        json={"brand_name": "Conflicting edit"},
        headers=signed_up_owner["headers"],
    )

    assert stale_edit.status_code == 409


async def test_list_branches_includes_the_default_head_office(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.get("/api/v1/branches", headers=signed_up_owner["headers"])
    assert response.status_code == 200
    names = [b["name"] for b in response.json()["data"]]
    assert names == ["Head Office"]


async def test_create_branch_with_duplicate_code_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/branches",
        json={"name": "Second Branch", "code": "HO"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_create_branch_with_unique_code_succeeds(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/branches",
        json={"name": "Downtown", "code": "DT01"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["name"] == "Downtown"


async def test_create_warehouse_for_a_branch(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.post(
        f"/api/v1/branches/{signed_up_owner['branch_id']}/warehouses",
        json={"branch_id": signed_up_owner["branch_id"], "name": "Overflow", "code": "OVF"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text

    listed = await client.get(
        f"/api/v1/branches/{signed_up_owner['branch_id']}/warehouses",
        headers=signed_up_owner["headers"],
    )
    names = {w["name"] for w in listed.json()["data"]}
    assert names == {"Main Warehouse", "Overflow"}


async def test_endpoints_reject_requests_without_a_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/branches")
    assert response.status_code == 401


async def test_endpoints_reject_a_garbage_token(client: AsyncClient) -> None:
    response = await client.get(
        "/api/v1/branches", headers={"Authorization": "Bearer not-a-real-token"}
    )
    assert response.status_code == 401
