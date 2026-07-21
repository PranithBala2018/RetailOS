import 'package:dio/dio.dart';

import '../../domain/repositories/company_setup_repository.dart';

class SignupTokens {
  const SignupTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class CompanySetupRemoteDataSource {
  CompanySetupRemoteDataSource(this._dio);

  final Dio _dio;

  Future<SignupTokens> signUp(CompanySignupParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/companies',
      data: {
        'name': params.companyName,
        if (params.brandName != null && params.brandName!.isNotEmpty)
          'brand_name': params.brandName,
        if (params.gstNumber != null && params.gstNumber!.isNotEmpty)
          'gst_number': params.gstNumber,
        'currency': params.currency,
        'owner_full_name': params.ownerFullName,
        'owner_email': params.ownerEmail,
        'owner_password': params.ownerPassword,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return SignupTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }
}
