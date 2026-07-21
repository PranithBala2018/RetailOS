import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/api_health.dart';

/// Presentation depends on this interface only — never on
/// [HealthRepositoryImpl] or the Dio-based data source directly.
abstract interface class HealthRepository {
  Future<Either<Failure, ApiHealth>> check();
}
