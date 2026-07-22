from httpx import AsyncClient


async def _get_role_id(client: AsyncClient, headers: dict, role_name: str) -> str:
    response = await client.get("/api/v1/roles", headers=headers)
    role = next(r for r in response.json()["data"] if r["name"] == role_name)
    return role["id"]


async def _create_variant(
    client: AsyncClient,
    headers: dict,
    sku: str,
    *,
    track_inventory: bool = True,
    allow_negative_stock: bool = False,
    low_stock_threshold: int | None = None,
) -> dict:
    units = (await client.get("/api/v1/units", headers=headers)).json()["data"]
    unit_id = next(u["id"] for u in units if u["abbreviation"] == "pcs")
    response = await client.post(
        "/api/v1/products",
        json={
            "sku": sku,
            "name": f"Widget {sku}",
            "base_unit_id": unit_id,
            "track_inventory": track_inventory,
            "allow_negative_stock": allow_negative_stock,
            "low_stock_threshold": low_stock_threshold,
        },
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()["data"]["variants"][0]


async def test_stock_in_creates_transaction_and_raises_the_balance(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-001")

    response = await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 10,
            "reason": "Opening stock",
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["quantity_after"] == 10
    assert response.json()["data"]["movement_type"] == "stock_in"

    level = await client.get(
        f"/api/v1/inventory/stock/{variant['id']}",
        params={"warehouse_id": signed_up_owner["warehouse_id"]},
        headers=signed_up_owner["headers"],
    )
    assert level.json()["data"]["quantity"] == 10


async def test_stock_out_reduces_the_balance(client: AsyncClient, signed_up_owner: dict) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-002")
    await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 10,
        },
        headers=signed_up_owner["headers"],
    )

    response = await client.post(
        "/api/v1/inventory/stock-out",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 4,
            "reason": "Damaged",
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["quantity_after"] == 6
    assert response.json()["data"]["quantity_delta"] == -4


async def test_stock_out_rejected_when_it_would_go_negative(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-003")

    response = await client.post(
        "/api/v1/inventory/stock-out",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 1,
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422

    level = await client.get(
        f"/api/v1/inventory/stock/{variant['id']}",
        params={"warehouse_id": signed_up_owner["warehouse_id"]},
        headers=signed_up_owner["headers"],
    )
    assert level.json()["data"]["quantity"] == 0


async def test_stock_out_allowed_negative_when_product_permits_it(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(
        client, signed_up_owner["headers"], "INV-004", allow_negative_stock=True
    )

    response = await client.post(
        "/api/v1/inventory/stock-out",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 3,
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["quantity_after"] == -3


async def test_stock_in_rejected_when_product_does_not_track_inventory(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(
        client, signed_up_owner["headers"], "INV-005", track_inventory=False
    )

    response = await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 1,
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_adjustment_computes_delta_from_the_counted_quantity(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-006")
    await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 10,
        },
        headers=signed_up_owner["headers"],
    )

    response = await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "counted_quantity": 7,
            "reason": "recount",
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["quantity_delta"] == -3
    assert response.json()["data"]["quantity_after"] == 7
    assert response.json()["data"]["movement_type"] == "adjustment"


async def test_transfer_moves_stock_between_warehouses(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-007")
    await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 10,
        },
        headers=signed_up_owner["headers"],
    )
    other_warehouse = await client.post(
        f"/api/v1/branches/{signed_up_owner['branch_id']}/warehouses",
        json={
            "branch_id": signed_up_owner["branch_id"],
            "name": "Overflow",
            "code": "OVF-INV",
        },
        headers=signed_up_owner["headers"],
    )
    other_warehouse_id = other_warehouse.json()["data"]["id"]

    response = await client.post(
        "/api/v1/inventory/transfers",
        json={
            "from_warehouse_id": signed_up_owner["warehouse_id"],
            "to_warehouse_id": other_warehouse_id,
            "product_variant_id": variant["id"],
            "quantity": 4,
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text

    source_level = await client.get(
        f"/api/v1/inventory/stock/{variant['id']}",
        params={"warehouse_id": signed_up_owner["warehouse_id"]},
        headers=signed_up_owner["headers"],
    )
    dest_level = await client.get(
        f"/api/v1/inventory/stock/{variant['id']}",
        params={"warehouse_id": other_warehouse_id},
        headers=signed_up_owner["headers"],
    )
    assert source_level.json()["data"]["quantity"] == 6
    assert dest_level.json()["data"]["quantity"] == 4


async def test_transfer_rejects_the_same_warehouse_as_source_and_destination(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-008")

    response = await client.post(
        "/api/v1/inventory/transfers",
        json={
            "from_warehouse_id": signed_up_owner["warehouse_id"],
            "to_warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 1,
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_low_stock_lists_only_variants_at_or_below_threshold(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    low_variant = await _create_variant(
        client, signed_up_owner["headers"], "INV-009", low_stock_threshold=5
    )
    healthy_variant = await _create_variant(
        client, signed_up_owner["headers"], "INV-010", low_stock_threshold=5
    )
    await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": low_variant["id"],
            "quantity": 2,
        },
        headers=signed_up_owner["headers"],
    )
    await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": healthy_variant["id"],
            "quantity": 50,
        },
        headers=signed_up_owner["headers"],
    )

    response = await client.get(
        "/api/v1/inventory/low-stock",
        params={"warehouse_id": signed_up_owner["warehouse_id"]},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    variant_ids = {row["product_variant_id"] for row in response.json()["data"]}
    assert low_variant["id"] in variant_ids
    assert healthy_variant["id"] not in variant_ids


async def test_transactions_endpoint_paginates_with_a_cursor(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-011")
    for _ in range(3):
        await client.post(
            "/api/v1/inventory/stock-in",
            json={
                "warehouse_id": signed_up_owner["warehouse_id"],
                "product_variant_id": variant["id"],
                "quantity": 1,
            },
            headers=signed_up_owner["headers"],
        )

    first_page = await client.get(
        "/api/v1/inventory/transactions",
        params={"product_variant_id": variant["id"], "limit": 2},
        headers=signed_up_owner["headers"],
    )
    assert first_page.status_code == 200, first_page.text
    first_data = first_page.json()["data"]
    assert len(first_data["items"]) == 2
    assert first_data["has_more"] is True
    assert first_data["next_cursor"] is not None

    second_page = await client.get(
        "/api/v1/inventory/transactions",
        params={
            "product_variant_id": variant["id"],
            "limit": 2,
            "cursor": first_data["next_cursor"],
        },
        headers=signed_up_owner["headers"],
    )
    second_data = second_page.json()["data"]
    assert len(second_data["items"]) == 1
    assert second_data["has_more"] is False

    seen_ids = {item["id"] for item in first_data["items"]} | {
        item["id"] for item in second_data["items"]
    }
    assert len(seen_ids) == 3


async def test_inventory_endpoints_reject_requests_without_a_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/inventory/stock")
    assert response.status_code == 401


async def test_cashier_cannot_record_stock_movements_but_manager_can(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    variant = await _create_variant(client, signed_up_owner["headers"], "INV-012")

    manager_role_id = await _get_role_id(client, signed_up_owner["headers"], "Manager")
    cashier_role_id = await _get_role_id(client, signed_up_owner["headers"], "Cashier")
    for email, role_id in (
        ("manager-inv@acmeretail-example.com", manager_role_id),
        ("cashier-inv@acmeretail-example.com", cashier_role_id),
    ):
        await client.post(
            "/api/v1/users",
            json={
                "email": email,
                "password": "test-password-123",
                "full_name": "Test User",
                "default_branch_id": signed_up_owner["branch_id"],
                "assigned_branch_ids": [signed_up_owner["branch_id"]],
                "role_ids": [role_id],
            },
            headers=signed_up_owner["headers"],
        )

    async def _login(email: str) -> dict:
        response = await client.post(
            "/api/v1/auth/login", json={"email": email, "password": "test-password-123"}
        )
        return {"Authorization": f"Bearer {response.json()['data']['access_token']}"}

    manager_headers = await _login("manager-inv@acmeretail-example.com")
    cashier_headers = await _login("cashier-inv@acmeretail-example.com")

    manager_response = await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 5,
        },
        headers=manager_headers,
    )
    assert manager_response.status_code == 200, manager_response.text

    cashier_response = await client.post(
        "/api/v1/inventory/stock-in",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "quantity": 5,
        },
        headers=cashier_headers,
    )
    assert cashier_response.status_code == 403

    manager_adjust = await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "warehouse_id": signed_up_owner["warehouse_id"],
            "product_variant_id": variant["id"],
            "counted_quantity": 1,
            "reason": "recount",
        },
        headers=manager_headers,
    )
    assert manager_adjust.status_code == 403


async def test_company_wide_warehouse_listing(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.get("/api/v1/warehouses", headers=signed_up_owner["headers"])
    assert response.status_code == 200, response.text
    names = [w["name"] for w in response.json()["data"]]
    assert "Main Warehouse" in names
