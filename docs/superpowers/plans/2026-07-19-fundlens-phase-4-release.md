# FundLens Phase 4 Security, Packaging and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Argon2id + AES-256-GCM 备份、安全恢复、日志与临时文件保护、内置 Python 引擎和 Windows 安装程序，并通过 V1 全量验收。

**Architecture:** 备份加密和数据库替换完全由 Dart 控制；Python 引擎以 PyInstaller one-directory 形式作为只读安装资源交付。Inno Setup 将 Flutter release bundle、引擎、OCR 模型、字体、许可证和文档装入单一 Windows 安装程序，用户数据留在应用支持目录。

**Tech Stack:** PointyCastle、crypto、Flutter integration_test、PyInstaller、PowerShell、Inno Setup、Windows clean VM。

## Global Constraints

- 备份密码永不保存、记录或传给 Python。
- sqlite3mc 数据库密钥只允许出现在 Windows 安全存储或经过备份密码认证加密的载荷中，绝不出现在备份明文头。
- 备份 KDF 固定为 Argon2id：32-byte key、16-byte random salt、3 iterations、65536 KiB memory、1 lane。
- 备份 AEAD 固定为 AES-256-GCM：12-byte random nonce、128-bit tag；每份备份重新生成盐和 nonce。
- 恢复必须先在临时目录解密、校验 SHA-256 和数据库 schema，再原子替换；替换前保留可恢复副本。
- 日志不得包含完整持仓金额、原始 OCR 文本、截图内容、数据库密钥或备份密码。
- 确认导入或显式丢弃后清理临时截图和中间 OCR 图；不得删除用户原文件。
- 安装包不得包含真实截图、真实持仓、开发日志、缓存、API key 或用户备份。
- 卸载默认保留用户数据库；只有用户明确勾选“删除本地数据”才删除，并二次确认。
- 发布门禁必须在干净 Windows VM 上运行，不以开发机成功替代。

---

### Task 1: Define and test the encrypted backup container

**Files:**
- Modify: `apps/fundlens_windows/pubspec.yaml`
- Create: `apps/fundlens_windows/lib/backup/backup_format.dart`
- Create: `apps/fundlens_windows/lib/backup/backup_cipher.dart`
- Create: `apps/fundlens_windows/lib/backup/pointycastle_backup_cipher.dart`
- Test: `apps/fundlens_windows/test/backup/backup_cipher_test.dart`
- Test: `apps/fundlens_windows/test/backup/backup_format_test.dart`

**Interfaces:**
- Produces: `BackupCipher.encrypt/decrypt`, `FundLensBackupHeader`, `FundLensBackupPayload`, extension `.fundlens-backup`.
- Consumes: raw encrypted-database bytes, its 64-character database key and a user password held only in memory.

- [x] **Step 1: Add crypto dependencies and failing round-trip tests**

Run: `cd apps/fundlens_windows && flutter pub add pointycastle crypto`

```dart
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
  final encrypted = await cipher.encrypt([1,2,3], 'secret');
  final tampered = [...encrypted]..[encrypted.length - 1] ^= 1;
  await expectLater(cipher.decrypt(encrypted, 'wrong'), throwsA(isA<BackupAuthenticationException>()));
  await expectLater(cipher.decrypt(tampered, 'secret'), throwsA(isA<BackupAuthenticationException>()));
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/backup`

Expected: FAIL because backup types do not exist.

- [x] **Step 3: Implement the versioned container**

The binary layout is:

```text
16 bytes  ASCII magic "FUNDLENS-BACKUP\0"
4 bytes   unsigned big-endian JSON header length
N bytes   UTF-8 canonical JSON header used as AES-GCM AAD
remaining AES-GCM ciphertext followed by 16-byte authentication tag
```

The authenticated plaintext payload is a migration-safe binary record:

```text
2 bytes   unsigned big-endian database-key length (must equal 64)
64 bytes  ASCII hex sqlite3mc database key
8 bytes   unsigned big-endian database length
N bytes   encrypted SQLite database file
```

The database key is inside the AES-GCM ciphertext, never in the header. This is required because a backup restored on another Windows machine cannot access the source machine's Credential Manager.

