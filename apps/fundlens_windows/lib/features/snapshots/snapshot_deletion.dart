import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hook that deletes a snapshot by id.
///
/// The storage-layer `SnapshotRepository` interface does not expose deletion
/// yet, so the bootstrap wires this provider once deletion is available
/// there. Tests override it with a fake.
final snapshotDeletionProvider =
    Provider<Future<void> Function(String snapshotId)>((ref) {
  throw UnimplementedError(
    'snapshotDeletionProvider must be overridden by the bootstrap.',
  );
});
