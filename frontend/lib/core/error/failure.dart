import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Everything crossing the domain/presentation boundary from a repository
/// is `Either<Failure, T>` (fpdart) — never a thrown exception. See
/// SPRINT0.md §13. Presentation code pattern-matches with `.when`/`.map`
/// to decide UI treatment; no branch is allowed to be left unhandled.
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network({String? message}) = NetworkFailure;

  const factory Failure.server({String? message, int? statusCode}) = ServerFailure;

  const factory Failure.cache({String? message}) = CacheFailure;

  const factory Failure.validation({required String message, Map<String, String>? fieldErrors}) =
      ValidationFailure;

  const factory Failure.conflict({String? message}) = ConflictFailure;

  const factory Failure.auth({String? message}) = AuthFailure;

  const factory Failure.unexpected({String? message}) = UnexpectedFailure;
}
