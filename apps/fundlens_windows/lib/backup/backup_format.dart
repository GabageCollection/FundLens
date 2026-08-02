import 'dart:convert';
import 'dart:typed_data';

/// 16-byte ASCII magic that opens every FundLens backup container.
final Uint8List kFundLensBackupMagic = ascii.encode('FUNDLENS-BACKUP\x00');

/// File extension for FundLens encrypted backups.
const String kFundLensBackupExtension = '.fundlens-backup';

/// Upper bound for a backup container (and its plaintext payload), 100 MiB.
const int kMaxBackupBytes = 100 * 1024 * 1024;

/// Thrown when a backup container, header or payload record is structurally
/// invalid or uses an unsupported format, KDF or cipher version.
final class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Authenticated cleartext header of a FundLens backup container.
///
/// The canonical JSON encoding of [toJson] is used as AES-GCM AAD, so the
/// header is authenticated but never secret: the database key only ever
/// appears inside the encrypted payload.
final class FundLensBackupHeader {
  const FundLensBackupHeader({
    required this.createdAtUtc,
    required this.salt,
    required this.nonce,
    required this.payloadSha256,
  });

  static const formatVersion = 1;
  static const argonMemoryKiB = 65536;
  static const argonIterations = 3;
  static const argonLanes = 1;
  static const saltBytes = 16;
  static const nonceBytes = 12;

  final DateTime createdAtUtc;
  final Uint8List salt;
  final Uint8List nonce;
  final String payloadSha256;

  /// Serializes with this exact key order; the resulting JSON is the AAD.
  Map<String, Object> toJson() => {
        'format_version': formatVersion,
        'created_at_utc': createdAtUtc.toIso8601String(),
        'kdf': {
          'name': 'argon2id',
          'memory_kib': argonMemoryKiB,
          'iterations': argonIterations,
          'lanes': argonLanes,
          'salt': base64Encode(salt),
        },
        'cipher': {
          'name': 'aes-256-gcm',
          'nonce': base64Encode(nonce),
          'tag_bits': 128,
        },
        'payload_sha256': payloadSha256,
      };

  /// Parses a header map, ignoring unknown keys so newer containers stay
  /// readable. Throws [FormatException] on malformed known fields.
  factory FundLensBackupHeader.fromJson(Map<String, Object?> json) {
    final kdf = json['kdf'];
    final cipher = json['cipher'];
    if (kdf is! Map || cipher is! Map) {
      throw const FormatException('header is missing kdf or cipher');
    }
    final salt = _decodeBase64(kdf['salt'], saltBytes, 'kdf.salt');
    final nonce = _decodeBase64(cipher['nonce'], nonceBytes, 'cipher.nonce');
    final sha = json['payload_sha256'];
    if (sha is! String || !_lowerHex64.hasMatch(sha)) {
      throw const FormatException('payload_sha256 must be 64 lowercase hex characters');
    }
    final createdAt = DateTime.tryParse(json['created_at_utc']?.toString() ?? '');
    if (createdAt == null) {
      throw const FormatException('created_at_utc is not an ISO-8601 timestamp');
    }
    return FundLensBackupHeader(
      createdAtUtc: createdAt.toUtc(),
      salt: salt,
      nonce: nonce,
      payloadSha256: sha,
    );
  }

  static Uint8List _decodeBase64(Object? value, int expectedBytes, String field) {
    if (value is! String) throw FormatException('$field must be base64');
    final Uint8List decoded;
    try {
      decoded = base64Decode(value);
    } on FormatException {
      throw FormatException('$field must be base64');
    }
    if (decoded.length != expectedBytes) {
      throw FormatException('$field must decode to $expectedBytes bytes');
    }
    return decoded;
  }
}

/// Reads the authenticated cleartext header from a backup container without
/// needing the password. The header carries the creation time; the payload
/// (and with it all user data) stays encrypted.
FundLensBackupHeader readBackupHeader(Uint8List backupBytes) {
  if (backupBytes.length < kFundLensBackupMagic.length + 4 + 16) {
    throw const BackupFormatException('backup container is truncated');
  }
  for (var i = 0; i < kFundLensBackupMagic.length; i++) {
    if (backupBytes[i] != kFundLensBackupMagic[i]) {
      throw const BackupFormatException('not a FundLens backup container');
    }
  }
  final headerLength = ByteData.sublistView(backupBytes).getUint32(
    kFundLensBackupMagic.length,
  );
  final headerStart = kFundLensBackupMagic.length + 4;
  if (headerLength > backupBytes.length - headerStart - 16) {
    throw const BackupFormatException('backup container is truncated');
  }
  final aad = Uint8List.sublistView(
    backupBytes,
    headerStart,
    headerStart + headerLength,
  );
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(aad));
  } on FormatException {
    throw const BackupFormatException('backup header is not valid JSON');
  }
  if (decoded is! Map<String, Object?>) {
    throw const BackupFormatException('backup header is not a JSON object');
  }
  try {
    return FundLensBackupHeader.fromJson(decoded);
  } on FormatException {
    throw const BackupFormatException('backup header is malformed');
  }
}

final RegExp _lowerHex64 = RegExp(r'^[0-9a-f]{64}$');

/// The authenticated plaintext record inside a FundLens backup:
///
/// ```text
/// 2 bytes   unsigned big-endian database-key length (must equal 64)
/// 64 bytes  ASCII hex sqlite3mc database key
/// 8 bytes   unsigned big-endian database length
/// N bytes   encrypted SQLite database file
/// ```
final class FundLensBackupPayload {
  FundLensBackupPayload({required this.databaseKeyHex, required this.databaseBytes}) {
    if (!_lowerHex64.hasMatch(databaseKeyHex)) {
      throw ArgumentError.value(
        databaseKeyHex.length,
        'databaseKeyHex',
        'must be exactly 64 lowercase hexadecimal characters',
      );
    }
  }

  static const keyLengthBytes = 64;
  static const _recordPrefixBytes = 2 + keyLengthBytes + 8;

  final String databaseKeyHex;
  final Uint8List databaseBytes;

  Uint8List encode() {
    final keyBytes = ascii.encode(databaseKeyHex);
    return (BytesBuilder()
          ..add((ByteData(2)..setUint16(0, keyBytes.length)).buffer.asUint8List())
          ..add(keyBytes)
          ..add((ByteData(8)..setUint64(0, databaseBytes.length)).buffer.asUint8List())
          ..add(databaseBytes))
        .toBytes();
  }

  /// Parses [bytes], rejecting any deviation from the record layout with
  /// [BackupFormatException].
  factory FundLensBackupPayload.decode(List<int> bytes) {
    if (bytes.length < _recordPrefixBytes) {
      throw const BackupFormatException('payload record is truncated');
    }
    final buffer = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final view = ByteData.sublistView(buffer);
    if (view.getUint16(0) != keyLengthBytes) {
      throw const BackupFormatException('database key length must be 64');
    }
    final keyHex = ascii.decode(Uint8List.sublistView(buffer, 2, 2 + keyLengthBytes));
    if (!_lowerHex64.hasMatch(keyHex)) {
      throw const BackupFormatException('database key must be 64 lowercase hex characters');
    }
    final declaredLength = view.getUint64(2 + keyLengthBytes);
    final remaining = buffer.length - _recordPrefixBytes;
    if (declaredLength != remaining) {
      throw const BackupFormatException('declared database length differs from remaining bytes');
    }
    return FundLensBackupPayload(
      databaseKeyHex: keyHex,
      databaseBytes: Uint8List.fromList(Uint8List.sublistView(buffer, _recordPrefixBytes)),
    );
  }
}
