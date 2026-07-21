# RetailOS — Sprint 0: Architecture Finalization

Status: **Finalized for implementation.** No application code has been written against this document. Any deviation from a decision below during implementation requires an explicit ADR (see §24) before the deviation is coded.

---

## 1. Final Project Architecture

### 1.1 System topology

```
                         ┌────────────────────────┐
                         │   Flutter Clients       │
                         │ Android / Windows       │
                         │ (Web / iOS — future)    │
                         └───────────┬─────────────┘
                                     │ HTTPS (Dio) + local Drift SQLite
                                     ▼
                         ┌────────────────────────┐
                         │   Nginx / Traefik       │  ← TLS termination, reverse proxy
                         └───────────┬─────────────┘
                                     ▼
                    ┌────────────────────────────────┐
                    │   FastAPI app (stateless,        │
                    │   horizontally scaled replicas)  │
                    │  - REST API /api/v1               │
                    │  - Auth middleware (JWT)          │
                    │  - Tenant-context middleware      │
                    └───────┬───────────────┬──────────┘
                            │               │
                    ┌───────▼──────┐   ┌────▼─────┐
                    │ PostgreSQL   │   │  Redis    │  ← cache, rate limit, Celery broker
                    │ (primary +   │   └────┬─────┘
                    │ read replica)│        │
                    └──────────────┘   ┌────▼─────┐
                                        │ Celery    │  ← background jobs (future, but
                                        │ workers + │     interface stubbed from Sprint 1)
                                        │ beat      │
                                        └──────────┘
```

### 1.2 Architectural style

- **Backend: modular monolith**, not microservices. At current team size, microservices add operational cost (service discovery, distributed tracing, network failure handling) without a corresponding benefit. Modules are isolated by strict internal boundaries (see §2) so that extraction into services later is possible without a rewrite — the discipline is enforced now, the deployment split happens only if scale ever demands it.
- **Frontend: Clean Architecture, feature-first.** Each feature owns its `domain` / `data` / `presentation` layers. Cross-feature communication happens through the `domain` layer only (interfaces), never by importing another feature's `data` or `presentation` code.
- **Bounded contexts** (module groups that own their data and expose it to others only through service interfaces, never direct cross-module DB queries):
  1. **Identity** — Auth, Users, Roles, Permissions, Company, Multi-business
  2. **Catalog** — Products, Categories, Brands, Units, Barcode
  3. **Trade** — Suppliers, Purchases, Customers, Sales, POS, Returns, Invoices, Payments
  4. **Inventory** — Stock, Adjustments, Transfers
  5. **Finance** — Expenses, GST/Tax, Reports (financial)
  6. **Platform** — Notifications, Settings, Sync, Audit
  7. **Intelligence** — AI Analytics, Forecasting, Assistant (reads from the above, never writes back except through the Trade/Inventory service interfaces)
- **Cross-module side effects use domain events**, not direct calls. Example: `SaleCompleted` event → Inventory module decrements stock, Finance module records tax liability, Platform module queues a notification. Implemented in Sprint 1 as an in-process event bus (simple pub/sub via a registry); can be swapped for Redis Streams/Kafka later without changing publishers or subscribers.

---

## 2. Folder Structure

### 2.1 Repository layout (monorepo)

A single repo is correct here: frontend and backend evolve together (shared API contract, shared sprint cadence, one team). Split only if a second independent team is added.

```
RetailOS/
├── backend/
├── frontend/
├── database/            # standalone SQL reference + seed data, ERD source
├── docs/                 # architecture, ADRs, runbooks
├── .github/workflows/    # CI/CD pipelines
├── docker-compose.yml    # local dev stack
├── ARCHITECTURE.md
├── DATABASE.md
├── API.md
├── TASKS.md
├── SPRINT0.md
└── CLAUDE.md
```

### 2.2 Backend (`backend/`)

```
backend/
├── app/
│   ├── core/
│   │   ├── config.py            # pydantic-settings, per-env
│   │   ├── db.py                 # async engine/session factory
│   │   ├── security.py           # JWT encode/decode, password hashing
│   │   ├── tenant_context.py     # sets/reads current company_id (contextvar)
│   │   ├── middleware/
│   │   │   ├── auth.py
│   │   │   ├── tenant.py
│   │   │   ├── request_id.py
│   │   │   └── rate_limit.py
│   │   ├── exceptions.py         # AppException hierarchy
│   │   └── events.py             # in-process domain event bus
│   ├── common/
│   │   ├── base_model.py         # SQLAlchemy declarative base + mixins
│   │   ├── pagination.py
│   │   ├── response.py           # success/error envelope helpers
│   │   └── schemas.py            # shared Pydantic base schemas
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── api.py             # FastAPI router
│   │   │   ├── schemas.py         # Pydantic request/response
│   │   │   ├── models.py          # SQLAlchemy ORM
│   │   │   ├── service.py         # business logic
│   │   │   ├── repository.py      # DB access
│   │   │   └── exceptions.py
│   │   ├── company/
│   │   ├── users_roles_permissions/
│   │   ├── products_catalog/
│   │   ├── inventory/
│   │   ├── purchases/
│   │   ├── sales_pos/
│   │   ├── customers/
│   │   ├── suppliers/
│   │   ├── invoices_payments/
│   │   ├── expenses/
│   │   ├── gst_tax/
│   │   ├── reports/
│   │   ├── dashboard/
│   │   ├── notifications/
│   │   ├── settings/
│   │   ├── sync/                  # sync push/pull endpoints, cursors, conflicts
│   │   ├── audit/
│   │   └── ai/                    # analytics, forecasting, assistant (later sprint)
│   ├── migrations/                # Alembic
│   └── main.py                    # app factory, router registration
├── tests/
│   ├── unit/
│   ├── integration/
│   └── api/
├── alembic.ini
├── pyproject.toml
├── Dockerfile
└── docker-compose.override.yml
```

