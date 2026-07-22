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

  runApp(
    ProviderScope(
      overrides: [
        holdingRepositoryProvider
            .overrideWithValue(DriftHoldingRepository(database)),
        snapshotRepositoryProvider
            .overrideWithValue(DriftSnapshotRepository(database)),
        portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
        dataQualityCalculatorProvider
            .overrideWithValue(DataQualityCalculator()),
      ],
      child: const FundLensBootstrapApp(),
    ),
  );
}

/// Root widget kept provider-free so widget smoke tests can pump the shell
/// without bootstrapping the encrypted database.
class FundLensBootstrapApp extends StatelessWidget {
  const FundLensBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) => const FundLensApp();
}