```dart
final class FundLensBackupHeader {
  const FundLensBackupHeader({required this.createdAtUtc, required this.salt, required this.nonce, required this.payloadSha256});
  static const formatVersion = 1;
  static const argonMemoryKiB = 65536;
  static const argonIterations = 3;
  static const argonLanes = 1;
  final DateTime createdAtUtc;
  final Uint8List salt;
  final Uint8List nonce;
  final String payloadSha256;

  Map<String, Object> toJson() => {
    'format_version': formatVersion,
    'created_at_utc': createdAtUtc.toIso8601String(),
    'kdf': {'name':'argon2id','memory_kib':argonMemoryKiB,'iterations':argonIterations,'lanes':argonLanes,'salt':base64Encode(salt)},
    'cipher': {'name':'aes-256-gcm','nonce':base64Encode(nonce),'tag_bits':128},
    'payload_sha256': payloadSha256,
  };
}
```

Serialize maps in the literal key order above; decoder must ignore unknown header keys but reject unknown format/KDF/cipher versions before allocating large buffers.

- [x] **Step 4: Implement Argon2id and AES-GCM**

```dart
Uint8List deriveBackupKey(String password, Uint8List salt) {
  final generator = Argon2BytesGenerator()
    ..init(Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: 32,
      iterations: 3,
      memory: 65536,
      lanes: 1,
    ));
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final key = Uint8List(32);
  generator.deriveKey(passwordBytes, 0, key, 0);
  passwordBytes.fillRange(0, passwordBytes.length, 0);
  return key;
}

Uint8List cryptGcm(bool encrypt, Uint8List input, Uint8List key, Uint8List nonce, Uint8List aad) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(encrypt, AEADParameters<KeyParameter>(KeyParameter(key), 128, nonce, aad));
  try {
    return cipher.process(input);
  } finally {
    key.fillRange(0, key.length, 0);
  }
}
```

Map GCM authentication failures and wrong passwords to `BackupAuthenticationException` without revealing which check failed. After decryption, compare payload SHA-256 in constant time, require an exactly 64-character lowercase hexadecimal database key, and reject a declared database length that differs from remaining bytes.

- [x] **Step 5: Run crypto tests and commit**

Run: `flutter test apps/fundlens_windows/test/backup && flutter analyze apps/fundlens_windows`

Expected: PASS for round-trip, unique salt/nonce, wrong password, tag tamper, header tamper, truncation, unsupported version and 100 MiB size guard.

```bash
git add apps/fundlens_windows/pubspec.yaml apps/fundlens_windows/pubspec.lock apps/fundlens_windows/lib/backup apps/fundlens_windows/test/backup
git commit -m "feat(backup): add authenticated encrypted backup format"
```

---

### Task 2: Implement safe database backup, restore and settings UI

**Files:**
- Create: `apps/fundlens_windows/lib/backup/backup_service.dart`
- Create: `apps/fundlens_windows/lib/backup/database_restore_service.dart`
- Create: `apps/fundlens_windows/lib/features/settings/backup_section.dart`
- Test: `apps/fundlens_windows/test/backup/backup_service_test.dart`
- Test: `apps/fundlens_windows/test/backup/database_restore_service_test.dart`
- Test: `apps/fundlens_windows/test/features/settings/backup_section_test.dart`

**Interfaces:**
- Produces: `BackupService.create(destination, password)`, `DatabaseRestoreService.restore(source, password)`.
- Consumes: database lifecycle lock, database path, backup cipher, file-system adapter.

- [x] **Step 1: Write failing non-destructive restore tests**

```dart
test('wrong password never closes or replaces current database', () async {
  await expectLater(service.restore(badBackup, 'wrong'), throwsA(isA<BackupAuthenticationException>()));
  expect(files.bytesAt(currentDb), originalDatabaseBytes);
  expect(lifecycle.closeCount, 0);
});

test('replacement failure restores the pre-restore copy', () async {
  files.failAtomicMove = true;
  await expectLater(service.restore(validBackup, 'secret'), throwsA(isA<RestoreFailedException>()));
  expect(files.bytesAt(currentDb), originalDatabaseBytes);
  expect(await repository.watchAll().first, originalHoldings);
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/backup/database_restore_service_test.dart`

Expected: FAIL because restore service does not exist.

- [x] **Step 3: Implement creation and staged restore**

`BackupService.create` acquires the database lifecycle lock, checkpoints WAL, copies the encrypted DB to a private temporary file, reads the current database key from `DatabaseKeyStore`, builds `FundLensBackupPayload(databaseKeyHex, databaseBytes)`, encrypts it with the user password, writes `destination.tmp`, fsyncs, then atomically renames. It deletes temporary material and zeroes the in-memory key bytes in `finally`.

