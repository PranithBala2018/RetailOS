# RetailOS Frontend

Flutter, Clean Architecture, feature-first. See `../SPRINT0.md` for the
full architecture; this file is a working quickstart only.

## Setup

```bash
flutter pub get
flutter gen-l10n                                            # localization
dart run build_runner build --delete-conflicting-outputs    # freezed / riverpod / drift
```

Generated code (`*.g.dart`, `*.freezed.dart`, the l10n output) is not
committed — see `../docs/adr/0002-do-not-commit-generated-dart-code.md`.
Re-run the two commands above after pulling changes that touch any
`@freezed`, `@riverpod`, or `@DriftDatabase`-annotated file.

## Running

```bash
flutter run -d windows                                       # Windows desktop
flutter run -d <android-device-id>                            # Android
flutter run --dart-define=API_HOST=http://10.0.2.2:8000       # Android emulator → host machine's API
```

`API_HOST` defaults to `http://localhost:8000`; override it with
`--dart-define` per SPRINT0.md's build-time config approach (no `.env` on
this side — see `lib/core/config/app_config.dart`).

## Common tasks

```bash
flutter analyze                       # static analysis
dart format . --line-length=100       # format
flutter test --coverage               # unit + widget tests, 80%+ coverage gate
flutter build apk --debug             # Android
flutter build windows                 # Windows (requires Visual Studio's "Desktop development with C++" workload)
```

## Layout

`lib/core/` holds cross-cutting infrastructure (network, database,
routing, theming, DI, error types). `lib/features/<name>/` holds one
package per feature, each split into `domain/` (entities, repository
interfaces, use cases), `data/` (models, data sources, repository
implementations), and `presentation/` (screens, widgets, Riverpod
providers). `presentation` depends only on `domain`; `data` implements
`domain`'s interfaces; no feature imports another feature's `data` or
`presentation` directly. `lib/features/bootstrap/` is a full worked
example of this shape — see SPRINT0.md §2.3.
