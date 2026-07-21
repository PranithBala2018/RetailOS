# RetailOS Database Design

## Database

PostgreSQL

## Design Principles

- Normalize to 3NF where practical
- Use UUIDs for primary keys
- Add created_at and updated_at timestamps
- Support soft delete where required
- Create indexes for search and reporting
- Use foreign keys to maintain integrity

## Core Tables

### Business

- companies
- branches
- users
- roles
- permissions

### Products

- categories
- brands
- products
- product_variants
- product_barcodes
- product_images

### Inventory

- stock
- stock_transactions
- stock_adjustments
- stock_transfers

### Purchases

- suppliers
- purchase_orders
- purchase_order_items
- goods_receipts
- supplier_returns

### Sales

- customers
- invoices
- invoice_items
- payments
- returns

### Finance

- expenses
- expense_categories
- tax_rates

### Reports

- audit_logs
- activity_logs
- dashboard_cache

## Naming Standards

- Table names: plural (products, customers)
- Columns: snake_case
- Primary key: id
- Foreign key: <table>_id

## Performance

- Index barcode
- Index SKU
- Index invoice number
- Index customer phone
- Index supplier code
- Optimize frequently used reports

## Backup Strategy

- Daily backup
- Weekly full backup
- Point-in-time recovery support

## Future Expansion

- Warehouse Management
- Manufacturing
- CRM
- HR & Payroll
- AI Analytics

---

## Implemented Schema (Sprint 2 — Identity & Organization)

Source of truth is always the Alembic migrations
(`backend/app/migrations/versions/`) and the SQLAlchemy models
(`backend/app/modules/*/models.py`); this section is a map, not a
substitute for reading them.

### Cross-cutting columns

Every table below except `Company` (the tenant root) and the
audit/junction tables carries: `id` (UUID, client-generatable — see
SPRINT0.md §5.1/§14.1), `created_at`/`updated_at` (timestamptz),
`deleted_at` (soft delete), `version` (optimistic concurrency),
`client_uuid`/`sync_status` (offline-sync metadata, unused until the
sync engine lands), `created_by`/`updated_by` (actor UUIDs, intentionally
not FK-constrained — see `AuditMixin`'s docstring).

### Tables

| Table | Notes |
|---|---|
| `companies` | Tenant root. No `company_id` of its own. |
| `branches` | `company_id` required. `default_warehouse_id` / `manager_user_id` are circular back-references resolved via `ForeignKey(use_alter=True)` — see the migration's module docstring for why that alone doesn't add the constraint and what had to be done instead. |
| `warehouses` | Organizational container only — no stock/quantity columns; that's real Inventory-module scope. Exists now so `branches.default_warehouse_id` has a real target. |
| `users` | `email` is **globally unique**, not company-scoped — one email is one login identity (see the model docstring for why). `failed_login_attempts`/`locked_until` implement account lockout; `must_change_password` supports admin-initiated resets. |
| `roles` | `company_id` **nullable** — NULL means a system default role (Super Admin/Admin/Manager/Cashier, seeded once, shared by every tenant); a real UUID means a company-specific custom role. |
| `permissions` | Code-defined vocabulary (`module.action`, e.g. `company.read`), seeded via migration — never created through the API. |
| `role_permissions`, `user_roles`, `user_branches` | Plain join tables. |
| `refresh_tokens` | One row = one device session. Only a SHA-256 hash of the token is stored. Rotation chains via `replaced_by_token_id`; presenting an already-rotated (revoked) token is treated as compromise (see `auth/service.py`). |
| `password_reset_tokens` | Same hash-only storage; single-use (`used_at`). |
| `audit_logs` | Append-only — no soft delete, no version, no sync metadata. Covers login history plus future entity change tracking. `company_id`/`user_id` both nullable (a failed login against an unknown email has neither). |

### Tenant isolation

Application-layer only in Sprint 2 (every repository method takes an
explicit `company_id` and filters by it) — Postgres Row-Level Security
is deliberately deferred; see `docs/adr/0003-defer-rls-policies-to-sprint-3.md`
for why (the pre-auth login lookup has no `company_id` to scope by yet).
