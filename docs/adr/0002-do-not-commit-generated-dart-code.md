# ADR-0002: Do not commit generated Dart code

## Status

Accepted

## Context

SPRINT0.md §23 names a specific risk mitigation for the codegen-heavy
Flutter stack (Riverpod + Drift + Freezed + go_router all rely on
`build_runner`): "CI step fails the build if `build_runner build`
produces a diff against committed generated files." That wording assumes
`.g.dart` / `.freezed.dart` files are committed to the repository.

In practice, committing generated code for this dependency set has real
costs: every model/provider change produces a large, noisy diff in
generated files on top of the actual source change, and generated code
frequently causes merge conflicts that have nothing to do with the
underlying logic. It also invites a stale-file bug class the "diff check"
was meant to catch in the first place — someone forgets to regenerate
locally, and now the wrong generated code is what's under review.

## Decision

Generated Dart files (`**/*.g.dart`, `**/*.freezed.dart`, and the
`flutter gen-l10n` output under `lib/core/localization/generated/`) are
gitignored and never committed. `frontend-ci.yml` regenerates all of them
from source at the start of every run — before `dart format`, `flutter
analyze`, and `flutter test` — so CI always analyzes and tests against
freshly generated code, never a possibly-stale committed copy. Local
development runs `dart run build_runner build --delete-conflicting-outputs`
after `flutter pub get` for the same reason.

## Consequences

- Achieves the same goal SPRINT0.md §23 was after — generated code can
  never silently drift from source in what ships — through regeneration
  instead of diffing.
- A fresh clone requires running `dart run build_runner build` (and
  `flutter gen-l10n`) before the app compiles or tests run; this is
  documented in `frontend/README.md`.
- Slightly slower CI (codegen runs every time) in exchange for zero
  generated-code merge conflicts and zero risk of reviewing stale output.
