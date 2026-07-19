import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/database_opener.dart';

void main() {
  test('release runtime exposes cipher and rejects a wrong key', () async {
    final file = File('${Directory.systemTemp.path}/fundlens-cipher-smoke.db');
    final keyA = List.filled(32, '11').join();
    final keyB = List.filled(32, '22').join();
    final db = AppDatabase(openEncryptedDatabase(file, keyA));
    await db.customSelect('PRAGMA cipher;').getSingle();
    await db.close();
    final wrongKeyDb = AppDatabase(openEncryptedDatabase(file, keyB));
    await expectLater(
      wrongKeyDb.customSelect('SELECT * FROM holding').get(),
      throwsA(anything),
    );
    await wrongKeyDb.close();
  });
}
