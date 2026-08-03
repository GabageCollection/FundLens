import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/app_dependencies.dart';
import '../../backup/backup_cipher.dart';
import '../../backup/backup_format.dart';
import '../../backup/backup_service.dart';
import '../../backup/database_restore_service.dart';
import '../../backup/password_strength.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/confirm_dialog.dart';
import 'persisted_settings.dart';
import 'widgets/setting_info_row.dart';
import 'widgets/settings_section_card.dart';

/// Backup service used by the settings backup section.
///
/// Null until the app bootstrap wires the live database; the section then
/// shows the controls as unavailable instead of pretending they work.
final backupServiceProvider = Provider<BackupService?>((ref) => null);

/// Restore service used by the settings backup section; see
/// [backupServiceProvider].
final databaseRestoreServiceProvider = Provider<DatabaseRestoreService?>(
  (ref) => null,
);

/// File picker abstraction so tests never touch the OS dialog.
final backupFilePickerProvider = Provider<BackupFilePicker>(
  (ref) => const FilePickerBackupFilePicker(),
);

/// File system used for backup metadata checks (file size). Injectable so
/// widget tests never touch the OS disk.
final backupFileSystemProvider = Provider<BackupFileSystem>(
  (ref) => const IoBackupFileSystem(),
);

/// Picks backup save/open locations, restricted to the FundLens backup
/// extension.
abstract interface class BackupFilePicker {
  Future<String?> pickBackupSaveLocation();
  Future<String?> pickBackupFile();
}

/// OS-backed picker used by the app bootstrap; tests inject a fake
/// [BackupFilePicker] instead.
///
/// The save flow picks a directory and writes a timestamped default file
/// name into it.
final class FilePickerBackupFilePicker implements BackupFilePicker {
  const FilePickerBackupFilePicker();

  static const _extension = 'fundlens-backup';

  @override
  Future<String?> pickBackupSaveLocation() async {
    final directory = await file_picker.FilePicker.platform.getDirectoryPath();
    if (directory == null) return null;
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return p.join(directory, 'fundlens-$stamp$kFundLensBackupExtension');
  }

  @override
  Future<String?> pickBackupFile() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const [_extension],
    );
    return result?.files.single.path;
  }
}