Rule: a module may import another module's `schemas.py` (its public contract) but never its `models.py` or `repository.py`. Cross-module reads go through the other module's `service.py`.

### 2.3 Frontend (`frontend/`)

```
frontend/
├── lib/
│   ├── core/
│   │   ├── di/                    # riverpod provider wiring, get_it for non-widget scope
│   │   ├── router/                 # go_router config + route guards
│   │   ├── network/                # dio client, interceptors (auth, retry, logging)
│   │   ├── database/                # drift database, DAOs, migrations
│   │   ├── sync/                    # sync engine, queue drainer, conflict handling
│   │   ├── error/                   # Failure types (freezed), Result<T>
│   │   ├── theme/
│   │   ├── localization/
│   │   └── utils/
│   ├── features/
│   │   ├── auth/
│   │   │   ├── domain/               # entities, repository interfaces, usecases
│   │   │   ├── data/                  # models, remote/local datasources, repo impl
│   │   │   └── presentation/          # screens, widgets, riverpod providers
│   │   ├── company/
│   │   ├── products/
│   │   ├── inventory/
│   │   ├── purchases/
│   │   ├── pos/
│   │   ├── customers/
│   │   ├── suppliers/
│   │   ├── invoices/
│   │   ├── reports/
│   │   ├── dashboard/
│   │   ├── notifications/
│   │   ├── settings/
│   │   └── ai/
│   ├── app.dart
│   └── main.dart
├── test/
│   ├── unit/
│   └── widget/
├── integration_test/
└── pubspec.yaml
```

Rule: `presentation` depends on `domain` only. `data` implements `domain` interfaces. No feature imports another feature's `data` or `presentation`; shared logic moves to `core` or a `shared/` package if reused by 3+ features.

---

## 3. Flutter Package Selection

| Concern | Package | Notes |
|---|---|---|
| State management | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | codegen-based providers, compile-time safety |
| Routing | `go_router` | declarative, supports guards for auth/tenant redirect |
| Networking | `dio` | interceptor chain: auth header injection, refresh-on-401, structured logging |
| Local DB | `drift`, `sqlite3_flutter_libs`, `drift_dev` | typed SQL, migrations, reactive streams for offline-first UI |
| Immutability/unions | `freezed`, `freezed_annotation` | entities, Failure types, sealed sync states |
| Serialization | `json_serializable`, `json_annotation` | `fieldRename: FieldRename.snake` to match API's snake_case JSON |
| Functional error handling | `fpdart` | `Either<Failure, T>` at repository boundary |
| Secure storage | `flutter_secure_storage` | JWT/refresh token storage (Keystore/DPAPI-backed) |
| Connectivity | `connectivity_plus` | drives sync-trigger and offline-banner UI |
| Background sync (Android) | `workmanager` | periodic + on-reconnect sync; Windows uses in-app `Timer` + tray-resident isolate since WorkManager is Android-only |
| Localization | `flutter_localizations`, `intl` | ARB-based, multi-language from Sprint 1 |
| Responsive layout | `flutter_screenutil` or `responsive_framework` | breakpoints for phone/tablet/desktop |
| Barcode/QR | `mobile_scanner` | camera-based scanning; HID scanners need no plugin (keyboard emulation) |
| Printer/hardware | `flutter_pos_printer_platform`, `esc_pos_utils`, `usb_serial` | wrapped behind an internal `PrinterDriver` interface (see §16 hardware note) |
| Env config | `envied` | compile-time injected, avoids bundling secrets as plain assets |
| Crash/error reporting | `sentry_flutter` | prod only |
| Logging | `logger` | structured, wrapped by `core/error` to also forward to Sentry breadcrumbs |
| Testing | `flutter_test`, `integration_test`, `mocktail`, `golden_toolkit` | see §20 |
| Linting | `flutter_lints` (extended with stricter custom rules) | enforced in CI |

Dependency policy: pin exact versions in `pubspec.lock` (committed), bump deliberately via a scheduled dependency-review sprint task, not ad hoc.

---

## 4. Python Package Selection

