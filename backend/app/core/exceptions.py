"""Application exception hierarchy and the handlers that map it onto the
response envelope defined in API.md — see SPRINT0.md §13.

Every exception raised by application code (services, repositories) should
be a subclass of AppException so it lands in the standard envelope instead
of leaking a stack trace to the client.
"""

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.common.response import error_envelope
from app.core.logging import get_logger

logger = get_logger(__name__)


class AppException(Exception):
    """Base of the application exception hierarchy.

    `code` is a stable, machine-readable identifier clients can branch on;
    `status_code` is the HTTP status the handler below will respond with.
    """

    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    code: str = "internal_error"

    def __init__(self, message: str, *, field: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.field = field


class NotFoundException(AppException):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class ValidationException(AppException):
    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT
    code = "validation_failed"


class ConflictException(AppException):
    status_code = status.HTTP_409_CONFLICT
    code = "conflict"


class UnauthorizedException(AppException):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"


class PermissionDeniedException(AppException):
    status_code = status.HTTP_403_FORBIDDEN
    code = "permission_denied"


class TenantMismatchException(AppException):
    status_code = status.HTTP_403_FORBIDDEN
    code = "tenant_mismatch"


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppException)
    async def handle_app_exception(request: Request, exc: AppException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=error_envelope(
                message=exc.message,
                errors=[{"code": exc.code, "field": exc.field, "detail": exc.message}],
            ),
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        errors = [
            {
                "code": "validation_failed",
                "field": ".".join(str(loc) for loc in err["loc"]),
                "detail": err["msg"],
            }
            for err in exc.errors()
        ]
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content=error_envelope(message="Validation failed", errors=errors),
        )

    @app.exception_handler(Exception)
    async def handle_unhandled_exception(request: Request, exc: Exception) -> JSONResponse:
        request_id = getattr(request.state, "request_id", None)
        logger.error(
            "unhandled_exception",
            request_id=request_id,
            path=request.url.path,
            exc_info=exc,
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=error_envelope(
                message="An unexpected error occurred. Please try again or contact support.",
                errors=[
                    {
                        "code": "internal_error",
                        "field": None,
                        "detail": f"request_id={request_id}" if request_id else None,
                    }
                ],
            ),
        )
