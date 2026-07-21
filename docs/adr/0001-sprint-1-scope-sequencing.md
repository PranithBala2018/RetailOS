# ADR-0001: Defer the sync-engine and stock-concurrency spikes to Sprint 2

## Status

Accepted

## Context

SPRINT0.md §26 defines Sprint 1 as "Infra + sync/stock spike," explicitly
including an end-to-end offline sync round trip and a stock-delta
concurrency spike as Sprint 1 deliverables.

The Sprint 1 kickoff instructions given by the Product Owner scoped Sprint
1 to fifteen concrete infrastructure items (Flutter project scaffold,
FastAPI backend, PostgreSQL configuration, Docker/Compose, environment
configuration, Clean Architecture folder structure, Riverpod, GoRouter,
Dio, Drift, SQLAlchemy, Alembic, logging, GitHub Actions CI, and JWT
authentication infrastructure foundation-only) and explicitly excluded
business modules. Sync and stock-concurrency logic are not infrastructure
plumbing — they are behavior that depends on the Identity and Inventory
schemas, neither of which exists yet in Sprint 1.

## Decision

The sync-engine spike and the stock-delta concurrency spike are deferred
to Sprint 2, to be built alongside (not before) the Identity and Inventory
schemas they depend on. Sprint 1 delivers the infrastructure those spikes
will run on top of: Drift is configured with zero tables, Alembic is
configured with zero migrations, and the `core/sync/` directory described
in SPRINT0.md §2.3 is not created yet — it lands with the first real
sync-eligible entity.

## Consequences

- Sprint 1's Definition of Done for "does the offline path work end to
  end" is deferred; it is re-added as an explicit Sprint 2 exit criterion.
- The stock-oversell race condition (SPRINT0.md §14.4, §23) remains an
  open risk one sprint longer than originally planned. It is still
  addressed before any POS billing work begins (Sprint 8–9 in the
  roadmap), well ahead of when it would matter in practice.
- This does not change the target architecture in SPRINT0.md — only the
  sprint in which two specific spikes are executed.
