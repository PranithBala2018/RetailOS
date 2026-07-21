import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/core/network/dio_error_mapper.dart';

RequestOptions _options() => RequestOptions(path: '/test');

DioException _withStatus(int statusCode, {String? message}) {
  return DioException(
    requestOptions: _options(),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: _options(),
      statusCode: statusCode,
      data: message == null
          ? null
          : <String, dynamic>{'success': false, 'message': message, 'errors': <dynamic>[]},
    ),
  );
}

void main() {
  test('connection errors map to Failure.network', () {
    final failure = mapDioException(
      DioException(requestOptions: _options(), type: DioExceptionType.connectionError),
    );
    expect(failure, isA<NetworkFailure>());
  });

  test('401 maps to Failure.auth with the backend message', () {
    final failure = mapDioException(_withStatus(401, message: 'Invalid email or password'));
    expect(failure, isA<AuthFailure>());
    expect((failure as AuthFailure).message, 'Invalid email or password');
  });

  test('409 maps to Failure.conflict', () {
    final failure = mapDioException(_withStatus(409, message: 'Version mismatch'));
    expect(failure, isA<ConflictFailure>());
  });

  test('422 maps to Failure.validation', () {
    final failure = mapDioException(_withStatus(422, message: 'Email is already registered'));
    expect(failure, isA<ValidationFailure>());
    expect((failure as ValidationFailure).message, 'Email is already registered');
  });

  test('422 without a backend message still produces a usable validation message', () {
    final failure = mapDioException(_withStatus(422));
    expect((failure as ValidationFailure).message, 'Validation failed');
  });

  test('500 maps to Failure.server with the status code preserved', () {
    final failure = mapDioException(_withStatus(500, message: 'boom'));
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).statusCode, 500);
  });
}
