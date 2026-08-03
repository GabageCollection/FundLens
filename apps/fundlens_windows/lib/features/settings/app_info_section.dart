import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/fundlens_tokens.dart';
import '../../updates/update_checker.dart';
import '../../widgets/app_toast.dart';
import '../../updates/update_service.dart';
import 'widgets/setting_info_row.dart';
import 'widgets/settings_section_card.dart';

/// Running version facts shown in the app info card. The bootstrap overrides
/// this with the real package info; tests inject fixed values.
final appInfoProvider = Provider<({String version, String buildNumber})>(
  (ref) => (version: '开发版', buildNumber: ''),
);

/// Update check wiring. Overridden by the bootstrap with the real app
/// version and a real download directory; tests inject fakes.
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  return const UpdateChecker(manifestUrl: '', currentVersion: '0.0.0-dev');
});

final updateServiceProvider = Provider<UpdateInstaller?>((ref) => null);

/// App info card: version and build number plus the manual update check.
/// Nothing runs on its own — the network is only touched when the user taps
/// 检查更新.
class AppInfoSection extends ConsumerStatefulWidget {
  const AppInfoSection({super.key});

  @override
  ConsumerState<AppInfoSection> createState() => _AppInfoSectionState();
}

class _AppInfoSectionState extends ConsumerState<AppInfoSection> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider);
    return SettingsSectionCard(
      key: const ValueKey('app-info-section'),
      title: '应用信息',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingInfoRow(label: '版本', value: appInfo.version),
          SettingInfoRow(
            label: '构建号',
            value: appInfo.buildNumber.isEmpty ? '—' : appInfo.buildNumber,
          ),
          const SizedBox(height: FundLensTokens.space3),
          Text(
            '只在点击按钮时检查更新，不会自动联网',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: FundLensTokens.space3),
          FilledButton.tonal(
            onPressed: _checking ? null : _checkForUpdate,
            child: Text(_checking ? '正在检查…' : '检查更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checking = true);
    try {
      final result = await ref.read(updateCheckerProvider).check();
      if (!mounted) return;
      switch (result) {
        case UpdateCheckDisabled():
          _showSnack('未配置更新地址，无法检查更新');
        case UpdateUpToDate():
          _showSnack('当前已是最新版本');
        case UpdateCheckFailed(:final message):
          _showSnack(message, isError: true);
        case UpdateAvailable(:final manifest, :final currentVersion):
          await _offerUpdate(manifest, currentVersion);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _offerUpdate(
    UpdateManifest manifest,
    String currentVersion,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _UpdateDialog(
        manifest: manifest,
        currentVersion: currentVersion,
        service: ref.read(updateServiceProvider),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    showAppToast(context, message, isError: isError);
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.manifest,
    required this.currentVersion,
    required this.service,
  });

  final UpdateManifest manifest;
  final String currentVersion;
  final UpdateInstaller? service;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;
  bool _downloading = false;
  bool _launched = false;

  @override
  Widget build(BuildContext context) {
    final manifest = widget.manifest;
    return AlertDialog(
      title: Text('发现新版本 ${manifest.version}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${widget.currentVersion}'),
            if (manifest.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(manifest.notes),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress == null
                    ? '正在下载…'
                    : '正在下载… ${(_progress! * 100).toStringAsFixed(0)}%',
              ),
            ],
            if (_launched) ...[
              const SizedBox(height: 16),
              const Text('安装程序已启动，请按提示完成安装。'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _downloading ? null : () => Navigator.of(context).pop(),
          child: Text(_launched ? '完成' : '取消'),
        ),
        if (!_launched)
          FilledButton(
            onPressed:
                _downloading || widget.service == null ? null : _download,
            child: const Text('下载并安装'),
          ),
      ],
    );
  }

  Future<void> _download() async {
    final service = widget.service;
    if (service == null) return;
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });
    try {
      await service.downloadVerifiedAndLaunch(
        widget.manifest,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) {
        setState(() {
          _downloading = false;
          _launched = true;
        });
      }
    } on UpdateIntegrityException {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载文件校验失败，已删除，请重试';
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败: $e';
        });
      }
    }
  }
}
