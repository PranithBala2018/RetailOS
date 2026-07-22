"""Transaction-per-test isolation against the real local Postgres
instance: each test runs inside an outer transaction that's always
rolled back afterward, so tests never see each other's data and the
seeded roles/permissions (committed by the Sprint 2 migrations) are
visible to every test without needing to be recreated.
"""

from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.db import create_engine
from app.core.db import get_db_session as real_get_db_session
from app.main import create_app


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    engine = create_engine()
    connection = await engine.connect()
    transaction = await connection.begin()

    session_factory = async_sessionmaker(
        bind=connection, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    session = session_factory()

    try:
        yield session
    finally:
        await session.close()
        await transaction.rollback()
        await connection.close()
        await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    app = create_app()

    async def _override_get_db_session() -> AsyncGenerator[AsyncSession, None]:
        # Mirrors the real `get_db_session`'s commit-on-success/
        # rollback-on-exception semantics — required for correctness
        # tests where a request writes something, then a business-rule
        # check raises afterward (e.g. inventory's atomic stock upsert
        # followed by a negative-stock policy check): without an actual
        # rollback here, the already-applied write would incorrectly
        # persist within this test's shared session even though the
        # request failed. `db_session`'s own outer transaction (opened
        # with `create_savepoint` join mode) still gets rolled back at
        # the end of the test either way, for isolation between tests.
        try:
            yield db_session
            await db_session.commit()
        except Exception:
            await db_session.rollback()
            raise

    app.dependency_overrides[real_get_db_session] = _override_get_db_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def signup_payload() -> dict:
    return {
        "name": "Acme Retail",
        "currency": "INR",
        "owner_email": "owner@acmeretail-example.com",
        "owner_password": "correct-horse-battery-staple",
        "owner_full_name": "Ada Owner",
    }


@pytest_asyncio.fixture
async def signed_up_owner(client: AsyncClient, signup_payload: dict) -> dict:
    """Signs up a fresh company and returns everything a test typically
    needs: tokens, ids, and an `Authorization` header ready to use."""
    response = await client.post("/api/v1/companies", json=signup_payload)
    assert response.status_code == 200, response.text
    data = response.json()["data"]
    return {
        "company_id": data["company"]["id"],
        "branch_id": data["branch"]["id"],
        "warehouse_id": data["warehouse"]["id"],
        "owner_user_id": data["owner_user_id"],
        "access_token": data["access_token"],
        "refresh_token": data["refresh_token"],
        "email": signup_payload["owner_email"],
        "password": signup_payload["owner_password"],
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
    }
