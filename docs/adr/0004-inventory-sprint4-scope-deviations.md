# ADR-0004: Inventory (Sprint 4) scope deferrals and schema deviations from SPRINT0.md §1.2/§5.2/§5.5

## Status

Accepted

## Context

SPRINT0.md sketches Inventory across several sections:

- §1.2 lists "Inventory" as its own bounded context (Stock, Adjustments,
  Transfers) and specifies that cross-module side effects — e.g. a
  `SaleCompleted` event decrementing stock — happen through an in-process
  pub/sub event bus, not direct cross-module calls.
- §5.2 sketches Inventory's tables as `stock`, `stock_transactions`,
  `stock_adjustments`, `stock_transfers`, `product_batches`
  (expiry-tracked) — table names only, no columns, explicitly labeled
  "illustrative, not exhaustive — full DDL is written per-module during
  its sprint."
- §5.5 mandates that `stock_transactions` be range-partitioned by month
  "from day one... retrofitting partitioning onto a live high-write table
  is far more disruptive than declaring it upfront."
- §14.4 describes offline-sync conflict resolution for stock quantities:
  a server-authoritative recompute that applies a client's *delta*
  against the current server value inside a row-locked transaction, with
  unresolvable conflicts written to `sync_conflicts` for review.

None of the domain-event bus, the client-side offline-sync engine
(local-first Drift writes, `sync_queue`, push/pull, `sync_conflicts`), or
the "stock-delta concurrency spike" that `docs/adr/0001` deferred from
Sprint 1 to Sprint 2 have been built in any sprint through Sprint 3 —
confirmed against `CHANGELOG.md`'s Sprint 2 and Sprint 3 entries, neither
of which mentions them. Sprint 4 is the first sprint where Inventory
tables actually exist, so this is the point at which each of these design
threads either gets picked up or explicitly re-deferred.

## Decision

**1. No domain event bus this sprint.** Nothing in the codebase yet needs
to *publish into* Inventory — Purchases (goods receipt) and POS (sale)
are both entirely unbuilt, so a bus would have zero producers. Inventory
exposes its four mutations (Stock In, Stock Out, Transfer, Adjustment) as
direct, synchronous HTTP endpoints. The event-driven design in §1.2
remains the target architecture; it is deferred until a real producer
module (Purchases or POS) exists to justify it.

**2. `product_batches` (expiry tracking) is not modeled at all**, not
folded into another table. §5.2 names it but no further design exists
anywhere in this repository, and none of TASKS.md's Phase 5 items
(Stock In, Stock Out, Stock Transfer, Stock Adjustment, Low Stock Alerts)
require batch/expiry semantics. This is an outright omission, to be
designed fresh (batch number, expiry date, FIFO/FEFO allocation) if a
future sprint's requirements need it — not something a reader should
expect to find folded into `stock_transactions.note` or similar.

**3. No Flutter offline-sync engine.** This is not a new deferral
introduced by Inventory — it is the same gap `docs/adr/0001` already
described, still unaddressed as of Sprint 3. Every Inventory mutation
this sprint is a direct, online HTTP call; there is no local-first write
path and nothing queues for later sync.

**4. `stock_transactions` ships as a plain (non-partitioned) table**,
despite §5.5's mandate. `backend/app/migrations/env.py` diffs
`Base.metadata` directly against the live database with no
`include_name`/`include_object` filter. Partition child tables created
via raw DDL exist in Postgres but are never registered in `Base.metadata`
(only the parent table is, as an ORM class) — so the next
`alembic revision --autogenerate` run for *any other module* would see
those partitions as unrecognized tables and emit `op.drop_table(...)` for
each one. Avoiding that requires an `env.py` filter and an operational
story for creating future partitions (e.g. a scheduled job), neither of
which exists, for a table that has near-zero rows on day one — no
Purchases/POS writers exist yet to generate the write volume §5.5's own
justification ("a live high-write table") is written for. `stock_levels`
and `stock_transactions` instead get two composite indexes —
`(company_id, created_at DESC)` and
`(company_id, product_variant_id, created_at DESC)` — sized for the
current, not eventual, workload.

**5. Three tables, not SPRINT0's literal four-plus-batches sketch.**
`stock_adjustments` is folded into `stock_transactions` as one more
`movement_type` value (with `quantity_before`/`quantity_after` snapshot
columns used only for that type) rather than a separate table — an
adjustment is not semantically different from any other stock movement,
it is a delta with a reason. A separate table would only mean joining
across movement-type tables to answer "show me everything that happened
to this variant," which the consolidated ledger answers directly. This is
exercising the discretion §5.2's own "illustrative, not exhaustive"
framing grants, not overriding a firm spec.

## Consequences

- Every Inventory mutation still gets the server-side half of §14.4's
  concurrency design — an atomic, delta-based, row-locked upsert against
  `stock_levels`, checked against `track_inventory`/`allow_negative_stock`
  before commit — even though the offline path that design was written
  for doesn't exist yet. This satisfies the substance of the still-open
  `docs/adr/0001` stock-concurrency spike without requiring the client
  sync engine to exist first.
- Re-trigger conditions, to revisit each deferral:
  - Domain event bus: when Purchases or POS is built and needs to affect
    stock without a direct cross-module call.
  - `product_batches`: when a real requirement (e.g. a perishables/pilot
    business) needs expiry tracking.
  - Offline sync engine: unchanged from `docs/adr/0001` — whenever that
    ADR's deferred scope is picked back up.
  - Partitioning: before Purchases or POS ships (both will write to
    `stock_transactions` at meaningfully higher volume), or when the
    table's row count crosses a size where unpartitioned scans start
    costing real query time — whichever comes first. At that point, add
    the `env.py` `include_name` filter alongside the partitioning
    migration, not before.
- This is a narrower scope than SPRINT0.md read literally, recorded here
  rather than silently implemented differently, per this project's
  standing rule that any architectural deviation gets an ADR (see
  `docs/adr/0002`, `docs/adr/0003`).
