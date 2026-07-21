# RetailOS Backend

FastAPI + SQLAlchemy 2 (async) + PostgreSQL. See `../SPRINT0.md` for the
full architecture; this file is a working quickstart only.

## Local setup (without Docker)

```bash
python -m venv .venv
.venv/Scripts/activate        # .venv/bin/activate on macOS/Linux
pip install -e ".[dev]"
cp .env.example .env          # then fill in a real API_JWT_SECRET_KEY
```

Requires a running PostgreSQL instance matching `API_DATABASE_URL` in
`.env` (or use `docker compose up postgres redis` from the repo root).

```bash
uvicorn app.main:app --reload
# → http://localhost:8000/health
# → http://localhost:8000/api/v1/docs  (Swagger UI, non-production only)
```

## Common tasks

```bash
pytest                        # run the test suite (80%+ coverage gate)
ruff check .                  # lint
ruff format .                 # format
mypy app                      # type check (strict on core/ and common/)
alembic revision --autogenerate -m "message"   # new migration
alembic upgrade head           # apply migrations
```

## Layout

See SPRINT0.md §2.2 for the full rationale. In short: `app/core` is
framework/infrastructure code, `app/common` is shared base classes used
across modules, and `app/modules/<name>` is where each business module
(auth, company, products, ...) will live starting Sprint 2 — one package
per module, each with its own `api.py` / `schemas.py` / `models.py` /
`service.py` / `repository.py`. A module never imports another module's
`models.py` or `repository.py` directly — only its `schemas.py`.
