import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// The local offline-first store (SPRINT0.md §14). No tables are declared
/// yet — the first ones (mirroring the Identity/Catalog schema) land
/// alongside their backend counterparts starting Sprint 2, at which point
/// this also gains the `sync_queue` table and the sync engine that drains
/// it (§14.2).
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'retailos');
}