`DatabaseRestoreService.restore` executes exactly:

1. Read and authenticate the backup into a private temp directory.
2. Verify plaintext SHA-256, file size and backup format.
3. Parse the encrypted payload, open the candidate database with the payload's database key, run `PRAGMA integrity_check`, read schema version, and reject unsupported future schema.
4. Acquire lifecycle lock and close the current Drift database.
5. Copy current DB/WAL/SHM and current database key to an in-memory recovery record plus timestamped recovery directory.
6. Atomically move the validated candidate into place and write the payload database key to `DatabaseKeyStore`.
7. Reopen with the restored key and run a read query.
8. On any failure after step 4, restore both the recovery database files and previous key, then reopen them.

The candidate is never moved over current data before steps 1–3 pass.

- [x] **Step 4: Replace the reserved settings section with working controls**

UI requires password + confirmation on create, password on restore, file picker restricted to `.fundlens-backup`, progress state, and explicit restore warning. Never retain password in controller state after completion. Restore confirmation names the chosen file and states that a recovery copy will be kept.

- [x] **Step 5: Run tests and commit**

Run: `flutter test apps/fundlens_windows/test/backup apps/fundlens_windows/test/features/settings/backup_section_test.dart`

Expected: PASS for success, wrong password, corrupt file, unsupported schema, disk-full injection, atomic-move failure and successful rollback.

```bash
git add apps/fundlens_windows/lib/backup apps/fundlens_windows/lib/features/settings apps/fundlens_windows/test/backup apps/fundlens_windows/test/features/settings
git commit -m "feat(backup): add safe backup and restore workflow"
```

---

### Task 3: Enforce log redaction, path boundaries and temporary-file cleanup

**Files:**
- Create: `apps/fundlens_windows/lib/security/redacting_logger.dart`
- Create: `apps/fundlens_windows/lib/security/selected_path_guard.dart`
- Create: `apps/fundlens_windows/lib/security/temporary_import_store.dart`
- Create: `engine/src/fundlens_engine/security.py`
- Test: `apps/fundlens_windows/test/security/redacting_logger_test.dart`
- Test: `apps/fundlens_windows/test/security/selected_path_guard_test.dart`
- Test: `apps/fundlens_windows/test/security/temporary_import_store_test.dart`
- Test: `engine/tests/test_security.py`

**Interfaces:**
- Produces: structured redacted events and allowlisted file access.
- Consumes: event codes, non-sensitive counts/durations and user-selected canonical paths.

- [x] **Step 1: Write failing secret-leak tests**

```dart
test('logger removes money, OCR text, keys and passwords', () {
  final output = logger.format('import.failed', {
    'amount': '78347.87',
    'ocr_text': '脱敏基金 +428.96',
    'database_key': 'abcd',
    'password': 'secret',
    'issue_count': 2,
  });
  expect(output, isNot(contains('78347.87')));
  expect(output, isNot(contains('脱敏基金')));
  expect(output, isNot(contains('abcd')));
  expect(output, isNot(contains('secret')));
  expect(output, contains('"issue_count":2'));
});
```

```python
def test_engine_rejects_unselected_path(tmp_path) -> None:
    with pytest.raises(PathAccessError):
        validate_selected_file(str(tmp_path / "not-selected.png"), allowed_paths=[])
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/security && python -m pytest engine/tests/test_security.py -q`

Expected: FAIL because security adapters do not exist.

- [x] **Step 3: Implement allowlists and redaction**

Logger accepts only registered event schemas; keys `amount`, `value`, `profit`, `ocr_text`, `screenshot`, `database_key`, `backup_password`, `password` are always replaced with `"[REDACTED]"`. Unknown values default to redacted, not included.

Canonicalize selected paths before sending them to Python. Python resolves symlinks, requires the resolved path to equal one of the request's exact allowlisted paths, verifies regular-file type and extension, and imposes per-file/total size limits. The engine writes only beneath its provided job temp directory.

- [x] **Step 4: Implement cleanup and crash recovery**

`TemporaryImportStore` creates per-job directories with restrictive permissions where available, records no user content in names, and removes them after commit/discard. On app startup it removes orphaned job directories older than 24 hours. Cleanup failures create a nonblocking privacy issue and retry on next launch.

