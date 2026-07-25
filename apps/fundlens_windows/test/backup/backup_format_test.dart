import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/backup/backup_format.dart';

void main() {
  final validKey = List.filled(32, '1a').join();

  group('FundLensBackupPayload', () {
    test('encode writes the documented binary layout', () {
      final databaseBytes = Uint8List.fromList(utf8.encode('synthetic database'));
      final payload = FundLensBackupPayload(
        databaseKeyHex: validKey,
        databaseBytes: databaseBytes,
      );

      final encoded = payload.encode();
      final view = ByteData.sublistView(encoded);

      expect(view.getUint16(0), 64);
      expect(ascii.decode(encoded.sublist(2, 66)), validKey);
      expect(view.getUint64(66), databaseBytes.length);
      expect(encoded.sublist(74), databaseBytes);
    });

    test('round trips through encode and decode', () {
      final payload = FundLensBackupPayload(
        databaseKeyHex: validKey,
        databaseBytes: Uint8List.fromList(List.generate(257, (i) => i & 0xFF)),
      );

      final decoded = FundLensBackupPayload.decode(payload.encode());

      expect(decoded.databaseKeyHex, payload.databaseKeyHex);
      expect(decoded.databaseBytes, payload.databaseBytes);
    });

    test('rejects a database key that is not 64 lowercase hex characters', () {
      final bytes = Uint8List.fromList(const [1, 2, 3]);

      expect(
        () => FundLensBackupPayload(databaseKeyHex: 'ab', databaseBytes: bytes),
        throwsArgumentError,
      );
      expect(
        () => FundLensBackupPayload(
          databaseKeyHex: validKey.toUpperCase(),
          databaseBytes: bytes,
        ),
        throwsArgumentError,
      );
      expect(
        () => FundLensBackupPayload(
          databaseKeyHex: List.filled(32, '1g').join(),
          databaseBytes: bytes,
        ),
        throwsArgumentError,
      );
    });

    test('decode rejects a key length field other than 64', () {
      final payload = FundLensBackupPayload(
        databaseKeyHex: validKey,
        databaseBytes: Uint8List.fromList(const [1, 2, 3]),
      );
      final encoded = payload.encode();
      encoded[1] = 63;

      expect(
        () => FundLensBackupPayload.decode(encoded),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('decode rejects a declared database length differing from remaining bytes', () {
      final payload = FundLensBackupPayload(
        databaseKeyHex: validKey,
        databaseBytes: Uint8List.fromList(const [1, 2, 3]),
      );
      final tampered = payload.encode();
      ByteData.sublistView(tampered).setUint64(66, 4);

      expect(
        () => FundLensBackupPayload.decode(tampered),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('decode rejects a key that is not lowercase hex inside the record', () {
      final payload = FundLensBackupPayload(
        databaseKeyHex: validKey,
        databaseBytes: Uint8List.fromList(const [1, 2, 3]),
      );
      final tampered = payload.encode();
      tampered[2] = ascii.encode('G').first;

      expect(
        () => FundLensBackupPayload.decode(tampered),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('decode rejects truncated input', () {
      expect(
        () => FundLensBackupPayload.decode(Uint8List(20)),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('FundLensBackupHeader', () {
    FundLensBackupHeader buildHeader() => FundLensBackupHeader(
          createdAtUtc: DateTime.utc(2026, 7, 25, 12, 30),
          salt: Uint8List.fromList(List.generate(16, (i) => i)),
          nonce: Uint8List.fromList(List.generate(12, (i) => 0xA0 + i)),
          payloadSha256: List.filled(32, '0f').join(),
        );

    test('serializes keys in the documented canonical order', () {
      expect(
        buildHeader().toJson().keys.toList(),
        ['format_version', 'created_at_utc', 'kdf', 'cipher', 'payload_sha256'],
      );
      final json = buildHeader().toJson();
      expect(
        (json['kdf']! as Map<String, Object>).keys.toList(),
        ['name', 'memory_kib', 'iterations', 'lanes', 'salt'],
      );
      expect(
        (json['cipher']! as Map<String, Object>).keys.toList(),
        ['name', 'nonce', 'tag_bits'],
      );
      expect(json['format_version'], 1);
      expect(json['created_at_utc'], '2026-07-25T12:30:00.000Z');
    });

    test('json round trips and ignores unknown keys', () {
      final header = buildHeader();
      final json = jsonDecode(jsonEncode(header.toJson())) as Map<String, Object?>
        ..['future_field'] = 42;

      final decoded = FundLensBackupHeader.fromJson(json);

      expect(decoded.createdAtUtc, header.createdAtUtc);
      expect(decoded.salt, header.salt);
      expect(decoded.nonce, header.nonce);
      expect(decoded.payloadSha256, header.payloadSha256);
    });

    test('rejects salt or nonce of the wrong length', () {
      final json = jsonDecode(jsonEncode(buildHeader().toJson())) as Map<String, Object?>;
      (json['kdf']! as Map<String, Object?>)['salt'] = base64Encode(Uint8List(8));

      expect(() => FundLensBackupHeader.fromJson(json), throwsFormatException);
    });
  });

  group('container constants', () {
    test('magic is the 16-byte ASCII FUNDLENS-BACKUP marker', () {
      expect(kFundLensBackupMagic.length, 16);
      expect(ascii.decode(kFundLensBackupMagic.sublist(0, 15)), 'FUNDLENS-BACKUP');
      expect(kFundLensBackupMagic[15], 0);
    });

    test('backup extension is .fundlens-backup', () {
      expect(kFundLensBackupExtension, '.fundlens-backup');
    });

    test('size guard is 100 MiB', () {
      expect(kMaxBackupBytes, 100 * 1024 * 1024);
    });
  });
}
