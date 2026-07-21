# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