- [x] **Step 5: Verify and commit**

Run: `flutter test apps/fundlens_windows/test/security && python -m pytest engine/tests/test_security.py -q && python -m ruff check engine`

Expected: PASS for traversal, symlink, extension spoofing, oversize input, cleanup retry and redaction.

```bash
git add apps/fundlens_windows/lib/security apps/fundlens_windows/test/security engine/src/fundlens_engine/security.py engine/tests/test_security.py
git commit -m "feat(security): enforce local data boundaries"
```

---

### Task 4: Package the Python engine and build the Windows installer

**Files:**
- Create: `engine/fundlens_engine.spec`
- Create: `tools/build_engine.ps1`
- Create: `tools/build_windows_release.ps1`
- Create: `installer/FundLens.iss`
- Create: `installer/assets/LICENSES.txt`
- Create: `apps/fundlens_windows/lib/data_engine/installed_engine_locator.dart`
- Test: `apps/fundlens_windows/test/data_engine/installed_engine_locator_test.dart`
- Create: `tests/release/verify_bundle.ps1`

**Interfaces:**
- Produces: `dist/engine/fundlens_engine.exe`, Flutter release bundle, `dist/installer/FundLens-Setup.exe`.
- Consumes: locked Python/Dart dependencies, PaddleOCR model files, Inno Setup `ISCC.exe`.

- [x] **Step 1: Write failing bundle-verification tests**

```powershell
$ErrorActionPreference = 'Stop'
$required = @(
  'FundLens.exe',
  'fundlens_engine/fundlens_engine.exe',
  'fundlens_engine/models',
  'data/flutter_assets/AssetManifest.bin'
)
foreach ($path in $required) {
  if (-not (Test-Path (Join-Path $args[0] $path))) { throw "Missing bundle item: $path" }
}
$forbidden = Get-ChildItem $args[0] -Recurse -File | Where-Object {
  $_.Name -match '\.(log|fundlens-backup)$' -or $_.FullName -match 'tests\\fixtures\\ocr'
}
if ($forbidden) { throw "Forbidden release files: $($forbidden.FullName -join ', ')" }
```

- [x] **Step 2: Run verifier and confirm failure**

Run: `powershell -File tests/release/verify_bundle.ps1 dist/windows`

Expected: FAIL because no release bundle exists.

- [x] **Step 3: Create deterministic engine packaging**

`fundlens_engine.spec` must use `COLLECT`/one-directory, include PaddleOCR runtime modules and only the required Chinese detection/recognition/classification models, exclude pytest/dev caches, and set `console=False`. `build_engine.ps1` recreates an isolated venv from `requirements.lock`, runs Python tests, invokes PyInstaller with `--clean --noconfirm`, copies model licenses, and calls `fundlens_engine.exe` with a health JSON line to verify protocol version 1.

`InstalledEngineLocator` resolves only `<install-dir>/fundlens_engine/fundlens_engine.exe`, verifies it is inside the install directory, and never searches `PATH` or the user's Python installation.

- [x] **Step 4: Build Flutter release and installer**

`build_windows_release.ps1` executes:

```powershell
$ErrorActionPreference = 'Stop'
powershell -File tools/verify_windows_toolchain.ps1
powershell -File tools/build_engine.ps1
dart test packages/fundlens_core
flutter test apps/fundlens_windows
flutter analyze apps/fundlens_windows
flutter build windows --release --project-dir apps/fundlens_windows
powershell -File tests/release/verify_bundle.ps1 apps/fundlens_windows/build/windows/x64/runner/Release
& "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe" installer/FundLens.iss
```

The Inno script installs per-user by default, creates Start Menu/Desktop choices, includes Visual C++ runtime prerequisite handling, writes no user data under Program Files, and leaves `%APPDATA%/FundLens` intact on normal uninstall. A separate confirmation checkbox is required to delete it.

- [ ] **Step 5: Verify bundle and commit packaging**

Run: `powershell -File tools/build_windows_release.ps1`

Expected: release verifier passes; engine health returns schema version 1; installer is produced.

```bash
git add engine/fundlens_engine.spec tools installer apps/fundlens_windows/lib/data_engine apps/fundlens_windows/test/data_engine tests/release
git commit -m "build: package FundLens Windows installer"
```

---

### Task 5: Run performance, clean-VM acceptance and publish documentation

