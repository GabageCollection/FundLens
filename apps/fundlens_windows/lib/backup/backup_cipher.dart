import 'dart:typed_data';

import 'backup_format.dart';

/// Thrown when a backup cannot be authenticated. Wrong passwords, GCM tag
/// failures and payload digest mismatches all surface as this single type so
/// callers cannot tell which check failed.
final class BackupAuthenticationException implements Exception {
  const BackupAuthenticationException();

  @override
  String toString() => 'BackupAuthenticationException: backup authentication failed';
}

/// Encrypts and decrypts FundLens backup containers.
///
/// [encrypt] consumes the encoded [FundLensBackupPayload] and a user password
/// that is held only in memory; [decrypt] authenticates the container and
/// returns the encoded payload. Structural problems raise
/// [BackupFormatException]; authentication failures raise
/// [BackupAuthenticationException].
abstract interface class BackupCipher {
  Future<Uint8List> encrypt(List<int> plaintextPayload, String password);
  Future<Uint8List> decrypt(List<int> backupBytes, String password);
}
