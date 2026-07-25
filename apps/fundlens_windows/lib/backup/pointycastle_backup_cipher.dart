import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'backup_cipher.dart';
import 'backup_format.dart';

/// Derives the 32-byte backup key with the fixed FundLens KDF:
/// Argon2id, 16-byte salt, 3 iterations, 65536 KiB memory, 1 lane.
///
/// The encoded password bytes are zeroed before returning.
Uint8List deriveBackupKey(String password, Uint8List salt) {
  final generator = Argon2BytesGenerator()
    ..init(Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: 32,
      iterations: FundLensBackupHeader.argonIterations,
      memory: FundLensBackupHeader.argonMemoryKiB,
      lanes: FundLensBackupHeader.argonLanes,
    ));
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final key = Uint8List(32);
  generator.deriveKey(passwordBytes, 0, key, 0);
  passwordBytes.fillRange(0, passwordBytes.length, 0);
  return key;
}

/// Runs AES-256-GCM over [input]. On encrypt the 16-byte tag is appended to
/// the returned ciphertext; on decrypt a tag mismatch throws
/// [InvalidCipherTextException]. [key] is always zeroed before returning.
Uint8List cryptGcm(bool encrypt, Uint8List input, Uint8List key, Uint8List nonce, Uint8List aad) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(encrypt, AEADParameters<KeyParameter>(KeyParameter(key), 128, nonce, aad));
  try {
    return cipher.process(input);
  } finally {
    key.fillRange(0, key.length, 0);
  }
}

/// [BackupCipher] backed by PointyCastle, producing the versioned container:
///
/// ```text
/// 16 bytes  ASCII magic "FUNDLENS-BACKUP\0"
/// 4 bytes   unsigned big-endian JSON header length
/// N bytes   UTF-8 canonical JSON header used as AES-GCM AAD
/// remaining AES-GCM ciphertext followed by 16-byte authentication tag
/// ```
final class PointyCastleBackupCipher implements BackupCipher {
  PointyCastleBackupCipher({List<int> Function(int length)? randomBytes})
      : _randomBytes = randomBytes ?? _secureRandomBytes;

  final List<int> Function(int length) _randomBytes;

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  @override
  Future<Uint8List> encrypt(List<int> plaintextPayload, String password) async {
    if (plaintextPayload.length > kMaxBackupBytes) {
      throw const BackupFormatException('backup payload exceeds 100 MiB');
    }
    // Fresh salt and nonce for every backup.
    final salt = Uint8List.fromList(_randomBytes(FundLensBackupHeader.saltBytes));
    final nonce = Uint8List.fromList(_randomBytes(FundLensBackupHeader.nonceBytes));
    final payload = Uint8List.fromList(plaintextPayload);
    try {
      final header = FundLensBackupHeader(
        createdAtUtc: DateTime.now().toUtc(),
        salt: salt,
        nonce: nonce,
        payloadSha256: sha256.convert(payload).toString(),
      );
      final aad = Uint8List.fromList(utf8.encode(jsonEncode(header.toJson())));
      final ciphertext = cryptGcm(true, payload, deriveBackupKey(password, salt), nonce, aad);
      return (BytesBuilder()
            ..add(kFundLensBackupMagic)
            ..add((ByteData(4)..setUint32(0, aad.length)).buffer.asUint8List())
            ..add(aad)
            ..add(ciphertext))
          .toBytes();
    } finally {
      payload.fillRange(0, payload.length, 0);
    }
  }

  @override
  Future<Uint8List> decrypt(List<int> backupBytes, String password) async {
    if (backupBytes.length > kMaxBackupBytes) {
      throw const BackupFormatException('backup container exceeds 100 MiB');
    }
    if (backupBytes.length < kFundLensBackupMagic.length + 4 + 16) {
      throw const BackupFormatException('backup container is truncated');
    }
    final bytes = backupBytes is Uint8List ? backupBytes : Uint8List.fromList(backupBytes);
    for (var i = 0; i < kFundLensBackupMagic.length; i++) {
      if (bytes[i] != kFundLensBackupMagic[i]) {
        throw const BackupFormatException('not a FundLens backup container');
      }
    }
    final headerLength = ByteData.sublistView(bytes).getUint32(kFundLensBackupMagic.length);
    final headerStart = kFundLensBackupMagic.length + 4;
    if (headerLength > bytes.length - headerStart - 16) {
      throw const BackupFormatException('backup container is truncated');
    }
    final aad = Uint8List.sublistView(bytes, headerStart, headerStart + headerLength);
    final header = _parseHeader(aad);
    final ciphertext = Uint8List.sublistView(bytes, headerStart + headerLength);

    // Any GCM failure, wrong password or digest mismatch maps to the same
    // exception so callers cannot distinguish which check failed.
    final Uint8List plaintext;
    try {
      plaintext = cryptGcm(false, ciphertext, deriveBackupKey(password, header.salt), header.nonce, aad);
    } on InvalidCipherTextException {
      throw const BackupAuthenticationException();
    }
    if (!_digestMatches(plaintext, header.payloadSha256)) {
      plaintext.fillRange(0, plaintext.length, 0);
      throw const BackupAuthenticationException();
    }
    return plaintext;
  }

  /// Parses the JSON header, rejecting unknown format/KDF/cipher versions
  /// before any large buffer is derived from declared lengths.
  FundLensBackupHeader _parseHeader(Uint8List aad) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(aad));
    } on FormatException {
      throw const BackupFormatException('backup header is not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException('backup header is not a JSON object');
    }
    if (decoded['format_version'] != FundLensBackupHeader.formatVersion) {
      throw const BackupFormatException('unsupported backup format version');
    }
    final kdf = decoded['kdf'];
    if (kdf is! Map ||
        kdf['name'] != 'argon2id' ||
        kdf['memory_kib'] != FundLensBackupHeader.argonMemoryKiB ||
        kdf['iterations'] != FundLensBackupHeader.argonIterations ||
        kdf['lanes'] != FundLensBackupHeader.argonLanes) {
      throw const BackupFormatException('unsupported backup KDF parameters');
    }
    final cipher = decoded['cipher'];
    if (cipher is! Map || cipher['name'] != 'aes-256-gcm' || cipher['tag_bits'] != 128) {
      throw const BackupFormatException('unsupported backup cipher');
    }
    try {
      return FundLensBackupHeader.fromJson(decoded);
    } on FormatException {
      throw const BackupFormatException('backup header is malformed');
    }
  }

  static bool _digestMatches(Uint8List plaintext, String expectedHex) {
    final digest = sha256.convert(plaintext).bytes;
    final expected = ascii.encode(expectedHex);
    var difference = expected.length ^ 64;
    for (var i = 0; i < digest.length; i++) {
      final nibble = _hexValue(expected[i * 2]) << 4 | _hexValue(expected[i * 2 + 1]);
      difference |= digest[i] ^ nibble;
    }
    return difference == 0;
  }

  static int _hexValue(int char) {
    if (char >= 0x30 && char <= 0x39) return char - 0x30;
    if (char >= 0x61 && char <= 0x66) return char - 0x61 + 10;
    // Invalid hex still compares constant-time; it simply never matches.
    return 0;
  }
}
