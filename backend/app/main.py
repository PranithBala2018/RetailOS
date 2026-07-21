"""Application factory. Registers middleware, exception handlers, and the
health endpoint. No business routers are included yet — the first one
(auth) lands in Sprint 2.
"""

from typing import Any

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.common.response import success_envelope
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging, get_logger
from app.core.middleware.request_id import RequestIdMiddleware

logger = get_logger(__name__)


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings)

    app = FastAPI(
        title=settings.project_name,
        version="0.1.0",
        docs_url="/api/v1/docs" if settings.environment != "production" else None,
        redoc_url=None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allow_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RequestIdMiddleware)

    register_exception_handlers(app)

    @app.get("/health", tags=["health"])
    async def health() -> dict[str, Any]:
        return success_envelope(
            data={"status": "ok", "environment": settings.environment},
            message="RetailOS API is running",
        )

    logger.info("app_configured", environment=settings.environment)
    return app


app = create_app()
