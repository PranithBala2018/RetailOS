"""Cursor-based pagination primitives, per SPRINT0.md §18 — offset
pagination degrades badly on large tables, so every list endpoint uses
this shape from the start rather than retrofitting it later.
"""

from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PageParams(BaseModel):
    cursor: str | None = None
    limit: int = Field(default=25, ge=1, le=100)


class Page(BaseModel, Generic[T]):
    items: list[T]
    next_cursor: str | None = None
    has_more: bool = False
