# RetailOS API Standards

## Overview

The RetailOS backend exposes RESTful APIs for all business modules. APIs should be versioned and documented.

Base URL:
/api/v1

---

## Authentication

POST   /auth/login
POST   /auth/logout
POST   /auth/refresh
POST   /auth/forgot-password
POST   /auth/reset-password        (completes forgot-password with a token)
POST   /auth/change-password       (authenticated; requires current password)
POST   /auth/switch-branch
GET    /auth/me
GET    /auth/my-branches           (the caller's own assigned branches — not
                                     gated behind the `branches.read` admin
                                     permission; every role needs this to
                                     pick a branch regardless of what they
                                     can otherwise manage)
GET    /auth/sessions              (active device sessions / refresh tokens)
DELETE /auth/sessions/{id}

Authentication:
Bearer JWT Token

Login supports `remember_me` (longer-lived refresh token), `device_id` /
`device_name` (device-session labeling). Refresh tokens rotate on every
use; presenting an already-rotated token revokes every session for that
user (see `backend/app/modules/auth/service.py`).

---

## Company

POST   /companies      (unauthenticated — company signup: creates the
                         company, a default branch + warehouse, and an
                         owner user in one transaction, then returns
                         tokens for that owner — the "Company Setup
                         Wizard" backend)
GET    /companies/{id}           (own company only, requires `company.read`)
PUT    /companies/{id}           (requires `company.update`; body includes
                                   `expected_version` — optimistic
                                   concurrency, returns 409 on conflict)

`DELETE /companies/{id}` does not exist — companies are not deletable
through this API in Sprint 2 (this is a deliberate scope decision, not
an oversight; document any future addition here when it lands).

---

## Branches

GET    /branches                          (requires `branches.read`)
POST   /branches                          (requires `branches.create`)
PUT    /branches/{id}                     (requires `branches.update`)
GET    /branches/{id}/warehouses          (requires `branches.read`)
POST   /branches/{id}/warehouses          (requires `branches.update`)

---

## Users

GET    /users                             (requires `users.read`)
POST   /users                             (requires `users.create`)
GET    /users/{id}                        (requires `users.read`)
PUT    /users/{id}                        (requires `users.update`)
DELETE /users/{id}                        (disables the account — soft,
                                            requires `users.delete`)
POST   /users/{id}/reset-password         (admin-initiated; forces
                                            must_change_password on the
                                            target account, requires
                                            `users.update`)

---

## Roles & Permissions

GET    /roles          (system-default + this company's custom roles,
                         requires `roles.read`)
GET    /permissions    (the seeded permission catalog, read-only,
                         requires `permissions.read`)

Custom-role creation (`POST /roles`) is not implemented in Sprint 2.

---

## Dashboard

GET    /dashboard/shell    (requires `dashboard.read`) — infrastructure
                            only: company/branch name, current user, role
                            names, API/DB status, version. No business
                            metrics belong here until their modules exist.

---

## Products & Catalog (Sprint 3)

Every endpoint below is scoped to the caller's own `company_id` (from the
JWT) and gated behind the matching `categories.*`/`brands.*`/`units.*`/
`products.*` permission code. See `backend/app/modules/products_catalog/api.py`
for the exact implementation.

```
GET    /categories
POST   /categories                          (requires categories.create)
GET    /categories/{id}
PUT    /categories/{id}?expected_version=N   (requires categories.update)

GET    /brands
POST   /brands                               (requires brands.create)
GET    /brands/{id}
PUT    /brands/{id}?expected_version=N       (requires brands.update)

GET    /units
POST   /units                                (requires units.create; no update — see DATABASE.md)

GET    /products?search=&category_id=
POST   /products                             (requires products.create)
GET    /products/{id}                        (returns { product, variants })
PUT    /products/{id}?expected_version=N     (requires products.update — product-level fields only)
DELETE /products/{id}?expected_version=N     (requires products.delete — soft "disable", is_active=false)

GET    /products/{id}/variants
POST   /products/{id}/variants               (requires products.update)
PUT    /product-variants/{id}?expected_version=N   (requires products.update)

GET    /product-variants/{id}/barcodes
POST   /product-variants/{id}/barcodes       (requires products.update)

GET    /products/{id}/images
POST   /products/{id}/images                 (requires products.update)

GET    /products/export                      (requires products.export — streams text/csv)
POST   /products/import                      (requires products.import — multipart file upload)
```

Every mutating endpoint that touches a versioned row (categories, brands,
products, variants) takes `expected_version` as a query parameter and
returns `409 Conflict` if it's stale — the same optimistic-concurrency
pattern as Sprint 2's Company/Branch/User endpoints.

`POST /products` accepts a `has_variants` flag: `false` synthesizes exactly
one variant from the request's top-level pricing fields (reusing the
product's SKU); `true` requires a non-empty `variants` array. There is no
way to change `sku`/`has_variants` after creation — variants are added one
at a time via `POST /products/{id}/variants` instead.

CSV import/export use a flat, one-row-per-variant format with
category/brand/unit referenced by name — see DATABASE.md's "CSV
import/export" section for the full contract and idempotency guarantee.

---

## Customers

GET /customers
POST /customers
PUT /customers/{id}

---

## Suppliers

GET /suppliers
POST /suppliers
PUT /suppliers/{id}

---

## Purchases

GET /purchases
POST /purchases

---

## Inventory

GET /inventory
POST /inventory/adjustment
POST /inventory/transfer

---

## POS

POST /sales
GET /sales/{id}
POST /sales/return

---

## Reports

GET /reports/sales
GET /reports/purchases
GET /reports/inventory
GET /reports/profit

---

## Response Format

Success

{
  "success": true,
  "message": "Operation completed",
  "data": {}
}

Error

{
  "success": false,
  "message": "Validation failed",
  "errors": []
}

---

## Security

- JWT Authentication
- HTTPS only
- Role-based authorization
- Audit logging
- Request validation
- Rate limiting

---

## Versioning

/api/v1
/api/v2
