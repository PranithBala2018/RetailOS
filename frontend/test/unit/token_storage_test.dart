import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/network/token_storage.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage secureStorage;
  late TokenStorage tokenStorage;

  setUpAll(() {
    registerFallbackValue(AndroidOptions());
    registerFallbackValue(IOSOptions());
  });

  setUp(() {
    secureStorage = _MockSecureStorage();
    tokenStorage = TokenStorage(storage: secureStorage);
  });

  test('saveTokens writes both access and refresh token', () async {
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await tokenStorage.saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    verify(
      () => secureStorage.write(key: 'retailos.auth.access_token', value: 'access-1'),
    ).called(1);
    verify(
      () => secureStorage.write(key: 'retailos.auth.refresh_token', value: 'refresh-1'),
    ).called(1);
  });

  test('readAccessToken returns null when nothing is stored', () async {
    when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);

    expect(await tokenStorage.readAccessToken(), isNull);
  });

  test('clear deletes both tokens', () async {
    when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await tokenStorage.clear();

    verify(() => secureStorage.delete(key: 'retailos.auth.access_token')).called(1);
    verify(() => secureStorage.delete(key: 'retailos.auth.refresh_token')).called(1);
  });
}
