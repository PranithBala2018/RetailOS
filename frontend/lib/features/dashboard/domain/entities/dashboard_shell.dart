import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_shell.freezed.dart';

/// Mirrors the backend's DashboardShellResponse — infrastructure only,
/// per the Sprint 2 brief. No business metrics belong here.
@freezed
abstract class DashboardShell with _$DashboardShell {
  const factory DashboardShell({
    required String companyName,
    String? branchName,
    required String userFullName,
    required List<String> roleNames,
    required String apiStatus,
    required String databaseStatus,
    required String apiVersion,
  }) = _DashboardShell;
}
