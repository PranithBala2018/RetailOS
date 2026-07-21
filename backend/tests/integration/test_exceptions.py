"""Exercises the exception-handler wiring in isolation from any real route,
since no business module (which would raise these in practice) exists yet.
"""

import httpx
import pytest
from fastapi import FastAPI

from app.core.exceptions import (
    ConflictException,
    NotFoundException,
    PermissionDeniedException,
    register_exception_handlers,
)


@pytest.fixture
async def client():
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/not-found")
    async def raise_not_found() -> None:
        raise NotFoundException("Widget not found")

    @app.get("/conflict")
    async def raise_conflict() -> None:
        raise ConflictException("Widget version mismatch", field="version")

    @app.get("/forbidden")
    async def raise_forbidden() -> None:
        raise PermissionDeniedException("Not allowed")

    @app.get("/boom")
    async def raise_unhandled() -> None:
        raise RuntimeError("something broke")

    transport = httpx.ASGITransport(app=app, raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def test_not_found_exception_maps_to_404(client: httpx.AsyncClient) -> None:
    response = await client.get("/not-found")
    assert response.status_code == 404
    body = response.json()
    assert body["success"] is False
    assert body["errors"][0]["code"] == "not_found"


async def test_conflict_exception_includes_field(client: httpx.AsyncClient) -> None:
    response = await client.get("/conflict")
    assert response.status_code == 409
    assert response.json()["errors"][0]["field"] == "version"


async def test_permission_denied_maps_to_403(client: httpx.AsyncClient) -> None:
    response = await client.get("/forbidden")
    assert response.status_code == 403


async def test_unhandled_exception_returns_generic_500_envelope(
    client: httpx.AsyncClient,
) -> None:
    response = await client.get("/boom")
    assert response.status_code == 500
    body = response.json()
    assert body["success"] is False
    assert "unexpected error" in body["message"].lower()
    # The internal exception message must never leak to the client.
    assert "something broke" not in response.text
