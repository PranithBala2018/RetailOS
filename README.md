# RetailOS

A world-class Retail ERP + POS platform for everything from street vendors
to multi-branch retail chains — Android, Windows, and (later) web, backed
by a FastAPI + PostgreSQL API, offline-first by design.

- **Architecture, every finalized decision, and the sprint roadmap:** [`SPRINT0.md`](SPRINT0.md)
- **Backend quickstart:** [`backend/README.md`](backend/README.md)
- **Frontend quickstart:** [`frontend/README.md`](frontend/README.md)
- **Architecture deviations:** [`docs/adr/`](docs/adr/)
- **Release history:** [`CHANGELOG.md`](CHANGELOG.md)

## Quickstart (full stack, Docker)

```bash
cp .env.example .env      # fill in a real API_JWT_SECRET_KEY
docker compose up --build
# → http://localhost:8000/health
```

Then run the Flutter app against it — see `frontend/README.md`.

## Status

Sprint 1 (infrastructure foundation) complete. No business modules
(products, inventory, POS, etc.) exist yet — see `TASKS.md` and
`SPRINT0.md` §26 for what's next.
