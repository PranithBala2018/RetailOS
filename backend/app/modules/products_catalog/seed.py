"""Seeded default units of measure — same pattern as
`users_roles_permissions/seed.py`'s default roles: `company_id` NULL,
shared by every tenant, extended by adding new rows via migration, never
created through the API at runtime.
"""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class UnitDef:
    name: str
    abbreviation: str


DEFAULT_UNITS: tuple[UnitDef, ...] = (
    UnitDef("Pieces", "pcs"),
    UnitDef("Kilogram", "kg"),
    UnitDef("Gram", "g"),
    UnitDef("Litre", "ltr"),
    UnitDef("Millilitre", "ml"),
    UnitDef("Box", "box"),
    UnitDef("Dozen", "dz"),
    UnitDef("Meter", "mtr"),
    UnitDef("Pair", "pair"),
    UnitDef("Set", "set"),
)
