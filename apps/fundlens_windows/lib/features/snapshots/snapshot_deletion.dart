import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_dependencies.dart';

/// Hook that deletes a snapshot by id.
///
/// Defaults to [SnapshotRepository.deleteById]; tests override it with a
/// fake. Snapshot rows are otherwise immutable.
final snapshotDeletionProvider =
    Provider<Future<void> Function(String snapshotId)>((ref) {
  return (snapshotId) =>
      ref.read(snapshotRepositoryProvider).deleteById(snapshotId);
});
