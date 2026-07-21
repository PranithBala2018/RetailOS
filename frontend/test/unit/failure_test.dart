import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/error/failure.dart';

void main() {
  group('Failure', () {
    test('network failure round-trips through pattern matching', () {
      const failure = Failure.network(message: 'no connection');
      final matched = switch (failure) {
        NetworkFailure(:final message) => message,
        _ => null,
      };
      expect(matched, 'no connection');
    });

    test('two failures with the same fields are equal (freezed value equality)', () {
      expect(const Failure.server(statusCode: 500), const Failure.server(statusCode: 500));
    });

    test('switch over Failure is exhaustive without a default case', () {
      String describe(Failure failure) => switch (failure) {
        NetworkFailure() => 'network',
        ServerFailure() => 'server',
        CacheFailure() => 'cache',
        ValidationFailure() => 'validation',
        ConflictFailure() => 'conflict',
        AuthFailure() => 'auth',
        UnexpectedFailure() => 'unexpected',
      };

      expect(describe(const Failure.auth()), 'auth');
      expect(describe(const Failure.conflict()), 'conflict');
    });
  });
}
