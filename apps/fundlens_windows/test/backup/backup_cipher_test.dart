import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/backup/backup_cipher.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/pointycastle_backup_cipher.dart';

var _deterministicCounter = 0;

/// Counter-based byte source so tests can inject repeatable "randomness".
List<int> deterministicRandom(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = (_deterministicCounter + i) & 0xFF;
  }
  _deterministicCounter += length;
  return bytes;
}

bool _containsSubsequence(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

Map<String, Object?> _headerOf(List<int> backup) {
  final bytes = Uint8List.fromList(backup);
  final headerLength = ByteData.sublistView(bytes).getUint32(16);
  return jsonDecode(utf8.decode(bytes.sublist(20, 20 + headerLength)))
      as Map<String, Object?>;
}

Uint8List _withHeader(List<int> backup, Map<String, Object?> header) {
  final bytes = Uint8List.fromList(backup);
  final headerLength = ByteData.sublistView(bytes).getUint32(16);
  final newHeader = utf8.encode(jsonEncode(header));
  return (BytesBuilder()
        ..add(bytes.sublist(0, 16))
        ..add((ByteData(4)..setUint32(0, newHeader.length)).buffer.asUint8List())
        ..add(newHeader)
        ..add(bytes.sublist(20 + headerLength)))
      .toBytes();
}

void main() {
  group('PointyCastleBackupCipher', () {
    test('backup round trips with fixed test randomness', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final payload = FundLensBackupPayload(databaseKeyHex: List.filled(32, '11').join(), databaseBytes: Uint8List.fromList(utf8.encode('synthetic database')));
      final encrypted = await cipher.encrypt(payload.encode(), 'correct horse');
      final decoded = FundLensBackupPayload.decode(await cipher.decrypt(encrypted, 'correct horse'));
      expect(utf8.decode(decoded.databaseBytes), 'synthetic database');
      expect(decoded.databaseKeyHex, payload.databaseKeyHex);
      expect(encrypted, isNot(contains(utf8.encode('synthetic database'))));
    });

    test('wrong password and tampering are indistinguishable to callers', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final encrypted = await cipher.encrypt([1, 2, 3], 'secret');
      final tampered = [...encrypted]..[encrypted.length - 1] ^= 1;
      await expectLater(cipher.decrypt(encrypted, 'wrong'), throwsA(isA<BackupAuthenticationException>()));
      await expectLater(cipher.decrypt(tampered, 'secret'), throwsA(isA<BackupAuthenticationException>()));
    });

    test('ciphertext never exposes the database key or database bytes', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final payload = FundLensBackupPayload(
        databaseKeyHex: List.filled(32, '2b').join(),
        databaseBytes: Uint8List.fromList(utf8.encode('synthetic database')),
      );

      final encrypted = await cipher.encrypt(payload.encode(), 'correct horse');

      expect(_containsSubsequence(encrypted, ascii.encode(payload.databaseKeyHex)), isFalse);
      expect(_containsSubsequence(encrypted, utf8.encode('synthetic database')), isFalse);
    });

    test('ciphertext tampering fails authentication', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final encrypted = await cipher.encrypt([1, 2, 3], 'secret');
      // Flip one bit of the first ciphertext byte, right after the header.
      final headerLength = ByteData.sublistView(Uint8List.fromList(encrypted)).getUint32(16);
      final tampered = [...encrypted]..[20 + headerLength] ^= 1;

      await expectLater(
        cipher.decrypt(tampered, 'secret'),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('header tampering fails authentication', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final encrypted = await cipher.encrypt([1, 2, 3], 'secret');
      // Flip one bit inside the payload_sha256 hex string; the JSON stays
      // valid but the AAD no longer matches the GCM tag.
      final marker = utf8.encode('"payload_sha256":"');
      final markerIndex = _containsSubsequence(encrypted, marker)
          ? _indexOf(encrypted, marker)
          : -1;
      expect(markerIndex, isNonNegative);
      final tampered = [...encrypted]..[markerIndex + marker.length] ^= 1;

      await expectLater(
        cipher.decrypt(tampered, 'secret'),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('truncated backups are rejected', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final encrypted = await cipher.encrypt([1, 2, 3], 'secret');

      await expectLater(
        cipher.decrypt(encrypted.sublist(0, encrypted.length - 1), 'secret'),
        throwsA(isA<BackupAuthenticationException>()),
      );
      await expectLater(
        cipher.decrypt(encrypted.sublist(0, 10), 'secret'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('unsupported format, kdf or cipher versions are rejected', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      final encrypted = await cipher.encrypt([1, 2, 3], 'secret');

      final futureFormat = _withHeader(encrypted, _headerOf(encrypted)..['format_version'] = 2);
      await expectLater(
        cipher.decrypt(futureFormat, 'secret'),
        throwsA(isA<BackupFormatException>()),
      );

      final wrongKdf = _withHeader(
        encrypted,
        _headerOf(encrypted)..['kdf'] = {..._headerOf(encrypted)['kdf']! as Map<String, Object?>, 'name': 'scrypt'},
      );
      await expectLater(
        cipher.decrypt(wrongKdf, 'secret'),
        throwsA(isA<BackupFormatException>()),
      );

      final wrongCipher = _withHeader(
        encrypted,
        _headerOf(encrypted)..['cipher'] = {..._headerOf(encrypted)['cipher']! as Map<String, Object?>, 'name': 'aes-128-gcm'},
      );
      await expectLater(
        cipher.decrypt(wrongCipher, 'secret'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('unknown header keys are ignored', () async {
      // Craft a backup whose authenticated header carries a future key, using
      // the public KDF/AEAD helpers; the decoder must accept it.
      final salt = Uint8List.fromList(deterministicRandom(16));
      final nonce = Uint8List.fromList(deterministicRandom(12));
      final plaintext = Uint8List.fromList([1, 2, 3]);
      final header = FundLensBackupHeader(
        createdAtUtc: DateTime.utc(2026, 7, 25),
        salt: salt,
        nonce: nonce,
        payloadSha256: sha256.convert(plaintext).toString(),
      );
      final aad = Uint8List.fromList(
        utf8.encode(jsonEncode({...header.toJson(), 'future_field': 42})),
      );
      final key = deriveBackupKey('secret', salt);
      final ciphertext = cryptGcm(true, plaintext, key, nonce, aad);
      final backup = (BytesBuilder()
            ..add(kFundLensBackupMagic)
            ..add((ByteData(4)..setUint32(0, aad.length)).buffer.asUint8List())
            ..add(aad)
            ..add(ciphertext))
          .toBytes();

      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);
      expect(await cipher.decrypt(backup, 'secret'), [1, 2, 3]);
    });

    test('each backup uses a fresh salt and nonce', () async {
      final cipher = PointyCastleBackupCipher();
      final a = await cipher.encrypt([1, 2, 3], 'secret');
      final b = await cipher.encrypt([1, 2, 3], 'secret');

      final headerA = _headerOf(a);
      final headerB = _headerOf(b);
      expect(
        (headerA['kdf']! as Map<String, Object?>)['salt'],
        isNot((headerB['kdf']! as Map<String, Object?>)['salt']),
      );
      expect(
        (headerA['cipher']! as Map<String, Object?>)['nonce'],
        isNot((headerB['cipher']! as Map<String, Object?>)['nonce']),
      );
      expect(a, isNot(b));
    });

    test('encrypt rejects plaintext larger than 100 MiB', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);

      await expectLater(
        cipher.encrypt(Uint8List(kMaxBackupBytes + 1), 'secret'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('decrypt rejects containers larger than 100 MiB', () async {
      final cipher = PointyCastleBackupCipher(randomBytes: deterministicRandom);

      await expectLater(
        cipher.decrypt(Uint8List(kMaxBackupBytes + 1), 'secret'),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
