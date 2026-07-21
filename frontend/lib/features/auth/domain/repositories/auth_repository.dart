import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/branch_summary.dart';
import '../entities/current_user.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, CurrentUser>> login({
    required String email,
    required String password,
    bool rememberMe,
    String? deviceId,
    String? deviceName,
  });

  Future<Either<Failure, void>> logout();

  /// Whether a refresh token is stored locally — checked at app start
  /// (Splash) before attempting session validation. Does not itself
  /// prove the token is still valid server-side.
  Future<bool> hasStoredSession();

  Future<Either<Failure, CurrentUser>> fetchCurrentUser();

  Future<Either<Failure, void>> forgotPassword(String email);

  Future<Either<Failure, void>> resetPassword({required String token, required String newPassword});

  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<Failure, List<BranchSummary>>> myBranches();

  Future<Either<Failure, void>> switchBranch(String branchId);
}
