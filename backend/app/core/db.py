"""Async SQLAlchemy engine/session wiring, per SPRINT0.md §5 and §18.

A dedicated read-only session factory is included now so reporting-style
reads can be routed to a replica connection string later (SPRINT0 §5.7,
§19) purely via configuration, without touching call sites.
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import Settings, get_settings


def create_engine(settings: Settings | None = None) -> AsyncEngine:
    settings = settings or get_settings()
    return create_async_engine(
        str(settings.database_url),
        echo=settings.db_echo,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_pre_ping=True,
    )


_engine: AsyncEngine = create_engine()
_session_factory: async_sessionmaker[AsyncSession] = async_sessionmaker(
    bind=_engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a request-scoped session.

    Tenant scoping (SET LOCAL app.current_company_id, per SPRINT0 §15) is
    wired in from Sprint 2 onward once the Identity module exists — this
    dependency is the seam that will carry it, but it stays a plain session
    until there is a real `company_id` claim to set it from.
    """
    async with _session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