| Concern | Package | Notes |
|---|---|---|
| Framework | `fastapi` | async-first |
| ASGI server | `uvicorn[standard]` (dev), `gunicorn` + `uvicorn.workers.UvicornWorker` (prod, multi-process) |
| ORM | `sqlalchemy>=2.0` (async) | 2.x async ORM, typed |
| DB driver | `asyncpg` | fastest async Postgres driver |
| Migrations | `alembic` | one migration per PR touching schema, reviewed like code |
| Validation/schemas | `pydantic>=2`, `pydantic-settings` | request/response schemas, typed settings |
| Auth | `pyjwt`, `passlib[bcrypt]` (or `argon2-cffi`) | JWT signing; **Argon2id preferred** for new password hashes, bcrypt kept only for verifying legacy hashes if ever migrated from elsewhere |
| Background jobs | `celery`, `redis` (broker/backend) | stubbed in Sprint 1 interface, activated when a real async workload exists (report generation, bulk import) — see §23 risk on premature infra |
| Cache | `redis` (`redis.asyncio`) | product/price lookups, rate-limit counters |
| Outbound HTTP | `httpx` (async) | webhooks, SMS/WhatsApp/email provider calls |
| Rate limiting | `slowapi` or custom Redis token-bucket | per-tenant + per-IP limits |
| Logging | `structlog` | JSON logs, request-id bound per request |
| File uploads | `python-multipart` | product images, CSV import |
| Testing | `pytest`, `pytest-asyncio`, `pytest-cov`, `factory_boy`, `faker`, `testcontainers[postgres]` | real Postgres in CI via testcontainers, not SQLite-in-memory (avoids Postgres-only feature drift, e.g. RLS) |
| Lint/format | `ruff` | replaces flake8+black+isort in one tool |
| Type checking | `mypy` | strict mode on `app/core` and `app/common`, module-by-module elsewhere |
| Pre-commit | `pre-commit` | ruff, mypy, alembic-check, secret-scan hooks |
| Error tracking | `sentry-sdk[fastapi]` | prod only |
| API docs | built into FastAPI (OpenAPI/Swagger) | published at `/api/v1/docs` (staging only, disabled in prod or behind auth) |

Dependency policy: `pyproject.toml` with pinned versions via `uv.lock` or `poetry.lock` (committed); Dependabot/Renovate enabled for automated PRs, merged only after CI passes.

---

## 5. Database Architecture

### 5.1 Cross-cutting column conventions

Every tenant-scoped table includes:

```
id               UUID PRIMARY KEY DEFAULT gen_random_uuid()
company_id       UUID NOT NULL REFERENCES companies(id)
branch_id        UUID REFERENCES branches(id)          -- nullable only for company-wide entities
created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
created_by       UUID REFERENCES users(id)
updated_by       UUID REFERENCES users(id)
deleted_at       TIMESTAMPTZ                            -- soft delete; NULL = active
version          INTEGER NOT NULL DEFAULT 1              -- optimistic concurrency
client_uuid      UUID                                     -- set when the record originated offline; NULL if server-originated
sync_status      TEXT NOT NULL DEFAULT 'synced'          -- synced | pending | conflict
```

- Money columns: `NUMERIC(14,2)` minimum (never `FLOAT`/`DOUBLE`).
- `id` is always the client-generatable UUID (v7, time-ordered) — this is what makes offline record creation collision-free (see §14).
- Soft delete: enforced via unique constraints scoped as `UNIQUE (company_id, sku) WHERE deleted_at IS NULL` (partial indexes), not plain unique constraints, so a deleted SKU can be reused.

### 5.2 Representative core schema (illustrative, not exhaustive — full DDL is written per-module during its sprint)

| Domain | Tables |
|---|---|
| Identity | `companies`, `branches`, `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `refresh_tokens` |
| Catalog | `categories`, `brands`, `units`, `products`, `product_variants`, `product_barcodes`, `product_images`, `price_lists`, `price_list_items` |
| Inventory | `stock`, `stock_transactions`, `stock_adjustments`, `stock_transfers`, `product_batches` (expiry-tracked) |
| Trade | `suppliers`, `purchase_orders`, `purchase_order_items`, `goods_receipts`, `supplier_returns`, `customers`, `invoices`, `invoice_items`, `payments`, `payment_methods`, `sales_returns`, `loyalty_ledger` |
| Finance | `expenses`, `expense_categories`, `tax_rates`, `tax_rules` |
| Platform | `notifications`, `settings`, `audit_logs`, `activity_logs`, `sync_queue`, `sync_cursors`, `sync_conflicts` |

### 5.3 Multi-tenancy enforcement at the DB layer

Postgres **Row-Level Security** is enabled on every tenant-scoped table as a backstop against a forgotten `WHERE company_id = ...` in application code:

```sql
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON products
  USING (company_id = current_setting('app.current_company_id')::uuid);
