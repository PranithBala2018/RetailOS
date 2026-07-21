import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_health.freezed.dart';

@freezed
abstract class ApiHealth with _$ApiHealth {
  const factory ApiHealth({required String status, required String environment}) = _ApiHealth;
}
