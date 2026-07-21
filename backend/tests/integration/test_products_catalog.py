from httpx import AsyncClient


async def _get_pcs_unit_id(client: AsyncClient, headers: dict) -> str:
    response = await client.get("/api/v1/units", headers=headers)
    assert response.status_code == 200, response.text
    units = response.json()["data"]
    return next(u["id"] for u in units if u["abbreviation"] == "pcs")


async def test_list_units_includes_seeded_system_defaults(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.get("/api/v1/units", headers=signed_up_owner["headers"])
    assert response.status_code == 200, response.text
    abbreviations = {u["abbreviation"] for u in response.json()["data"]}
    assert {"pcs", "kg", "g", "ltr", "box", "dz"}.issubset(abbreviations)


async def test_create_custom_unit_succeeds(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.post(
        "/api/v1/units",
        json={"name": "Carton", "abbreviation": "ctn"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["is_system"] is False


async def test_create_category_and_fetch_it(client: AsyncClient, signed_up_owner: dict) -> None:
    response = await client.post(
        "/api/v1/categories",
        json={"name": "T-Shirts", "display_order": 1},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    category_id = response.json()["data"]["id"]

    fetched = await client.get(
        f"/api/v1/categories/{category_id}", headers=signed_up_owner["headers"]
    )
    assert fetched.status_code == 200
    assert fetched.json()["data"]["name"] == "T-Shirts"


async def test_create_category_with_duplicate_name_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    await client.post(
        "/api/v1/categories", json={"name": "Shoes"}, headers=signed_up_owner["headers"]
    )
    response = await client.post(
        "/api/v1/categories", json={"name": "Shoes"}, headers=signed_up_owner["headers"]
    )
    assert response.status_code == 422


async def test_create_subcategory_with_unknown_parent_returns_not_found(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    response = await client.post(
        "/api/v1/categories",
        json={"name": "Kids Shoes", "parent_category_id": "00000000-0000-0000-0000-000000000000"},
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 404


async def test_update_category_with_stale_version_returns_conflict(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    created = await client.post(
        "/api/v1/categories", json={"name": "Jeans"}, headers=signed_up_owner["headers"]
    )
    category_id = created.json()["data"]["id"]

    await client.put(
        f"/api/v1/categories/{category_id}?expected_version=1",
        json={"display_order": 5},
        headers=signed_up_owner["headers"],
    )
    stale = await client.put(
        f"/api/v1/categories/{category_id}?expected_version=1",
        json={"display_order": 9},
        headers=signed_up_owner["headers"],
    )
    assert stale.status_code == 409


async def test_create_brand_and_update_it(client: AsyncClient, signed_up_owner: dict) -> None:
    created = await client.post(
        "/api/v1/brands", json={"name": "Acme Wear"}, headers=signed_up_owner["headers"]
    )
    assert created.status_code == 200, created.text
    brand_id = created.json()["data"]["id"]

    updated = await client.put(
        f"/api/v1/brands/{brand_id}?expected_version=1",
        json={"description": "In-house label"},
        headers=signed_up_owner["headers"],
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["data"]["description"] == "In-house label"


async def test_create_simple_product_auto_creates_one_variant(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])

    response = await client.post(
        "/api/v1/products",
        json={
            "sku": "TEA-001",
            "name": "Masala Tea Powder 250g",
            "base_unit_id": unit_id,
            "selling_price": "120.00",
            "purchase_price": "90.00",
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["product"]["has_variants"] is False
    assert len(data["variants"]) == 1
    assert data["variants"][0]["sku"] == "TEA-001"
    assert data["variants"][0]["selling_price"] == "120.00"


async def test_create_variant_bearing_product_for_kids_wear_pilot(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])

    response = await client.post(
        "/api/v1/products",
        json={
            "sku": "KID-SHIRT-001",
            "name": "Kids Cotton T-Shirt",
            "base_unit_id": unit_id,
            "gender": "kids",
            "season": "summer",
            "age_group": "4-6y",
            "has_variants": True,
            "variants": [
                {
                    "sku": "KID-SHIRT-001-RED-S",
                    "size": "S",
                    "color": "Red",
                    "selling_price": "299.00",
                },
                {
                    "sku": "KID-SHIRT-001-BLU-M",
                    "size": "M",
                    "color": "Blue",
                    "selling_price": "299.00",
                },
            ],
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["product"]["gender"] == "kids"
    assert len(data["variants"]) == 2
    names = {v["variant_name"] for v in data["variants"]}
    assert names == {"Red / S", "Blue / M"}


async def test_create_product_without_variants_when_has_variants_true_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])

    response = await client.post(
        "/api/v1/products",
        json={
            "sku": "BAD-001",
            "name": "Bad Product",
            "base_unit_id": unit_id,
            "has_variants": True,
            "variants": [],
        },
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_create_product_with_duplicate_sku_is_rejected(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])
    payload = {
        "sku": "DUP-001",
        "name": "First",
        "base_unit_id": unit_id,
    }
    first = await client.post("/api/v1/products", json=payload, headers=signed_up_owner["headers"])
    assert first.status_code == 200, first.text

    second = await client.post(
        "/api/v1/products",
        json={**payload, "name": "Second"},
        headers=signed_up_owner["headers"],
    )
    assert second.status_code == 422


async def test_add_variant_to_existing_product_flips_has_variants(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])
    created = await client.post(
        "/api/v1/products",
        json={"sku": "GROW-001", "name": "Growing Product", "base_unit_id": unit_id},
        headers=signed_up_owner["headers"],
    )
    product_id = created.json()["data"]["product"]["id"]

    added = await client.post(
        f"/api/v1/products/{product_id}/variants",
        json={"sku": "GROW-001-XL", "size": "XL", "selling_price": "150.00"},
        headers=signed_up_owner["headers"],
    )
    assert added.status_code == 200, added.text

    fetched = await client.get(f"/api/v1/products/{product_id}", headers=signed_up_owner["headers"])
    assert fetched.json()["data"]["product"]["has_variants"] is True
    assert len(fetched.json()["data"]["variants"]) == 2


async def test_add_barcode_to_variant_and_list_it(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])
    created = await client.post(
        "/api/v1/products",
        json={"sku": "BAR-001", "name": "Barcoded Product", "base_unit_id": unit_id},
        headers=signed_up_owner["headers"],
    )
    variant_id = created.json()["data"]["variants"][0]["id"]

    added = await client.post(
        f"/api/v1/product-variants/{variant_id}/barcodes",
        json={"barcode": "8901234567890", "barcode_type": "ean13", "is_primary": True},
        headers=signed_up_owner["headers"],
    )
    assert added.status_code == 200, added.text

    listed = await client.get(
        f"/api/v1/product-variants/{variant_id}/barcodes", headers=signed_up_owner["headers"]
    )
    assert listed.json()["data"][0]["barcode"] == "8901234567890"


async def test_add_image_to_product_and_list_it(client: AsyncClient, signed_up_owner: dict) -> None:
    unit_id = await _get_pcs_unit_id(client, signed_up_owner["headers"])
    created = await client.post(
        "/api/v1/products",
        json={"sku": "IMG-001", "name": "Product With Image", "base_unit_id": unit_id},
        headers=signed_up_owner["headers"],
    )
    product_id = created.json()["data"]["product"]["id"]

    added = await client.post(
        f"/api/v1/products/{product_id}/images",
        json={"image_url": "https://example.com/img.jpg", "is_primary": True},
        headers=signed_up_owner["headers"],
    )
    assert added.status_code == 200, added.text

    listed = await client.get(
        f"/api/v1/products/{product_id}/images", headers=signed_up_owner["headers"]
    )
    assert listed.json()["data"][0]["image_url"] == "https://example.com/img.jpg"


async def test_products_endpoints_reject_requests_without_a_token(client: AsyncClient) -> None:
    response = await client.get("/api/v1/products")
    assert response.status_code == 401
