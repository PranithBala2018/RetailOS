import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/utils/app_logger.dart';

void main() {
  test('all log levels run without throwing', () {
    final logger = AppLogger('test');

    expect(() => logger.debug('debug message'), returnsNormally);
    expect(() => logger.info('info message'), returnsNormally);
    expect(() => logger.warning('warning message'), returnsNormally);
    expect(
      () => logger.error('error message', Exception('boom'), StackTrace.current),
      returnsNormally,
    );
  });
}
