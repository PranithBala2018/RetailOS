# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] — Sprint 2: Identity & Organization

Full authentication, company/branch/user management, and RBAC — the
foundation every future business module depends on. Products, Inventory,
POS, Customers, Suppliers, Purchases, and Reports remain unimplemented
(see `TASKS.md`).

### Added

**Backend (`backend/`)**
- 12 new tables across four modules (Company, Users/Roles/Permissions,
  Auth, Audit) — see `DATABASE.md`'s "Implemented Schema" section.
  Circular FKs (branches↔users↔warehouses) resolved via
  `ForeignKey(use_alter=True)`; a real bug where `use_alter=True` alone
  silently dropped the constraint from Alembic's `op.create_table` (it
  needs an explicit `op.create_foreign_key` after every table exists)
  was caught by testing against a real local Postgres instance rather
  than trusting the autogenerate output.
- Full auth surface: login (with account lockout after configurable
  failed attempts), logout, refresh-token rotation with reuse detection
  (stolen-token response: revoke every session for that user), forgot/
  reset/change password, branch switching, device-session listing and
  revocation. All security-relevant outcomes are written to `audit_logs`.
- RBAC: four seeded system-default roles (Super Admin/Admin/Manager/
  Cashier) and 14 seeded permissions across company/branches/users/
  roles/permissions/dashboard; `require_permission(code)` FastAPI
  dependency gates every endpoint.
- Company signup (`POST /companies`) creates a company, default branch +
  warehouse, and owner user in one transaction, then auto-logs the owner
  in — no separate "first login" step.
- 81 backend tests (was 36), 80% coverage, run against a real local
  Postgres instance (installed via conda — no Docker/native Postgres
  available in this dev environment) with transaction-per-test isolation.
- `docs/adr/0003`: tenant isolation is application-layer only this
  sprint; Postgres RLS is deferred to Sprint 3 (the pre-auth login
  lookup has no `company_id` to scope by yet — see the ADR for the
  three options considered).

**Frontend (`frontend/`)**
- Full auth flow: Splash (session validation / auto-login), Login,
  Forgot Password, Reset Password.
- Company Setup Wizard (two-step, posts to company signup), Branch
  Selection (uses `/auth/my-branches`, not the admin-gated
  `/branches`, so it works for every role).
- Dashboard Shell, Navigation Shell (`NavigationRail` on wide windows /
  bottom nav on narrow ones — same no-new-dependency responsive approach
  used for every form screen), Profile (change password, sign out).
- GoRouter now has real routes and a redirect guard driven by
  `sessionProvider`, via a `ChangeNotifier` bridge into
  `refreshListenable` so the router re-evaluates in place instead of
  being torn down and recreated on every session change.
- The Sprint 1 `bootstrap` feature (health-check proof-of-wiring) is
  removed — fully superseded by the real auth flow.
- 69 frontend tests (was 30), 82.6% coverage of non-generated code.
  Found and fixed two real UI bugs via testing: a "Remember me" row
  overflowing on narrow screens, and a screen title colliding with its
  own submit button's label, making them ambiguous to find in tests.

### Known issues

- Password reset has no email/SMS delivery channel yet (no notifications
  module) — the reset token is logged server-side as an explicit,
  documented stand-in.
- Postgres RLS is not yet enabled (see `docs/adr/0003`); tenant isolation
  relies on application-layer `company_id` filtering, checked by a
  per-table test class, not a database-level backstop.
- The async login-submission path isn't covered by a widget test (a
  Riverpod/`flutter_test` disposal-timing interaction, not a defect in
  the login flow) — covered instead at the unit level
  (`session_provider_test.dart`, `auth_repository_impl_test.dart`).

## [0.1.0] — Sprint 1: Infrastructure Foundation

No business modules (products, inventory, POS, customers, etc.) exist
yet — this release is infrastructure only, per SPRINT0.md and
`docs/adr/0001-sprint-1-scope-sequencing.md`.

### Added

**Backend (`backend/`)**
- FastAPI application factory (`app/main.py`) with CORS, a request-ID
  middleware, and a `/health` endpoint.
- Centralized exception hierarchy (`AppException` and subclasses) mapped
  onto the `API.md` response envelope, including a catch-all handler that
  never leaks internal error detail to clients.
- `pydantic-settings`-based configuration (`app/core/config.py`), sourced
  entirely from `API_`-prefixed environment variables.
- Structured JSON logging (`structlog`) with per-request context binding.
- Async SQLAlchemy 2 engine/session wiring (`app/core/db.py`).
- JWT access/refresh token issuance and verification, and Argon2id
  password hashing (`app/core/security.py`) — utilities only, no login
  endpoint yet (lands with the Identity module in Sprint 2).
- Cross-cutting ORM mixins (`app/common/base_model.py`): UUID primary
  keys, tenant scoping columns, timestamps, soft delete, optimistic
  concurrency, and offline-sync metadata, ready for the first real tables
  in Sprint 2.
- Alembic configured for async migrations (zero migrations yet — the
  `versions/` directory is intentionally empty).
- 36 backend tests (unit + integration), 95% coverage.
- `Dockerfile` and `.dockerignore`.

**Frontend (`frontend/`)**
- Flutter project scaffolded for Android and Windows.
- Clean Architecture, feature-first folder structure (`lib/core/`,
  `lib/features/`).
- Riverpod (with codegen), GoRouter, Dio, and Drift wired up as the state
  management, routing, networking, and local-database foundations.
- `Failure` sealed class (Freezed) and the `Either<Failure, T>`
  repository-boundary pattern (fpdart), per SPRINT0.md §13.
- Encrypted token storage (`flutter_secure_storage`) and a Dio auth
  interceptor — foundation only, no login screen yet.
- A `bootstrap` feature (domain/data/presentation) that calls the
  backend's `/health` endpoint end-to-end, serving as a worked example of
  the intended module shape and as a build/wiring smoke test. It is
  replaced by the real auth flow in Sprint 2.
- Localization scaffolding (`flutter gen-l10n`, one locale: `en`).
- 30 frontend tests (unit + widget), 88% coverage of non-generated code.

**Cross-cutting**
- `docker-compose.yml`: Postgres, Redis, and the API, wired together with
  health checks.
- Root and per-service `.env.example` files.
- GitHub Actions CI: `backend-ci.yml` (lint, format check, type check,
  migrations against a live Postgres service container, tests with an
  80% coverage gate, Docker build) and `frontend-ci.yml` (codegen,
  format check, analyze, tests with an 80% coverage gate on non-generated
  code, Android debug build).
- `docs/adr/`: two Architecture Decision Records documenting deviations
  from `SPRINT0.md` (deferred sync/stock-concurrency spikes; generated
  Dart code is not committed).

### Known issues

See the Sprint 1 completion report for the full list — notably: Windows
desktop builds are not locally verified in the current development
environment (requires Visual Studio's "Desktop development with C++"
workload plus Windows Developer Mode for plugin symlinks — both machine
prerequisites, not code defects); `freezed` is pinned to a dev-prerelease
(`3.2.6-dev.1`) because no stable 3.x has shipped yet.
