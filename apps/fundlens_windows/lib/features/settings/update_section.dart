import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../updates/update_checker.dart';
import '../../updates/update_service.dart';
import 'widgets/settings_section_card.dart';

/// Update check wiring. Overridden by the bootstrap with the real app
/// version and a real download directory; tests inject fakes.
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  return const UpdateChecker(manifestUrl: '', currentVersion: '0.0.0-dev');
});

final updateServiceProvider = Provider<UpdateInstaller?>((ref) => null);

/// Manual update check: compares the running version with the published
/// manifest, then downloads, verifies and launches the installer on demand.
/// Nothing here runs on its own — the network is only touched when the user
/// taps 检查更新.
class UpdateSection extends ConsumerStatefulWidget {
  const UpdateSection({super.key});

  @override
  ConsumerState<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<UpdateSection> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checker = ref.watch(updateCheckerProvider);
    return SettingsSectionCard(
      title: '应用更新',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前版本：${checker.currentVersion}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('只在点击按钮时检查更新，不会自动联网',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
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
          _showSnack(message);
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