/// Encrypted backup controls: create a password-protected backup and restore
/// from one. Passwords live only in the text controllers and are cleared as
/// soon as an operation completes, fails or is cancelled.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  final _createPassword = TextEditingController();
  final _createConfirm = TextEditingController();
  final _restorePassword = TextEditingController();

  var _busy = false;
  String? _feedback;
  var _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _createPassword,
      _createConfirm,
      _restorePassword,
    ]) {
      controller.addListener(_onPasswordChanged);
    }
  }

  @override
  void dispose() {
    _createPassword.dispose();
    _createConfirm.dispose();
    _restorePassword.dispose();
    super.dispose();
  }

  void _onPasswordChanged() => setState(() {});

  bool get _passwordsMatch =>
      _createPassword.text.isNotEmpty &&
      _createPassword.text == _createConfirm.text;

  bool get _showMismatch =>
      _createConfirm.text.isNotEmpty &&
      _createPassword.text != _createConfirm.text;

  Future<void> _create() async {
    final service = ref.read(backupServiceProvider);
    if (service == null || _busy || !_passwordsMatch) return;
    final picked = await ref
        .read(backupFilePickerProvider)
        .pickBackupSaveLocation();
    if (picked == null) return;
    final destination = picked.endsWith(kFundLensBackupExtension)
        ? picked
        : '$picked$kFundLensBackupExtension';

    setState(() => _busy = true);
    try {
      await service.create(destination, _createPassword.text);
      await _recordBackupInfo(destination);
      _setFeedback('备份已创建：$destination', isError: false);
    } on Exception {
      _setFeedback('备份创建失败，请重试。', isError: true);
    } finally {
      _createPassword.clear();
      _createConfirm.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Records the just-created backup's metadata into memory and the setting
  /// table. The size is re-statted so the shown value matches the real file.
  Future<void> _recordBackupInfo(String destination) async {
    final atUtc = DateTime.now().toUtc();
    final int size;
    try {
      size = await ref.read(backupFileSystemProvider).fileSize(destination);
    } on Exception {
      return; // The test filesystem may not expose the created file.
    }
    ref.read(lastBackupInfoProvider.notifier).state =
        (path: destination, at: atUtc, bytes: size);
    await persistSetting(
      ref.container,
      SettingKeys.backupLastPath,
      destination,
    );
    await persistSetting(
      ref.container,
      SettingKeys.backupLastCreatedAtUtc,
      atUtc.toIso8601String(),
    );
    await persistSetting(
      ref.container,
      SettingKeys.backupLastFileSizeBytes,
      '$size',
    );
  }

  Future<void> _restore() async {
    final service = ref.read(databaseRestoreServiceProvider);
    if (service == null || _busy || _restorePassword.text.isEmpty) return;
    final picked = await ref.read(backupFilePickerProvider).pickBackupFile();
    if (picked == null) return;
    if (!mounted) return;

    // Step 1: authenticate and inspect the backup without touching the live
    // database. The password is consumed here and never persisted.
    final password = _restorePassword.text;
    setState(() => _busy = true);
    RestoreSession? session;
    try {
      session = await service.prepareRestore(picked, password);
    } on BackupAuthenticationException {
      _setFeedback('备份密码不正确或备份文件已损坏。', isError: true);
      return;
    } on BackupFormatException {
      _setFeedback('备份文件已损坏或格式不受支持。', isError: true);
      return;
    } on Exception {
      _setFeedback('恢复失败，当前数据未受影响。', isError: true);
      return;
    } finally {
      // The password was consumed by prepare; never keep it around.
      _restorePassword.clear();
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    final confirmed = await _showRestoreSummary(session);
    if (!mounted) return;
    if (confirmed != true) {
      await service.cancelRestore(session);
      _restorePassword.clear();
      return;
    }

    // Step 2: the user confirmed; swap the staged candidate into place.
    setState(() => _busy = true);
    try {
      await service.confirmRestore(session);
      // The restore closed and reopened the physical database; refresh all
      // database-dependent providers so the UI reflects the restored data.
      ref.read(databaseRevisionProvider.notifier).state++;
      _setFeedback('恢复完成。', isError: false);
    } on Exception {
      _setFeedback('恢复失败，当前数据未受影响。', isError: true);
    } finally {
      _restorePassword.clear();
      if (mounted) setState(() => _busy = false);
    }
    // Reload persisted settings from the restored database. Best-effort: a
    // failure keeps the runtime defaults already in memory.
    await loadPersistedSettings(ref.container);
  }

  /// Confirmation dialog that presents the staged backup's summary before the
  /// live database is touched. Returns true only when the user confirmed.
  Future<bool?> _showRestoreSummary(RestoreSession session) {
    final summary = session.summary;
    return showConfirmDialog(
      context,
      title: '恢复备份',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('备份时间：${_formatDateTime(summary.createdAtUtc.toLocal())}'),
          const SizedBox(height: 8),
          Text(
            '数据摘要：持仓 ${summary.holdingCount} 条'
            ' · 快照 ${summary.snapshotCount} 份',
          ),
          const SizedBox(height: 8),
          const Text('将用该备份替换当前数据。替换前会在本机保留当前数据的恢复副本。'),
        ],
      ),
      confirmLabel: '确认恢复',
      destructive: true,
    );
  }

  void _setFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _feedbackIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backupService = ref.watch(backupServiceProvider);
    final restoreService = ref.watch(databaseRestoreServiceProvider);
    final backupInfo = ref.watch(lastBackupInfoProvider);
    final available = backupService != null && restoreService != null;

    return SettingsSectionCard(
      key: const ValueKey('backup-section'),
      title: '加密备份',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备份使用你设置的密码加密，仅保存在你选择的位置。恢复前会保留当前数据的恢复副本。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: FundLensTokens.space4),
          ..._backupInfoRows(theme, backupInfo),
          const Divider(height: FundLensTokens.space6),
          if (!available)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '备份功能当前不可用。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('backup-create-password'),
              controller: _createPassword,
              obscureText: true,
              enabled: available && !_busy,
              decoration: const InputDecoration(labelText: '备份密码'),
            ),
          ),
          if (_createPassword.text.isNotEmpty) ...[
            const SizedBox(height: FundLensTokens.space2),
            Text(
              '请牢记该密码：一旦遗失，备份将无法恢复。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: FundLensTokens.muted,
              ),
            ),
          ],
          const SizedBox(height: FundLensTokens.formGap),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('backup-create-confirm'),
              controller: _createConfirm,
              obscureText: true,
              enabled: available && !_busy,
              decoration: InputDecoration(
                labelText: '再次输入备份密码',
                errorText: _showMismatch ? '两次输入的密码不一致' : null,
              ),
            ),
          ),
          if (_createPassword.text.isNotEmpty) ...[
            const SizedBox(height: FundLensTokens.space2),
            Text(
              passwordStrengthHint(assessBackupPassword(_createPassword.text)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _strengthColor(
                  assessBackupPassword(_createPassword.text),
                  theme.colorScheme,
                ),
              ),
            ),
          ],
          const SizedBox(height: FundLensTokens.space3),
          FilledButton.tonal(
            key: const ValueKey('backup-create-button'),
            onPressed: available && !_busy && _passwordsMatch ? _create : null,
            child: const Text('创建加密备份'),
          ),
          const SizedBox(height: FundLensTokens.space6),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('backup-restore-password'),
              controller: _restorePassword,
              obscureText: true,
              enabled: available && !_busy,
              decoration: const InputDecoration(labelText: '备份密码'),
            ),
          ),
          const SizedBox(height: FundLensTokens.space3),
          OutlinedButton(
            key: const ValueKey('backup-restore-button'),
            onPressed: available && !_busy && _restorePassword.text.isNotEmpty
                ? _restore
                : null,
            child: const Text('选择备份文件并恢复'),
          ),
          if (_busy) ...[
            const SizedBox(height: FundLensTokens.space3),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('正在处理，请稍候…'),
              ],
            ),
          ],
          if (_feedback != null && !_busy) ...[
            const SizedBox(height: 12),
            Text(
              _feedback!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _feedbackIsError ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _backupInfoRows(
    ThemeData theme,
    ({String path, DateTime at, int bytes})? info,
  ) {
    if (info == null) {
      return const [
        SettingInfoRow(label: '上次备份', value: '尚未创建备份'),
        SettingInfoRow(label: '加密状态', value: 'AES-256-GCM · 已加密'),
        SettingInfoRow(label: '自动备份', value: '手动 · 未启用'),
      ];
    }
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: FundLensTokens.muted,
    );
    return [
      SettingInfoRow(label: '上次备份', value: _formatDateTime(info.at.toLocal())),
      SettingInfoRow(label: '备份位置', value: info.path),
      const SettingInfoRow(label: '加密状态', value: 'AES-256-GCM · 已加密'),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text('文件大小', style: muted)),
            const Expanded(child: _BackupSizeText()),
          ],
        ),
      ),
      const SettingInfoRow(label: '自动备份', value: '手动 · 未启用'),
    ];
  }

  Color _strengthColor(PasswordStrength strength, ColorScheme colors) {
    return switch (strength) {
      PasswordStrength.empty => colors.onSurfaceVariant,
      PasswordStrength.weak => colors.error,
      PasswordStrength.fair => FundLensTokens.warn,
      PasswordStrength.strong => FundLensTokens.profit,
    };
  }
}

/// Reads the recorded backup's real size from disk on the current [path].
///
/// A separate widget so the stat only runs once per path change and the
/// "file lost" state can restyle itself.
class _BackupSizeText extends ConsumerWidget {
  const _BackupSizeText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(lastBackupInfoProvider);
    final files = ref.watch(backupFileSystemProvider);
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: _readSize(info, files),
      builder: (context, snapshot) {
        final text = snapshot.data ?? '正在读取…';
        final lost = text == _kFileLostText;
        return Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: lost ? theme.colorScheme.error : null,
          ),
        );
      },
    );
  }

  static const _kFileLostText = '文件已移动或删除';

  Future<String> _readSize(
    ({String path, DateTime at, int bytes})? info,
    BackupFileSystem files,
  ) async {
    final path = info?.path;
    if (path == null) return _kFileLostText;
    try {
      final bytes = await files.fileSize(path);
      return _formatBytes(bytes);
    } on Exception {
      return _kFileLostText;
    }
  }
}

String _formatDateTime(DateTime local) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
