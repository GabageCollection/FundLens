import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/fundlens_app.dart';
import 'application/app_dependencies.dart';
import 'application/startup_automation.dart';
import 'backup/backup_service.dart';
import 'backup/database_restore_service.dart';
import 'backup/pointycastle_backup_cipher.dart';
import 'data_engine/installed_engine_locator.dart';
import 'data_engine/local_engine_process.dart';
import 'data_engine/process_data_engine_client.dart';
import 'features/holdings/holding_actions.dart';
import 'features/import_review/import_review_controller.dart';
import 'features/import_review/import_source_panel.dart';
import 'features/settings/app_info_section.dart';
import 'features/settings/backup_section.dart';
import 'features/settings/persisted_settings.dart';
import 'features/settings/privacy_section.dart';
import 'market/quote_refresh_service.dart';
import 'security/temporary_import_store.dart';
import 'storage/app_database.dart';
import 'storage/database_key_store.dart';
import 'storage/database_opener.dart';
import 'updates/update_checker.dart';
import 'updates/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 恢复上次会话的窗口尺寸与位置;首次运行使用默认 1440×900。
  await windowManager.ensureInitialized();
  await _restoreWindowBounds();

  final supportDir = await getApplicationSupportDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final dbFile = File(p.join(supportDir.path, 'fundlens.db'));
  final keyStore = SecureDatabaseKeyStore(const FlutterSecureStorage(), (
    length,
  ) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  });
  final keyHex = await keyStore.readOrCreate();
  final database = AppDatabase(openEncryptedDatabase(dbFile, keyHex));
  final lifecycle = DriftDatabaseLifecycle(
    databaseFile: dbFile,
    database: database,
  );

  final backupCipher = PointyCastleBackupCipher();
  const backupFiles = IoBackupFileSystem();

  // The data engine runs as a supervised local child process. An installed
  // build uses its bundled engine; development falls back to the repo venv.
  final bundledEngine = const InstalledEngineLocator().locate();
  final ProcessAdapter engineAdapter = bundledEngine != null
      ? InstalledEngineProcessAdapter(executablePath: bundledEngine)
      : LocalEngineProcessAdapter(engineDirectory: _engineDirectory());
  final engineClient = ProcessDataEngineClient(adapter: engineAdapter);

  // Temporary screenshot copies live in per-job directories; orphans left
  // by a crash are swept on startup. Failures are nonblocking privacy
  // issues and retried on the next launch; the outcome feeds the privacy
  // section's 临时清理 row.
  final tempPrivacyIssues = <String>[];
  final importTempStore = TemporaryImportStore(
    root: Directory(p.join(supportDir.path, 'import_tmp')),
    onPrivacyIssue: (code) {
      debugPrint('privacy issue: $code');
      tempPrivacyIssues.add(code);
    },
  );

  // Explicit container so settings can be loaded before the first frame and
  // startup automation can run after `runApp` without depending on a page.
  final container = ProviderContainer(
    overrides: [
      databaseLifecycleProvider.overrideWithValue(lifecycle),
      backupServiceProvider.overrideWithValue(
        BackupService(
          databasePath: dbFile.path,
          lifecycle: lifecycle,
          keyStore: keyStore,
          cipher: backupCipher,
          files: backupFiles,
        ),
      ),
      databaseRestoreServiceProvider.overrideWithValue(
        DatabaseRestoreService(
          databasePath: dbFile.path,
          lifecycle: lifecycle,
          keyStore: keyStore,
          cipher: backupCipher,
          files: backupFiles,
          inspector: const SqliteBackupDatabaseInspector(),
          supportedSchemaVersion: database.schemaVersion,
          recoveryDirectoryPath: p.join(supportDir.path, 'restore-recovery'),
        ),
      ),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
      dataEngineClientProvider.overrideWithValue(engineClient),
      importFilePickerProvider.overrideWithValue(
        const FilePickerImportFilePicker(),
      ),
      screenshotTempStoreProvider.overrideWithValue(importTempStore),
      importDraftStoreProvider.overrideWithValue(
        FileImportDraftStore(
          File(p.join(supportDir.path, 'import_draft.json')),
        ),
      ),
      importRecordStoreProvider.overrideWithValue(
        FileImportRecordStore(
          File(p.join(supportDir.path, 'last_import.json')),
        ),
      ),
      updateCheckerProvider.overrideWithValue(
        UpdateChecker(
          manifestUrl: kUpdateManifestUrl,
          currentVersion: packageInfo.version,
        ),
      ),
      appInfoProvider.overrideWithValue((
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      )),
      updateServiceProvider.overrideWithValue(
        UpdateService(
          tempDirectory: Directory(p.join(supportDir.path, 'updates')),
        ),
      ),
      // Resolved through the provider graph so a completed restore swaps
      // the underlying database for quote writes as well.
      quoteRefreshServiceProvider.overrideWith(
        (ref) => QuoteRefreshService(
          engine: engineClient,
          holdings: ref.watch(holdingRepositoryProvider),
          quoteCache: DriftQuoteCacheStore(ref.watch(appDatabaseProvider)),
          clock: DateTime.now,
        ),
      ),
    ],
  );
  await loadPersistedSettings(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FundLensBootstrapApp(),
    ),
  );

  // 窗口移动/缩放后持久化位置与尺寸;关闭事件由系统保证最终一次保存。
  windowManager.addListener(_WindowBoundsPersistence());

  unawaited(runStartupAutomation(container));
  unawaited(() async {
    final removed = await importTempStore.sweepOrphans();
    container.read(tempCleanupResultProvider.notifier).state = TempCleanupResult(
      removedJobs: removed,
      issueReported: tempPrivacyIssues.isNotEmpty,
    );
  }());
}

