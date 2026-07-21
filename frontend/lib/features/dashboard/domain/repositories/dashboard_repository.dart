import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/dashboard_shell.dart';

abstract interface class DashboardRepository {
  Future<Either<Failure, DashboardShell>> fetchShell();
}
