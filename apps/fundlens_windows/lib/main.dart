import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/fundlens_app.dart';
import 'application/app_dependencies.dart';
import 'data_engine/local_engine_process.dart';
import 'data_engine/process_data_engine_client.dart';
import 'features/holdings/holdings_page.dart';
import 'features/import_review/import_review_controller.dart';
import 'features/import_review/import_source_panel.dart';
import 'market/quote_refresh_service.dart';
import 'storage/app_database.dart';
import 'storage/database_key_store.dart';
import 'storage/database_opener.dart';
import 'storage/holding_repository.dart';
import 'storage/snapshot_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final dbFile = File(p.join(supportDir.path, 'fundlens.db'));
  final keyStore = SecureDatabaseKeyStore(
    const FlutterSecureStorage(),
    (length) {
      final random = Random.secure();
      return List<int>.generate(length, (_) => random.nextInt(256));
    },
  );
  final keyHex = await keyStore.readOrCreate();
  final database = AppDatabase(openEncryptedDatabase(dbFile, keyHex));

  final holdingRepository = DriftHoldingRepository(database);
  final snapshotRepository = DriftSnapshotRepository(database);

  // The data engine runs as a supervised local Python child process.
  final engineClient = ProcessDataEngineClient(
    adapter: LocalEngineProcessAdapter(
      engineDirectory: _engineDirectory(),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        holdingRepositoryProvider.overrideWithValue(holdingRepository),
        snapshotRepositoryProvider.overrideWithValue(snapshotRepository),
        portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
        dataQualityCalculatorProvider
            .overrideWithValue(DataQualityCalculator()),
        dataEngineClientProvider.overrideWithValue(engineClient),
        importFilePickerProvider
            .overrideWithValue(const FilePickerImportFilePicker()),
        screenshotTempStoreProvider.overrideWithValue(
          FileScreenshotTempStore(
            Directory(p.join(supportDir.path, 'import_tmp')),
          ),
        ),
        importDraftStoreProvider.overrideWithValue(
          FileImportDraftStore(
            File(p.join(supportDir.path, 'import_draft.json')),
          ),
        ),
        quoteRefreshServiceProvider.overrideWithValue(
          QuoteRefreshService(
            engine: engineClient,
            holdings: holdingRepository,
            quoteCache: DriftQuoteCacheStore(database),
            clock: DateTime.now,
          ),
        ),
      ],
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
