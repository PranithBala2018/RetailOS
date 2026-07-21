# ADR-0003: Enforce tenant isolation at the application layer in Sprint 2; defer Postgres RLS policies to Sprint 3

## Status

Accepted

## Context

SPRINT0.md §5.3 and §15 specify Postgres Row-Level Security as a backstop
to application-level `company_id` filtering, enabled per table via
`ALTER TABLE ... ENABLE ROW LEVEL SECURITY` + a `USING (company_id =
current_setting('app.current_company_id')::uuid)` policy, with the
setting populated by tenant middleware from the JWT after auth succeeds.

Sprint 2's Identity module introduces a case that policy doesn't handle:
login. `POST /auth/login` looks a user up by email *before* any JWT
exists, so there is no `company_id` to set `app.current_company_id` to
yet. If RLS were enabled on `users` with the policy above, the login
query would see zero rows unconditionally — not "no matching user," but
"no user is ever visible pre-auth" — because an unset session variable
doesn't satisfy `company_id = NULL`. Three ways to resolve this were
considered:

1. A second, tightly-scoped Postgres role with `BYPASSRLS`, used only for
   the pre-auth lookup path. Correct, but adds a second DB credential and
   connection path to manage for a single query, before any other
   business table exists to justify the operational cost.
2. A policy that treats an unset session variable as "no restriction"
   (`... OR current_setting(...) = ''`). Rejected outright — this fails
   *open*: any code path that forgets to set the tenant context would
   silently see every tenant's users instead of erroring, which is the
   opposite of what RLS is supposed to guarantee.
3. Defer enabling RLS on the Identity tables until Sprint 3, when real
   business-data tables (which have no equivalent pre-auth lookup case)
   arrive and justify building the dedicated auth-role mechanism from
   option 1 properly, instead of rushing it under this sprint's scope.

SPRINT0.md's Sprint 2 instructions separately list "Tenant Isolation" as
an implement-now item and "Future Row-Level Security support" as
forward-looking — consistent with reading RLS *enforcement* as
out-of-scope for this sprint while RLS *readiness* (correct `company_id`
columns, indexes, and a tenant-context plumbing point) is in-scope.

## Decision

Tenant isolation in Sprint 2 is enforced at the application layer only:
every repository method for a company-scoped table takes an explicit
`company_id` and filters by it — the value always comes from the
authenticated JWT's claim, never from a client-supplied parameter.
`app/core/tenant_context.py` provides a `ContextVar`-based holder for the
current request's `company_id`/`branch_id`/`user_id`, populated by the
`get_current_user` auth dependency, so the plumbing point RLS will
eventually hook into already exists. No table gets `ENABLE ROW LEVEL
SECURITY` or a `CREATE POLICY` this sprint.

## Consequences

- A bug in a repository method that omits the `company_id` filter is not
  caught by a database-level backstop in Sprint 2 — code review and the
  tenant-isolation test class (one per new table, asserting cross-tenant
  reads/writes are rejected at the service layer) are the only guard
  until RLS lands.
- Sprint 3 must implement the dedicated low-privilege auth-role mechanism
  (option 1 above) *before or alongside* enabling RLS on `users`, and
  RLS on `companies`/`branches`/`roles`/`permissions`/`role_permissions`/
  `user_roles` can be enabled independently of that, since none of them
  have a pre-auth lookup case.
- This is a narrower scope than SPRINT0.md §5.3 read literally ("RLS is
  enabled on every tenant-scoped table as a backstop... from day one"),
  which is why it's recorded as a deviation here rather than silently
  implemented differently.
