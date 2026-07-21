"""Boots the full FastAPI app assembly and exercises it over HTTP.

No database is required for this test — it exists to prove the app
factory, middleware stack, and exception handlers wire together correctly,
which is exactly what a Sprint 1 "does the project build" check needs.
"""

import httpx
import pytest

from app.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def test_health_endpoint_returns_success_envelope(client: httpx.AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["status"] == "ok"


async def test_health_endpoint_sets_request_id_header(client: httpx.AsyncClient) -> None:
    response = await client.get("/health")
    assert "X-Request-ID" in response.headers


async def test_request_id_is_echoed_back_when_supplied(client: httpx.AsyncClient) -> None:
    response = await client.get("/health", headers={"X-Request-ID": "test-request-id-123"})
    assert response.headers["X-Request-ID"] == "test-request-id-123"


async def test_unknown_route_returns_404(client: httpx.AsyncClient) -> None:
    response = await client.get("/this-route-does-not-exist")
    assert response.status_code == 404


async def test_openapi_schema_is_served(client: httpx.AsyncClient) -> None:
    response = await client.get("/openapi.json")
    assert response.status_code == 200
    assert response.json()["info"]["title"] == "RetailOS API"
