"""Verifies engine/session-factory construction without connecting to a
real database — actual connectivity is exercised by CI's Postgres service
container and by `docker compose up` locally (see KNOWN_ISSUES in the
Sprint 1 report; Postgres isn't available in this sandbox).
"""

from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.config import Settings
from app.core.db import create_engine


def test_create_engine_returns_async_engine() -> None:
    settings = Settings(database_url="postgresql+asyncpg://u:p@localhost:5432/db")
    engine = create_engine(settings)
    assert isinstance(engine, AsyncEngine)


def test_create_engine_uses_configured_pool_size() -> None:
    settings = Settings(db_pool_size=7, db_max_overflow=3)
    engine = create_engine(settings)
    assert engine.pool.size() == 7


def test_create_engine_respects_echo_setting() -> None:
    settings = Settings(db_echo=True)
    engine = create_engine(settings)
    assert engine.echo is True