/// Locates the repository `engine/` directory relative to the current
/// working directory, allowing `FUNDLENS_ENGINE_DIR` to override it.
String _engineDirectory() {
  final fromEnv = Platform.environment['FUNDLENS_ENGINE_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = p.join(dir.path, 'engine');
    if (Directory(candidate).existsSync()) return candidate;
    dir = dir.parent;
  }
  return p.join(Directory.current.path, 'engine');
}

/// 监听窗口几何变化并落盘。
class _WindowBoundsPersistence extends WindowListener {
  Timer? _debounce;

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMoved() => _schedule();

  @override
  void onWindowClose() => unawaited(saveWindowBounds());

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), saveWindowBounds);
  }
}

/// 窗口位置持久化文件(%APPDATA%/../FundLens 支持目录下)。
Future<File> _windowBoundsFile() async {
  final supportDir = await getApplicationSupportDirectory();
  return File(p.join(supportDir.path, 'window_bounds.json'));
}

/// 恢复窗口尺寸与位置。文件缺失或损坏时静默使用系统默认。
Future<void> _restoreWindowBounds() async {
  try {
    final file = await _windowBoundsFile();
    if (!file.existsSync()) return;
    final json = jsonDecode(await file.readAsString());
    if (json is! Map) return;
    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    final x = (json['x'] as num?)?.toDouble();
    final y = (json['y'] as num?)?.toDouble();
    if (width != null && height != null && width >= 1280 && height >= 720) {
      await windowManager.setSize(Size(width, height));
    }
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
  } catch (_) {
    // 窗口状态丢失不影响启动;下次退出时会重新写入。
  }
}

/// 保存当前窗口尺寸与位置。由 [FundLensWindowListener] 在移动/缩放后调用。
Future<void> saveWindowBounds() async {
  try {
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    final file = await _windowBoundsFile();
    await file.writeAsString(
      '{"width":${size.width},"height":${size.height},'
      '"x":${position.dx},"y":${position.dy}}',
    );
  } catch (_) {
    // 保存失败无用户可见影响。
  }
}

/// Root widget kept provider-free so widget smoke tests can pump the shell
/// without bootstrapping the encrypted database.
class FundLensBootstrapApp extends StatelessWidget {
  const FundLensBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) => const FundLensApp();
}
