"""Response envelope helpers matching the format defined in API.md."""

from typing import Any


def success_envelope(data: Any = None, message: str = "Operation completed") -> dict[str, Any]:
    return {"success": True, "message": message, "data": data}


def error_envelope(
    message: str = "Validation failed",
    errors: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {"success": False, "message": message, "errors": errors or []}
