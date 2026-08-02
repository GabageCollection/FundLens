import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/fundlens_app.dart';
import 'application/app_dependencies.dart';
import 'backup/backup_service.dart';
import 'backup/database_restore_service.dart';
import 'backup/pointycastle_backup_cipher.dart';
import 'data_engine/installed_engine_locator.dart';
import 'data_engine/local_engine_process.dart';
import 'data_engine/process_data_engine_client.dart';
import 'features/holdings/holding_actions.dart';
import 'features/import_review/import_review_controller.dart';
import 'features/import_review/import_source_panel.dart';
import 'features/settings/backup_section.dart';
import 'features/settings/persisted_settings.dart';
import 'features/settings/update_section.dart';
import 'market/quote_refresh_service.dart';
import 'security/temporary_import_store.dart';
import 'storage/app_database.dart';
import 'storage/database_key_store.dart';
import 'storage/database_opener.dart';
import 'updates/update_checker.dart';
import 'updates/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // issues and retried on the next launch.
  final importTempStore = TemporaryImportStore(
    root: Directory(p.join(supportDir.path, 'import_tmp')),
    onPrivacyIssue: debugPrint,
  );
  unawaited(importTempStore.sweepOrphans());

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

/// Root widget kept provider-free so widget smoke tests can pump the shell
/// without bootstrapping the encrypted database.
class FundLensBootstrapApp extends StatelessWidget {
  const FundLensBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) => const FundLensApp();
}