```

The API sets `app.current_company_id` via `SET LOCAL` at the start of every request transaction, populated from the JWT's `company_id` claim by tenant middleware (§15). Application-level `WHERE company_id = :id` filtering is still required (RLS is defense-in-depth, not a substitute for correct queries — it also avoids a full-table-scan-then-filter performance trap).

### 5.4 Indexing

- Every tenant-scoped table: composite index with `company_id` as the leading column, e.g. `(company_id, sku)`, `(company_id, created_at DESC)`.
- `products.barcode`, `products.sku`, `customers.phone`, `suppliers.code`, `invoices.invoice_number` — indexed, scoped by `company_id`.
- Partial indexes for soft-delete-aware uniqueness (see §5.1).

### 5.5 Partitioning

`stock_transactions`, `invoices`, `audit_logs`, `activity_logs` are declared as **range-partitioned by month** from day one (even before volume demands it) — retrofitting partitioning onto a live high-write table is far more disruptive than declaring it upfront.

### 5.6 Migrations

Alembic; one migration per schema-changing PR. Every migration must have a working `downgrade()`. CI runs `alembic upgrade head` then `alembic downgrade -1` then `alembic upgrade head` again against a fresh testcontainer DB to catch irreversible migrations before merge.

### 5.7 Read scaling

A read replica is provisioned from the start of staging; reporting/dashboard queries route through a read-only session; transactional queries always hit the primary.

---

## 6. Naming Conventions

| Layer | Convention | Example |
|---|---|---|
| DB tables | plural, snake_case | `purchase_orders` |
| DB columns | snake_case | `invoice_number` |
| DB primary key | `id` (UUID) | |
| DB foreign key | `<singular_table>_id` | `company_id`, `supplier_id` |
| API JSON (wire format) | snake_case | `{"invoice_number": "INV-0001"}` |
| Dart fields | lowerCamelCase (mapped from snake_case JSON via `json_serializable`) | `invoiceNumber` |
| Python modules/functions | snake_case | `create_purchase_order()` |
| Python classes | PascalCase | `PurchaseOrderService` |
| Dart classes | PascalCase | `PurchaseOrderRepository` |
| Dart files | snake_case | `purchase_order_repository.dart` |
| REST URL paths | kebab-case, plural resources | `/purchase-orders/{id}` |
| Git branches | `type/short-description` | `feat/pos-split-payments`, `fix/stock-oversell-race` |
| Git commits | Conventional Commits | `feat(pos): add split payment support` |
| Environment variables | UPPER_SNAKE, prefixed by service | `API_DATABASE_URL`, `API_JWT_SECRET` |

---

## 7. Coding Standards

**Python**
- Formatting/linting: `ruff` (format + lint), zero warnings on merge.
- Type hints mandatory on all function signatures; `mypy --strict` on `core`/`common`.
- No bare `except:`; always catch specific exceptions or the project's `AppException` base.
- Business logic lives in `service.py`, never in `api.py` (routers stay thin: parse request → call service → return response).
- Docstrings only where behavior isn't obvious from the signature (matches project-wide comment policy — no restating what the code does).

**Dart/Flutter**
- `flutter_lints` + custom rule set (`avoid_print`, enforce `const` constructors, max file length guidance).
- Widgets are either pure presentation (no business logic, no direct provider calls beyond reading state) or containers (wire providers to presentation widgets) — never both.
- No business logic in widgets; it lives in `domain/usecases` and is exposed via Riverpod notifiers.
- All async UI state modeled as `AsyncValue` (Riverpod) — no manual `isLoading` booleans.

**Both**
- No TODOs left in merged code (matches CLAUDE.md — if it's not done, it's not merged).
- Cyclomatic complexity flagged by linter above threshold requires a justified exception comment or a refactor.
- Architecture Decision Records (ADRs) required for any deviation from this document — stored in `docs/adr/NNNN-title.md`, one file per decision, never edited after acceptance (superseded by a new ADR instead).

---

## 8. Git Workflow

- **Trunk-based**, not GitFlow: `main` is always releasable. Short-lived feature branches (`feat/*`, `fix/*`) branch from `main`, merge back via PR within days, not weeks.
- `main` is protected: PR required, CI must pass (lint, type-check, tests, coverage gate), squash-merge only (keeps history linear and readable).
- No `develop` branch — it adds sync overhead without benefit at this team size; revisit only if a second team stream is added.
- Conventional Commits enforced via commit-lint pre-commit hook; commit messages drive future changelog generation.
- Release tags: `vMAJOR.MINOR.PATCH`, cut from `main` at each production deploy.

## 9. Branch Strategy

```
main ─────●───────●───────●───────●──────▶  (always deployable, tagged at releases)
           \      /\      /\      /
            feat/x  fix/y  feat/z          (short-lived, deleted after merge)

release/x.y.z branches only if a release needs stabilization
  independent of ongoing main development (rare at this stage;
  created on demand, not a permanent branch type)

hotfix/x.y.z branches from the release tag directly, merged back
  into main immediately after deploy
```

---

## 10. Environment Strategy

| Environment | Purpose | Data | Deploy trigger |
|---|---|---|---|
| **Development** | Local dev loop | Seeded synthetic data | Manual (`docker-compose up`) |
| **Testing/CI** | Automated test runs | Ephemeral, testcontainers | Every PR |
| **Staging** | UAT, pre-prod validation, demo | Anonymized/synthetic, prod-like volume | Auto-deploy on merge to `main` |
| **Production** | Live tenants | Real | Manual promotion from staging, approval-gated |

Each environment has its own database, its own secret set, and its own `.env` (never shared). Config loaded via `pydantic-settings` reading environment variables only — no environment-conditional code branches beyond config values.

---

## 11. Secrets Management

| Environment | Mechanism |
|---|---|
| Local dev | `.env` (gitignored) sourced from committed `.env.example` with placeholder values |
| CI | GitHub Actions **Encrypted Secrets**, injected as job env vars |
| Staging/Production | Cloud secret manager (AWS Secrets Manager / GCP Secret Manager / Doppler — final choice pinned to hosting decision in §22) injected at container start; never baked into Docker images, never committed |

Rules:
- JWT signing key is designed to support rotation from day one (`kid` header in JWT, key lookup table) even though only one key is active initially.
- Database credentials, JWT secret, Redis URL, third-party API keys (SMS/WhatsApp/email/payment gateway) all sourced the same way — no exceptions for "just this one."
- Pre-commit hook runs a secret scanner (`detect-secrets` or `gitleaks`) to block accidental commits.

---

## 12. Logging Strategy

**Backend**: `structlog`, JSON-formatted output. Every request gets a `request_id` (from `X-Request-ID` header or generated) bound to the log context for its full lifecycle, plus `company_id` and `user_id` once authenticated — this makes every log line traceable to a tenant and actor without manual tagging at each call site.

**Frontend**: `logger` package wrapping structured entries; breadcrumbs forwarded to Sentry in release builds. Logs written locally (rotated file) so offline devices retain a debug trail even without connectivity; synced to the backend only as opt-in diagnostic upload, never automatically (privacy).

**Levels**: `DEBUG` (dev only), `INFO` (business events: sale completed, sync run), `WARNING` (retryable failures, conflict detected), `ERROR` (unhandled exceptions, failed sync after retries exhausted).

**Retention**: application logs 30 days hot / 1 year cold storage. `audit_logs` (DB table, distinct from application logs) retained indefinitely — it's a compliance/business record, not a debug artifact.

---

## 13. Error Handling Strategy

**Backend**: a single `AppException` hierarchy (`NotFoundException`, `ValidationException`, `ConflictException`, `PermissionDeniedException`, `TenantMismatchException`, …), each carrying an HTTP status and a machine-readable `code`. One FastAPI exception handler maps every `AppException` (and a catch-all for unhandled ones) to the response envelope already defined in `API.md`:

```json
{ "success": false, "message": "human-readable summary", "errors": [{"code": "STOCK_INSUFFICIENT", "field": null, "detail": "..."}] }
```

Unhandled exceptions are never leaked to the client (no stack traces in response bodies outside `development`); they're logged with full context and returned as a generic `500` with a correlation `request_id` the user can report.

**Frontend**: repository layer returns `Either<Failure, T>` (fpdart) — no exceptions cross the `domain`/`presentation` boundary. `Failure` is a `freezed` sealed class (`NetworkFailure`, `ServerFailure`, `CacheFailure`, `ValidationFailure`, `ConflictFailure`, `AuthFailure`). Presentation layer pattern-matches on `Failure` to decide UI treatment (retry banner, form error, forced re-login). No feature is allowed to swallow a `Left` silently — CI lint rule flags unhandled `Either` results.

---

## 14. Offline Synchronization Design

### 14.1 Principles

1. Every write happens to local Drift SQLite **first**; the UI never blocks on network.
2. Every locally originated record gets a **client-generated UUIDv7** (time-ordered) as its permanent `id` — this is the same `id` the server will use, so there is no ID-remapping step after sync, ever.
3. Every mutation (create/update/delete) is appended to a local `sync_queue` table — the queue is the single source of truth for "what still needs to leave this device."

### 14.2 Sync queue (local, Drift)

```
sync_queue(
  queue_id        INTEGER PRIMARY KEY AUTOINCREMENT,  -- local-only, never synced
  entity_table    TEXT,
  entity_id       TEXT (UUID),
  operation       TEXT,       -- create | update | delete
  payload         TEXT (JSON),
  created_at      TIMESTAMP,
  retry_count     INTEGER DEFAULT 0,
  status          TEXT        -- pending | in_flight | failed | done
)
```

### 14.3 Push/pull cycle

- **Push**: on reconnect (via `connectivity_plus`) and on a periodic timer, the sync engine batches `pending` queue entries (ordered by `created_at`, capped per batch) and `POST`s them to `/api/v1/sync/push`. Success marks them `done` and deletes them; failure increments `retry_count` with exponential backoff (`WorkManager` periodic constraint on Android; in-app timer on Windows).
- **Pull**: device holds a `sync_cursors(device_id, company_id, last_synced_version)` watermark. `GET /api/v1/sync/pull?since=<cursor>` returns all server-side changes (across entities the device is scoped to) since that watermark; device applies them locally and advances the cursor.
- Idempotency: because `id` is client-generated and stable, replaying a push batch after a dropped response is a no-op upsert on the server — no duplicate-record risk.

### 14.4 Conflict resolution policy

| Field category | Strategy |
|---|---|
| Descriptive fields (name, notes, address, non-financial metadata) | **Last-write-wins**, compared by `updated_at`. Simple, low-risk if wrong. |
| Stock quantities | **Server-authoritative recompute.** The server never blindly applies a client's absolute stock number; it applies the client's *delta* (e.g., "−2 units sold") against the current server value inside a row-locked transaction. If the resulting stock would go negative, the server accepts the sale (configurable per business: allow negative stock) but writes a `sync_conflicts` record and flags it for the owner's review — the sale is never silently lost. |
| Invoices/payments (immutable once created) | Never merged. A conflicting local invoice is treated as a **new, additional record**; invoices are append-only by design, so there's nothing to conflict — this is why POS transactions must never be modeled as "editable" rows. |
| Deletes vs. concurrent edits | Delete wins only if the edit's `updated_at` predates the delete; otherwise the delete is rejected and logged as a conflict (prevents silently discarding a concurrent edit). |

All conflicts are written to `sync_conflicts(id, company_id, entity_table, entity_id, client_payload, server_payload, resolution, created_at)` for audit, and surfaced in-app as a dismissible notification — never a silent data change the user can't see.

### 14.5 Sequence (happy path)

```
Cashier completes sale offline
   → Drift: invoice + invoice_items + stock_transaction written locally, UI updates instantly
   → sync_queue: 3 entries appended (status=pending)
   ... connectivity restored ...
   → Sync engine drains queue → POST /sync/push (batched)
   → Server: validates tenant scope, re-applies stock delta transactionally, persists
   → Server returns per-item ack (success/conflict) + new pull cursor
   → Device: marks queue entries done, advances cursor, surfaces any conflict notices
```

---

## 15. Multi-Tenancy Implementation Design

- **Model**: shared PostgreSQL database, `company_id` on every tenant-scoped table (see §5), enforced by RLS (§5.3).
- **Tenant context propagation**: JWT access token carries `company_id` (and `branch_id` where relevant) as claims. FastAPI tenant middleware reads the claim after auth middleware validates the token, and issues `SET LOCAL app.current_company_id = :id` at the start of the request's DB transaction. No handler ever trusts a `company_id` passed in a request body/query for authorization purposes — it always comes from the token.
- **Cross-branch/company aggregation** (for an owner viewing consolidated reports across branches or multiple owned companies): a distinct `reports` service endpoint accepts a list of `company_id`s the authenticated user has a role on, explicitly bypassing the single-tenant RLS assumption via a scoped, audited query path — never a blanket RLS bypass.
- **Invoice numbering**: sequential and **per-branch**, generated via a `SELECT ... FOR UPDATE` on a `branch_invoice_counters` row (not `nextval` on a shared sequence) so numbering stays gap-free and legally compliant per branch.
- **Future dedicated-database enterprise tenants**: the application-layer service/repository interfaces are tenant-agnostic (they never construct raw SQL outside the repository layer), so routing a specific `company_id` to a different database connection later is a configuration change in a connection-resolution layer, not a business-logic rewrite. This path is designed for now, not built now.

---

## 16. Security Architecture

**Defense in depth, layered:**

1. **Transport**: HTTPS only, HSTS enabled, TLS termination at the reverse proxy.
2. **AuthN**: JWT access tokens (short-lived, 15 min) + refresh tokens (rotating, revocable, stored hashed in `refresh_tokens` with device binding). Logout revokes the refresh token server-side; access tokens are stateless but short-lived enough to bound the exposure window.
3. **Password storage**: Argon2id.
4. **AuthZ**: RBAC — `roles` → `role_permissions` → `permissions`, checked per-endpoint via a FastAPI dependency (`require_permission("pos.sale.create")`), never inferred from role name string-matching in handler code.
5. **Tenant isolation**: RLS backstop (§5.3, §15) in addition to application-level filtering.
6. **Input validation**: Pydantic schemas at every API boundary; SQLAlchemy parameterized queries exclusively (no raw string SQL interpolation, enforced by lint rule).
7. **Rate limiting**: Redis-backed, per-IP and per-`company_id`, tuned tighter on `/auth/*`.
8. **Secrets**: §11.
9. **Data at rest**: managed Postgres encryption at rest; local Drift SQLite encrypted via SQLCipher on-device; `flutter_secure_storage` for tokens (Android Keystore / Windows DPAPI-backed).
10. **PII/payment data**: card data is never stored — payment capture is tokenized through a gateway; only a gateway reference + last-4 is persisted.
11. **Audit**: `audit_logs` captures actor, action, entity, before/after diff, IP, device_id for every mutating action on financially or legally sensitive entities (invoices, payments, stock adjustments, user/role changes).
12. **MFA**: designed into the `users` schema (`mfa_secret`, `mfa_enabled`) from Sprint 1 even though enforcement ships later — retrofitting the column later would require a migration touching a live auth table.
13. **Dependency hygiene**: Dependabot/Renovate + `pip-audit`/`npm audit`-equivalent in CI; blocks merge on known-critical CVEs.
14. **Hardware integration boundary**: all printer/scanner/scale drivers sit behind an internal interface (`PrinterDriver`, `ScannerDriver`) so a compromised or buggy third-party plugin can't reach application state directly — it only emits typed events the app chooses to act on.

---

## 17. API Versioning Strategy

- URL-based versioning: `/api/v1`, future breaking changes ship as `/api/v2` running **side-by-side** with `v1` until all clients (Android/Windows devices in the field, which can lag behind server deploys) have migrated.
- A version is deprecated only after: (a) a successor version has shipped, (b) a deprecation window of at least 2 minor app releases has passed, (c) telemetry shows negligible traffic on the old version.
- Non-breaking changes (new optional field, new endpoint) ship within the current version — no version bump required.
- `Deprecation` and `Sunset` HTTP headers returned on deprecated-version responses so clients can surface an upgrade prompt.

---

## 18. Performance Strategy

- **Caching**: Redis for product/price/catalog lookups (short TTL + explicit invalidation on write, not TTL-only staleness tolerance for price data).
- **Pagination**: cursor-based (not offset) on all list endpoints returning more than a page — offset pagination degrades badly on large `invoices`/`stock_transactions` tables.
- **N+1 prevention**: SQLAlchemy relationships default to explicit `selectinload`/`joinedload` at the repository layer; CI includes a query-count assertion on key report endpoints.
- **Connection pooling**: PgBouncer in front of Postgres for the API's connection pool, sized for horizontal API replica count.
- **Async offload**: report generation, CSV import/export, and bulk operations run via Celery (§4) rather than blocking a request thread.
- **Client-side**: Drift queries indexed to match UI access patterns; product lists use lazy/virtualized rendering (`ListView.builder`) for 10k+ SKU catalogs; images cached via `cached_network_image`-style disk cache.
- **Budgets** (enforced via load test gates in staging, §21): POS "add item to cart" < 100ms local; checkout submit (server round trip) < 500ms p95; dashboard load < 1.5s p95.

---

## 19. Scalability Strategy

- API is fully stateless — horizontal scaling is just adding replicas behind the load balancer; session state lives only in the JWT/Redis, never in-process.
- Postgres: read replica for reporting workload (§5.7); partitioning (§5.5) keeps hot tables' working set bounded as history grows.
- Redis and Celery workers scale independently of the API tier.
- Heavy/async work (imports, reports, notifications, AI inference) is queue-decoupled from the request/response path so a spike in one doesn't degrade POS checkout latency.
- Static assets (product images) served via CDN once volume warrants it — object storage (S3-compatible) from the start so this is a config change, not a migration.
- On-premise deployments (§22) use the same container images as SaaS — scalability posture doesn't fork into a second codebase.

---

## 20. Testing Strategy

**Pyramid, both stacks:**

| Layer | Backend | Frontend |
|---|---|---|
| Unit | `pytest` — services, repositories (mocked DB) | `flutter_test` — usecases, notifiers, mappers |
| Integration | `pytest` + `testcontainers[postgres]` — real DB, real migrations | Drift DAO tests against an in-memory/test SQLite instance |
| API/contract | `pytest` + `httpx` async client against a running app instance | — |
| Widget | — | `flutter_test` widget tests per screen/component |
| Golden | — | `golden_toolkit` for pixel-critical screens (POS billing screen, receipt preview) |
| E2E | Postman/newman or `httpx`-driven smoke suite against staging | `integration_test` — full flows: login → sell → offline sale → reconnect sync |

- **Coverage gate: 80%+ on new/changed code**, enforced in CI (not a global ratchet that blocks on legacy gaps — measured via diff coverage).
- Test data via `factory_boy`/`faker` (backend) and fixture builders (frontend) — no hand-maintained fixture JSON blobs that drift from the schema.
- Sync engine and stock-concurrency logic (the two highest-risk areas, §14, §23) require integration tests simulating concurrent/offline scenarios explicitly, not just unit-level happy path.
- Every PR touching a module requires tests for that module; PRs cannot merge with reduced diff coverage.

---

## 21. CI/CD Strategy

GitHub Actions, path-filtered so backend/frontend pipelines run independently:

```
On PR →
  lint (ruff / flutter_lints)
  → type-check (mypy / dart analyze)
  → unit tests
  → integration tests (testcontainers spins real Postgres)
  → build (docker image / flutter build --debug)
  → coverage gate (diff coverage ≥ 80%)
  → migration reversibility check (alembic upgrade/downgrade/upgrade)

On merge to main →
  full test suite
  → build release artifacts (docker image tagged with commit SHA / flutter release builds)
  → auto-deploy to Staging
  → smoke test against Staging

Manual promotion (approval gate) →
  deploy the same artifact (never rebuilt) to Production
  → post-deploy smoke test
  → automatic rollback trigger if smoke test fails
```

Key rule: the artifact deployed to production is byte-identical to the one validated on staging — never rebuilt between environments.

---

## 22. Deployment Architecture

- **Local dev**: `docker-compose.yml` — Postgres, Redis, API, (Celery worker optional, off by default until needed). Flutter runs natively against this stack.
- **SaaS (managed) topology**: containerized API behind a load balancer, N replicas, managed Postgres with a read replica, managed Redis, Celery workers as a separate deployment, object storage for assets. Cloud provider left open (AWS/GCP/Azure) — the Docker-based design doesn't lock in a vendor.
- **On-premise topology**: the same Docker images distributed as a `docker-compose` bundle (small deployments) or a Helm chart (larger self-hosted installs) for enterprise customers who require self-hosting — this is why on-prem was scoped as a deployment-config concern, not a separate codebase, back in §1.
- **Blue-green / rolling deploy**: new replica set brought up healthy before old set is drained, so a deploy never drops in-flight POS requests.
- **Database migrations**: run as a separate, explicit pre-deploy step (not on container boot) so a failed migration blocks the deploy rather than partially applying under load.

---

## 23. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Riverpod + Drift + Freezed + go_router is a codegen-heavy stack (`build_runner`); generated files drifting from source is a real failure mode | CI step fails the build if `build_runner build` produces a diff against committed generated files |
| Celery/Redis introduced as infra before there's a real async workload | Sprint 1–N use FastAPI `BackgroundTasks` for simple cases; Celery is activated only when a genuine long-running job (bulk import, scheduled report) exists — avoid running infrastructure nobody uses yet |
| RLS + application-level filtering is duplicated logic that can drift | Integration test suite includes an explicit "tenant isolation" test class run against every new table: attempt cross-tenant read/write, assert rejection at both the RLS and application layer |
| Offline sync + stock concurrency remains the hardest problem in this system even with a design in hand | Build the sync engine and the stock-delta reconciliation as a Sprint 1–2 spike with dedicated integration tests before any dependent module (POS, Inventory) is built on top of it |
| Solo/small team against an enterprise-scope module list (30+ modules including future manufacturing/vision-inspection) | MVP is explicitly Phases mapped in §26 up to POS + Reports; everything past that ships only after the MVP is in real merchants' hands |
| Hardware fragmentation (printers/scanners/scales across many vendors) | All hardware access goes through an internal driver interface (§16); ship 2–3 common ESC/POS-compatible drivers first, add vendors on demand rather than trying to support everything upfront |
| GST/tax rule changes over time | Tax logic isolated in the `gst_tax` module behind a rules-table-driven engine, not hardcoded conditionals, so a rate/rule change is a data update, not a deploy |
| Partitioning/RLS/UUIDv7 are correct-but-unfamiliar choices that raise onboarding cost for future contributors | This document plus ADRs (§7, §24) capture the *why*, not just the *what*, so the reasoning survives team changes |

---

## 24. Technical Debt Prevention Plan

- **ADRs mandatory** for any deviation from this document (§7) — prevents silent architectural drift where "just this once" accumulates into inconsistency.
- **CI gates are non-negotiable**: lint, type-check, coverage, migration-reversibility, and generated-code-freshness all block merge — never bypassed with `--no-verify` or a disabled check (matches project-wide git safety rules).
- **No cross-module DB access** (§1.2, §2.2) enforced by an import-linter rule in backend CI and a folder-boundary lint in frontend CI — this is the single highest-leverage rule for keeping the modular monolith actually modular as it grows toward microservice-extractable.
- **Dependency updates** are a recurring backlog item (not deferred indefinitely) — Dependabot PRs triaged weekly, not left to accumulate.
- **Refactor budget**: every sprint reserves capacity (informal ~10%) for addressing debt flagged during that sprint's code review, rather than a dedicated "cleanup sprint" that never gets scheduled.
- **No feature flags as permanent branches in code** — a flag lives only as long as the rollout; stale flags are deleted within one release of full rollout.

---

## 25. Definition of Done (applies to every module/sprint)

A module is **Done** only when all of the following are true:

- [ ] Merged via reviewed PR into `main` (self-review checklist minimum if solo)
- [ ] Unit tests + relevant integration/widget tests written and passing
- [ ] Diff coverage ≥ 80%
- [ ] Linter and type-checker clean, no suppressed warnings without a justifying comment
- [ ] Database migration included, reviewed, and reversibility-tested (if schema touched)
- [ ] API changes reflected in OpenAPI spec and `API.md`
- [ ] All errors handled per §13 — no unhandled exceptions reach the client or crash the app
- [ ] Offline behavior verified where the module has offline-relevant writes (§14)
- [ ] Tenant isolation verified (RLS + app-level) for every new table (§15, §23)
- [ ] Security checklist passed: authz enforced per endpoint, inputs validated, no secrets in code/logs
- [ ] Structured logging added for key business events in the module
- [ ] All user-facing strings externalized for localization — no hardcoded UI text
- [ ] Manually verified on both Android and Windows
- [ ] `DATABASE.md` / `ARCHITECTURE.md` / module docs updated if the module changed the schema or contracts
- [ ] Product Owner sign-off against the module's acceptance criteria

---

## 26. Sprint Roadmap — Sprint 1 through Production Release

Cadence: 2-week sprints. Sprint 0 = this document (complete).

| Sprint | Focus | Key deliverables |
|---|---|---|
| **1** | Infra + sync/stock spike | Repo scaffolds (both stacks), Docker Compose dev stack, CI skeleton (lint/test/build), base migration + RLS pattern proven on one table, **sync engine spike**: offline create → queue → push → pull round trip proven end-to-end with a throwaway entity, **stock-delta concurrency spike** proving the row-locked reconciliation approach (§14.4) |
| **2** | Auth + Identity core | `companies`, `branches`, `users`, `roles`, `permissions`; JWT + refresh token flow; tenant-context middleware wired to RLS; login/logout/change-password/forgot-password end-to-end (backend + Flutter) |
| **3** | Multi-business / RBAC hardening | Role/permission enforcement on endpoints; company/branch CRUD; multi-branch invoice counter design (§15) implemented and tested |
| **4** | Catalog foundation | Categories, brands, units, products, variants, barcodes, product images; CSV import/export |
| **5** | Catalog UI + offline read path | Flutter product catalog screens; Drift local mirror of catalog tables; sync pull path exercised at real scale (10k+ SKU test dataset) |
| **6** | Inventory core | Stock, stock_transactions, adjustments, transfers; stock-delta reconciliation (from Sprint 1 spike) productionized; low-stock alerts |
| **7** | Purchases | Suppliers, purchase orders, goods receipts, supplier returns; feeds inventory via domain events |
| **8** | POS billing — core | Cart, billing screen, discounts, invoice generation (append-only, per §14.4), split payments |
| **9** | POS billing — hardware + offline | Thermal printer / cash drawer / barcode scanner integration via driver interface (§16); full offline sale → sync flow validated end-to-end |
| **10** | Customers | Customer CRUD, loyalty ledger, credit sales |
| **11** | Reports + Dashboard | Sales/purchase/inventory/GST/profit reports against the read replica; owner dashboard |
| **12** | Settings + Notifications | Backup/restore, printer/barcode settings, notification channels (email/SMS/WhatsApp) wired to Celery (activated here, per §23) |
| **13** | Hardening | Security review pass (§16 checklist across all modules), load test against performance budgets (§18), multi-branch/multi-company consolidated reporting (§15) |
| **14** | Beta stabilization | Bug-fix sprint against real pilot-merchant feedback; no new features |
| — | **MVP / v1.0 Production Release** | Phases through Sprint 14 constitute the sellable product: single shop → multi-branch → multi-company retail ERP + POS, offline-first, on Android and Windows |
| **15+** | Post-MVP: Returns, Expenses, GST reporting depth, Invoices polish, e-commerce/webhook integrations | Scoped and prioritized against real usage data from the MVP release, not pre-committed here |
| **AI phase** (after ≥3–6 months of production transaction volume) | AI Analytics → Forecasting → Assistant, per the phased sequencing in the prior architecture review | Data pipeline built on the by-then-stable Reports/Dashboard schema; rule-based anomaly detection ships before any ML forecasting |
| **Future** | Web, iOS, manufacturing integration, industrial vision inspection, marketplace APIs | Explicitly out of MVP scope; each requires its own Sprint-0-style design pass before implementation begins |

---

**This document is the implementation contract.** Any code written from this point forward should be traceable to a decision in one of the 26 sections above. Deviations require an ADR, not a silent judgment call mid-implementation.

Stopping here per instructions — awaiting approval before any application code is written.
