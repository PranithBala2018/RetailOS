import csv
import io

from httpx import AsyncClient


async def _create_pcs_product(client: AsyncClient, headers: dict, sku: str, name: str) -> None:
    units = (await client.get("/api/v1/units", headers=headers)).json()["data"]
    unit_id = next(u["id"] for u in units if u["abbreviation"] == "pcs")
    response = await client.post(
        "/api/v1/products",
        json={"sku": sku, "name": name, "base_unit_id": unit_id, "selling_price": "50.00"},
        headers=headers,
    )
    assert response.status_code == 200, response.text


def _upload(csv_text: str) -> dict:
    return {"file": ("products.csv", csv_text, "text/csv")}


async def test_export_products_returns_csv_with_one_row_per_variant(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    await _create_pcs_product(client, signed_up_owner["headers"], "EXP-001", "Exportable Tea")

    response = await client.get("/api/v1/products/export", headers=signed_up_owner["headers"])
    assert response.status_code == 200, response.text
    assert response.headers["content-type"].startswith("text/csv")

    rows = list(csv.DictReader(io.StringIO(response.text)))
    assert any(r["sku"] == "EXP-001" and r["unit"] == "pcs" for r in rows)


async def test_import_simple_products_creates_one_variant_each(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    csv_text = (
        "sku,name,category,brand,unit,variant_sku,purchase_price,selling_price\n"
        "IMP-001,Imported Tea,Beverages,Acme,pcs,IMP-001,80.00,120.00\n"
        "IMP-002,Imported Coffee,Beverages,Acme,pcs,IMP-002,90.00,150.00\n"
    )

    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["created"] == 2
    assert data["skipped"] == 0
    assert data["errors"] == 0

    listed = await client.get(
        "/api/v1/products", params={"search": "Imported"}, headers=signed_up_owner["headers"]
    )
    assert {p["sku"] for p in listed.json()["data"]} == {"IMP-001", "IMP-002"}


async def test_import_creates_missing_category_and_brand_automatically(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    csv_text = (
        "sku,name,category,brand,unit,variant_sku,purchase_price,selling_price\n"
        "IMP-CAT-001,New Category Product,Brand New Category,Brand New Brand,pcs,"
        "IMP-CAT-001,10.00,20.00\n"
    )
    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["created"] == 1

    categories = await client.get("/api/v1/categories", headers=signed_up_owner["headers"])
    brands = await client.get("/api/v1/brands", headers=signed_up_owner["headers"])
    assert "Brand New Category" in {c["name"] for c in categories.json()["data"]}
    assert "Brand New Brand" in {b["name"] for b in brands.json()["data"]}


async def test_import_groups_multiple_rows_with_same_sku_into_one_product_with_variants(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    csv_text = (
        "sku,name,unit,variant_sku,size,color,purchase_price,selling_price\n"
        "IMP-VAR-001,Kids Shirt,pcs,IMP-VAR-001-S-RED,S,Red,100.00,200.00\n"
        "IMP-VAR-001,Kids Shirt,pcs,IMP-VAR-001-M-BLU,M,Blue,100.00,200.00\n"
    )
    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["created"] == 1

    products = (
        await client.get(
            "/api/v1/products", params={"search": "Kids Shirt"}, headers=signed_up_owner["headers"]
        )
    ).json()["data"]
    assert len(products) == 1
    product_id = products[0]["id"]
    assert products[0]["has_variants"] is True

    variants = await client.get(
        f"/api/v1/products/{product_id}/variants", headers=signed_up_owner["headers"]
    )
    assert {v["sku"] for v in variants.json()["data"]} == {
        "IMP-VAR-001-S-RED",
        "IMP-VAR-001-M-BLU",
    }


async def test_import_skips_a_product_whose_sku_already_exists(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    await _create_pcs_product(client, signed_up_owner["headers"], "EXISTS-001", "Already Here")

    csv_text = (
        "sku,name,unit,variant_sku,purchase_price,selling_price\n"
        "EXISTS-001,Already Here Again,pcs,EXISTS-001,10.00,20.00\n"
    )
    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["created"] == 0
    assert data["skipped"] == 1
    assert data["results"][0]["status"] == "skipped"


async def test_import_reports_error_for_unknown_unit_without_aborting_other_rows(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    csv_text = (
        "sku,name,unit,variant_sku,purchase_price,selling_price\n"
        "BAD-UNIT-001,Bad Unit Product,not-a-real-unit,BAD-UNIT-001,10.00,20.00\n"
        "GOOD-UNIT-001,Good Unit Product,pcs,GOOD-UNIT-001,10.00,20.00\n"
    )
    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["created"] == 1
    assert data["errors"] == 1
    error_row = next(r for r in data["results"] if r["sku"] == "BAD-UNIT-001")
    assert error_row["status"] == "error"
    assert "not-a-real-unit" in error_row["message"]

    good_row_exists = await client.get(
        "/api/v1/products",
        params={"search": "Good Unit Product"},
        headers=signed_up_owner["headers"],
    )
    assert len(good_row_exists.json()["data"]) == 1


async def test_import_missing_required_column_returns_validation_error(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    csv_text = "sku,name\nX-001,Missing Columns\n"
    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_import_rejects_row_with_invalid_price(
    client: AsyncClient, signed_up_owner: dict
) -> None:
    csv_text = (
        "sku,name,unit,variant_sku,purchase_price,selling_price\n"
        "BAD-PRICE-001,Bad Price,pcs,BAD-PRICE-001,not-a-number,20.00\n"
    )
    response = await client.post(
        "/api/v1/products/import",
        files=_upload(csv_text),
        headers=signed_up_owner["headers"],
    )
    assert response.status_code == 422


async def test_export_and_import_endpoints_reject_requests_without_a_token(
    client: AsyncClient,
) -> None:
    export_response = await client.get("/api/v1/products/export")
    assert export_response.status_code == 401

    import_response = await client.post("/api/v1/products/import", files=_upload("sku,name\n"))
    assert import_response.status_code == 401
