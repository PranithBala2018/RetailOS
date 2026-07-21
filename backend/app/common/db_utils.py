"""Small SQLAlchemy typing helpers shared across repositories/services."""

from typing import Any, cast

from sqlalchemy.engine import CursorResult
from sqlalchemy.engine.result import Result


def affected_rows(result: Result[Any]) -> int:
    """`.rowcount` exists at runtime on the `CursorResult` returned for
    row-affecting statements (UPDATE/DELETE), but mypy only sees the
    generic `Result` type session.execute() is annotated to return —
    narrowing it here once instead of `# type: ignore`-ing every
    optimistic-concurrency check across the codebase.
    """
    return cast(CursorResult[Any], result).rowcount
