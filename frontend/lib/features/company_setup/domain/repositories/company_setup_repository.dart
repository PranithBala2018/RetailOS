import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

class CompanySignupParams {
  const CompanySignupParams({
    required this.companyName,
    this.brandName,
    this.gstNumber,
    required this.currency,
    required this.ownerFullName,
    required this.ownerEmail,
    required this.ownerPassword,
  });

  final String companyName;
  final String? brandName;
  final String? gstNumber;
  final String currency;
  final String ownerFullName;
  final String ownerEmail;
  final String ownerPassword;
}

abstract interface class CompanySetupRepository {
  /// On success, tokens are already persisted (see the data-layer impl)
  /// — the caller only needs to refresh session state afterward.
  Future<Either<Failure, Unit>> signUp(CompanySignupParams params);
}
