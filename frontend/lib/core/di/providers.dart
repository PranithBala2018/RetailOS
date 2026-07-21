import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../network/token_storage.dart';

part 'providers.g.dart';

/// Process-lifetime singletons. Feature-level providers (repositories,
/// notifiers) depend on these rather than constructing their own —
/// see SPRINT0.md §2.3 (`presentation` depends on `domain`; `data`
/// implements it; wiring happens here, not inside widgets).
@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => TokenStorage();

@Riverpod(keepAlive: true)
Dio dio(Ref ref) => createDioClient(tokenStorage: ref.watch(tokenStorageProvider));

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
