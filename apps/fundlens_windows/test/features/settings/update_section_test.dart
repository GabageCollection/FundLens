import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/features/settings/update_section.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/updates/update_checker.dart';
import 'package:fundlens_windows/updates/update_service.dart';

Widget harness({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: FundLensTheme.light,
      home: const Scaffold(body: UpdateSection()),
    ),
  );
}

/// Test double: verifies instantly without network or file IO.
final class _FakeInstaller implements UpdateInstaller {
  UpdateManifest? installed;

  @override
  Future<File> downloadVerifiedAndLaunch(
    UpdateManifest manifest, {
    void Function(double? progress)? onProgress,
  }) async {
    installed = manifest;
    onProgress?.call(1);
    return File(manifest.url);
  }
}

void main() {
  testWidgets('disabled checker explains that no update url is configured',
      (tester) async {
    await tester.pumpWidget(harness(overrides: [
      updateCheckerProvider.overrideWithValue(
        const UpdateChecker(manifestUrl: '', currentVersion: '1.0.0'),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('当前版本：1.0.0'), findsOneWidget);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('未配置更新地址，无法检查更新'), findsOneWidget);
  });

  testWidgets('a newer manifest offers a download that verifies and launches',
      (tester) async {
    final manifestJson = '''
      {
        "version": "1.1.0",
        "url": "https://example.com/FundLens-Setup.exe",
        "sha256": "${sha256.convert(const [1, 2, 3])}",
        "notes": "修复按钮失效问题"
      }
      ''';
    final installer = _FakeInstaller();

    await tester.pumpWidget(harness(overrides: [
      updateCheckerProvider.overrideWithValue(
        UpdateChecker(
          manifestUrl: 'https://example.com/version.json',
          currentVersion: '1.0.0',
          fetcher: (_) async => manifestJson,
        ),
      ),
      updateServiceProvider.overrideWithValue(installer),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('发现新版本 1.1.0'), findsOneWidget);
    expect(find.text('修复按钮失效问题'), findsOneWidget);

    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('安装程序已启动，请按提示完成安装。'), findsOneWidget);
    expect(installer.installed?.version, '1.1.0');
  });
}
