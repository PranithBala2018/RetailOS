"""Pydantic request/response schemas for Company, Branch, and Warehouse."""

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from app.common.schemas import ORMSchema


class CompanyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    brand_name: str | None = Field(default=None, max_length=200)
    logo_url: str | None = Field(default=None, max_length=500)
    gst_number: str | None = Field(default=None, max_length=20)
    pan: str | None = Field(default=None, max_length=20)
    address_line: str | None = Field(default=None, max_length=500)
    city: str | None = Field(default=None, max_length=100)
    state: str | None = Field(default=None, max_length=100)
    country: str | None = Field(default=None, max_length=100)
    pincode: str | None = Field(default=None, max_length=20)
    mobile: str | None = Field(default=None, max_length=20)
    email: EmailStr | None = None
    website: str | None = Field(default=None, max_length=255)
    currency: str = Field(default="INR", min_length=3, max_length=3)
    timezone: str = Field(default="Asia/Kolkata", max_length=50)
    financial_year_start_month: int = Field(default=4, ge=1, le=12)
    invoice_prefix: str | None = Field(default="INV", max_length=20)
    invoice_footer: str | None = None
    default_tax_percent: Decimal | None = Field(default=None, ge=0, le=100)


class CompanyUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    brand_name: str | None = Field(default=None, max_length=200)
    logo_url: str | None = Field(default=None, max_length=500)
    gst_number: str | None = Field(default=None, max_length=20)
    pan: str | None = Field(default=None, max_length=20)
    address_line: str | None = Field(default=None, max_length=500)
    city: str | None = Field(default=None, max_length=100)
    state: str | None = Field(default=None, max_length=100)
    country: str | None = Field(default=None, max_length=100)
    pincode: str | None = Field(default=None, max_length=20)
    mobile: str | None = Field(default=None, max_length=20)
    email: EmailStr | None = None
    website: str | None = Field(default=None, max_length=255)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    timezone: str | None = Field(default=None, max_length=50)
    financial_year_start_month: int | None = Field(default=None, ge=1, le=12)
    invoice_prefix: str | None = Field(default=None, max_length=20)
    invoice_footer: str | None = None
    default_tax_percent: Decimal | None = Field(default=None, ge=0, le=100)
    is_active: bool | None = None


class CompanyRead(ORMSchema):
    id: UUID
    name: str
    brand_name: str | None
    logo_url: str | None
    gst_number: str | None
    pan: str | None
    address_line: str | None
    city: str | None
    state: str | None
    country: str | None
    pincode: str | None
    mobile: str | None
    email: str | None
    website: str | None
    currency: str
    timezone: str
    financial_year_start_month: int
    invoice_prefix: str | None
    invoice_footer: str | None
    default_tax_percent: Decimal | None
    is_active: bool
    version: int


class BranchCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    code: str = Field(min_length=1, max_length=50)
    address_line: str | None = Field(default=None, max_length=500)
    phone: str | None = Field(default=None, max_length=20)
    gst_number: str | None = Field(default=None, max_length=20)
    manager_user_id: UUID | None = None


class BranchUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    code: str | None = Field(default=None, min_length=1, max_length=50)
    address_line: str | None = Field(default=None, max_length=500)
    phone: str | None = Field(default=None, max_length=20)
    gst_number: str | None = Field(default=None, max_length=20)
    manager_user_id: UUID | None = None
    default_warehouse_id: UUID | None = None
    is_active: bool | None = None


class BranchRead(ORMSchema):
    id: UUID
    company_id: UUID
    name: str
    code: str
    address_line: str | None
    phone: str | None
    gst_number: str | None
    default_warehouse_id: UUID | None
    manager_user_id: UUID | None
    is_active: bool
    version: int


class WarehouseCreate(BaseModel):
    branch_id: UUID
    name: str = Field(min_length=1, max_length=200)
    code: str = Field(min_length=1, max_length=50)
    is_default: bool = False


class WarehouseRead(ORMSchema):
    id: UUID
    company_id: UUID
    branch_id: UUID
    name: str
    code: str
    is_default: bool
    is_active: bool
