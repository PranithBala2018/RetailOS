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

**No Docker and no native PostgreSQL install on Windows?** A local dev
cluster can be installed via conda instead:

```powershell
conda create -n retailos_pg -c conda-forge postgresql -y
$pgBin = "$env:USERPROFILE\miniconda3\envs\retailos_pg\Library\bin"
$dataDir = "$env:USERPROFILE\.retailos_pgdata"
$pwFile = "$env:TEMP\pg_init_pw.txt"
Set-Content -Path $pwFile -Value "retailos" -NoNewline -Encoding ascii
& "$pgBin\initdb.exe" -D $dataDir -U retailos --pwfile=$pwFile -E UTF8 --locale=C
Remove-Item $pwFile -Force
& "$pgBin\pg_ctl.exe" -D $dataDir -l "$env:USERPROFILE\.retailos_pgdata_server.log" -o "-p 5432" start
& "$pgBin\createdb.exe" -U retailos -h localhost -p 5432 -O retailos retailos
```

Stop it later with `& "$pgBin\pg_ctl.exe" -D $dataDir stop`.

This installs Postgres binaries only (not a service) — `pg_ctl start` /
`pg_ctl stop -D <datadir>` control it per session. The default
`API_DATABASE_URL` in `.env.example` already matches this setup
(`retailos`/`retailos`@`localhost:5432`/`retailos`).

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
