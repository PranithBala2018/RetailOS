"""Shared Pydantic base classes.

Wire format is snake_case throughout (matches Pydantic's default and
Python's own convention) — the Flutter side maps snake_case JSON to
camelCase Dart fields via `json_serializable`'s `fieldRename: .snake`,
per SPRINT0.md §6. No alias generators needed here.
"""

from pydantic import BaseModel, ConfigDict


class ORMSchema(BaseModel):
    """Base for any schema built from a SQLAlchemy ORM instance."""

    model_config = ConfigDict(from_attributes=True)
