import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/domain/entities/branch_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

part 'branch_selection_providers.g.dart';

@riverpod
Future<List<BranchSummary>> myBranches(Ref ref) async {
  final result = await ref.watch(authRepositoryProvider).myBranches();
  return result.match((failure) => throw failure, (branches) => branches);
}
