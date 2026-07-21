import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/features/company_setup/data/datasources/company_setup_remote_data_source.dart';
import 'package:retailos/features/company_setup/domain/repositories/company_setup_repository.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late CompanySetupRemoteDataSource dataSource;
  Map<String, dynamic>? lastRequestBody;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bodyString = await utf8.decoder.bind(request).join();
      lastRequestBody = jsonDecode(bodyString) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'message': 'ok',
          'data': {
            'company': {'id': 'company-1'},
            'branch': {'id': 'branch-1'},
            'warehouse': {'id': 'warehouse-1'},
            'owner_user_id': 'user-1',
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
          },
        }),
      );
      await request.response.close();
    });
    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    dataSource = CompanySetupRemoteDataSource(dio);
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('posts every field and parses the token pair', () async {
    const params = CompanySignupParams(
      companyName: 'Acme Retail',
      brandName: 'Acme',
      gstNumber: '22AAAAA0000A1Z5',
      currency: 'INR',
      ownerFullName: 'Ada Owner',
      ownerEmail: 'owner@example.com',
      ownerPassword: 'correct-horse-battery-staple',
    );

    final tokens = await dataSource.signUp(params);

    expect(tokens.accessToken, 'access-1');
    expect(tokens.refreshToken, 'refresh-1');
    expect(lastRequestBody!['name'], 'Acme Retail');
    expect(lastRequestBody!['brand_name'], 'Acme');
    expect(lastRequestBody!['gst_number'], '22AAAAA0000A1Z5');
    expect(lastRequestBody!['owner_email'], 'owner@example.com');
  });

  test('omits optional fields when blank', () async {
    const params = CompanySignupParams(
      companyName: 'Acme Retail',
      brandName: '',
      gstNumber: '',
      currency: 'INR',
      ownerFullName: 'Ada Owner',
      ownerEmail: 'owner@example.com',
      ownerPassword: 'correct-horse-battery-staple',
    );

    await dataSource.signUp(params);

    expect(lastRequestBody!.containsKey('brand_name'), isFalse);
    expect(lastRequestBody!.containsKey('gst_number'), isFalse);
  });
}
