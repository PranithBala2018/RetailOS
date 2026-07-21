import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/database/app_database.dart';

void main() {
  test('opens against an in-memory executor and reports schema version 1', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 1);
  });
}
