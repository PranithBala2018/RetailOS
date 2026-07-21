import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/bootstrap/domain/entities/api_health.dart';
import 'package:retailos/features/bootstrap/domain/repositories/health_repository.dart';
import 'package:retailos/features/bootstrap/presentation/providers/health_providers.dart';
import 'package:retailos/features/bootstrap/presentation/screens/bootstrap_screen.dart';

class _FakeHealthRepository implements HealthRepository {
  _FakeHealthRepository(this._result);

  final Either<Failure, ApiHealth> _result;
  int checkCallCount = 0;

  @override
  Future<Either<Failure, ApiHealth>> check() async {
    checkCallCount++;
    return _result;
  }
}

Widget _wrap(Widget child, {required HealthRepository repository}) {
  return ProviderScope(
    overrides: [healthRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows API status once the health check succeeds', (tester) async {
    final repository = _FakeHealthRepository(
      const Right(ApiHealth(status: 'ok', environment: 'development')),
    );

    await tester.pumpWidget(_wrap(const BootstrapScreen(), repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('API status: ok (development)'), findsOneWidget);
  });

  testWidgets('shows an error state when the health check fails', (tester) async {
    final repository = _FakeHealthRepository(const Left(Failure.network()));

    await tester.pumpWidget(_wrap(const BootstrapScreen(), repository: repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('API unreachable'), findsOneWidget);
  });

  testWidgets('shows a loading indicator before the check resolves', (tester) async {
    final repository = _FakeHealthRepository(
      const Right(ApiHealth(status: 'ok', environment: 'development')),
    );

    await tester.pumpWidget(_wrap(const BootstrapScreen(), repository: repository));
    // Before settling, the FutureProvider is still in its loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tapping "Recheck API connection" re-runs the health check', (tester) async {
    final repository = _FakeHealthRepository(
      const Right(ApiHealth(status: 'ok', environment: 'development')),
    );

    await tester.pumpWidget(_wrap(const BootstrapScreen(), repository: repository));
    await tester.pumpAndSettle();
    expect(repository.checkCallCount, 1);

    await tester.tap(find.text('Recheck API connection'));
    await tester.pumpAndSettle();

    expect(repository.checkCallCount, 2);
  });
}