**Files:**
- Create: `apps/fundlens_windows/integration_test/performance_test.dart`
- Create: `tests/release/clean_vm_acceptance.ps1`
- Create: `docs/user-guide.md`
- Create: `docs/privacy-and-security.md`
- Create: `docs/known-limitations.md`
- Create: `docs/test-report-template.md`
- Create: `docs/releases/v1.0.0-test-report.md`
- Modify: `README.md`

**Interfaces:**
- Produces: reproducible acceptance commands and release evidence.
- Consumes: signed or unsigned release candidate installer built in Task 4.

- [x] **Step 1: Add failing performance budgets**

```dart
testWidgets('2000 holdings and 500 snapshots meet interaction budgets', (tester) async {
  final fixture = await LargePortfolioFixture.create(holdings: 2000, snapshots: 500);
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(releaseLikeHarness(fixture));
  await tester.pumpAndSettle();
  expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  stopwatch
    ..reset()
    ..start();
  await tester.tap(find.text('资产分析'));
  await tester.pumpAndSettle();
  expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
  expect(fixture.repository.fullReadCount, 1);
  expect(fixture.engine.startCount, 1);
});
```

- [x] **Step 2: Run performance test before optimization**

Run on Windows release/profile mode: `flutter test integration_test/performance_test.dart -d windows`

Expected: record actual numbers; if a budget fails, profile and fix the measured bottleneck without reducing precision or dropping records.

- [x] **Step 3: Write the clean-VM acceptance script**

The script installs silently into a disposable Windows VM user, launches FundLens, waits for the window, then drives a documented manual checklist with synthetic files. It records installer hash, Windows version, Flutter/Dart/Python dependency locks, test commands, timings and screenshots that contain only synthetic data. It then upgrades over the previous build, confirms database retention, uninstalls, and confirms data remains unless the deletion option was explicitly selected.

Required checklist:

1. Add manual cash, deposit and physical gold.
2. Import synthetic Alipay screenshot in partial mode and resolve one low-confidence field.
3. Import synthetic THS screenshot; confirm name/value/quantity/cost/signs.
4. Refresh fake/staging quotes; verify amount-only Alipay value remains unchanged.
5. Save two snapshots and compare “资产金额变化”.
6. Create encrypted backup; reject wrong password; restore correct backup.
7. Kill the engine and verify degraded manual/cached mode.
8. Verify no advice wording and no real/user files in installation directory.

- [x] **Step 4: Write user-facing documentation and the test report**

`user-guide.md` covers the six pages, supported assets, manual/CSV/Excel/OCR imports, partial/full distinction, quote dates, snapshot meaning and backup recovery. `known-limitations.md` explicitly states no direct bonds, no transaction records, no real-time quotes, no cloud, no Android and no investment advice. `privacy-and-security.md` documents local processing, temporary cleanup, database key storage, backup cryptography and log redaction without exposing secrets.

- [ ] **Step 5: Run the complete release gate**

Run:

```powershell
dart test packages/fundlens_core
flutter test apps/fundlens_windows
flutter analyze apps/fundlens_windows
python -m pytest engine/tests -m "not live" -q
python -m ruff check engine
python -m mypy engine/src
powershell -File tools/build_windows_release.ps1
powershell -File tests/release/clean_vm_acceptance.ps1 dist/installer/FundLens-Setup.exe
```

Expected: every command exits `0`; `docs/releases/v1.0.0-test-report.md` contains actual observed evidence, installer SHA-256 and zero unresolved release-blocking defects.

- [ ] **Step 6: Commit release evidence**

```bash
git add README.md docs apps/fundlens_windows/integration_test tests/release
git commit -m "docs: add FundLens V1 release evidence"
```

## Phase 4 Completion Gate

- [ ] Backup cryptography passes tamper, wrong-password and unique-randomness tests.
- [ ] Failed restore cannot alter current data; post-close failure restores the recovery copy.
- [ ] Logs and engine diagnostics pass secret-leak tests.
- [ ] Installed app launches only its bundled, version-matched Python engine.
- [ ] Installer contains no fixtures, logs, backups, keys or user screenshots.
- [ ] Performance budgets pass with 2,000 holdings and 500 snapshots.
- [ ] Clean-VM install, upgrade, restore, degraded mode and uninstall retention pass.
- [ ] User documentation states every V1 limitation and contains no investment advice.
