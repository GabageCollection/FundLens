import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and retrieves the per-installation database encryption key.
abstract interface class DatabaseKeyStore {
  Future<String> readOrCreate();
  Future<void> write(String keyHex);
}

/// Implementation of [DatabaseKeyStore] backed by Windows Credential Manager
/// through [FlutterSecureStorage].
///
/// A fresh 256-bit key is generated with [randomBytes] when no key exists.
final class SecureDatabaseKeyStore implements DatabaseKeyStore {
  SecureDatabaseKeyStore(this.storage, this.randomBytes);

  final FlutterSecureStorage storage;
  final List<int> Function(int length) randomBytes;
  static const _key = 'fundlens.database.key.v1';

  @override
  Future<String> readOrCreate() async {
    final existing = await storage.read(key: _key);
    if (existing != null) return existing;
    final value = randomBytes(32)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await storage.write(key: _key, value: value);
    return value;
  }

  @override
  Future<void> write(String keyHex) => storage.write(key: _key, value: keyHex);
}
