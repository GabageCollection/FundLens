import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FundLensBootstrapApp()));
}

class FundLensBootstrapApp extends StatelessWidget {
  const FundLensBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FundLens',
        home: const Scaffold(body: Center(child: Text('FundLens'))),
      );
}
