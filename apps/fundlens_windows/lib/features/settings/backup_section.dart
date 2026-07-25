import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../backup/backup_cipher.dart';
import '../../backup/backup_format.dart';
import '../../backup/backup_service.dart';
import '../../backup/database_restore_service.dart';
import 'structure_thresholds_section.dart';

/// Backup service used by the settings backup section.
///
/// Null until the app bootstrap wires the live database; the section then
/// shows the controls as unavailable instead of pretending they work.
final backupServiceProvider = Provider<BackupService?>((ref) => null);

/// Restore service used by the settings backup section; see
/// [backupServiceProvider].
final databaseRestoreServiceProvider =
    Provider<DatabaseRestoreService?>((ref) => null);

/// File picker abstraction so tests never touch the OS dialog.
final backupFilePickerProvider =
    Provider<BackupFilePicker>((ref) => const FilePickerBackupFilePicker());

/// Picks backup save/open locations, restricted to the FundLens backup
/// extension.
abstract interface class BackupFilePicker {
  Future<String?> pickBackupSaveLocation();
  Future<String?> pickBackupFile();
}

/// OS-backed picker used by the app bootstrap; tests inject a fake
/// [BackupFilePicker] instead.
///
/// file_picker 3.0.4 has no save-file dialog, so the save flow picks a
/// directory and writes a timestamped default file name into it.
final class FilePickerBackupFilePicker implements BackupFilePicker {
  const FilePickerBackupFilePicker();

  static const _extension = 'fundlens-backup';

  @override
  Future<String?> pickBackupSaveLocation() async {
    final directory = await file_picker.FilePicker.platform.getDirectoryPath();
    if (directory == null) return null;
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
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
    final picked = await ref.read(backupFilePickerProvider).pickBackupSaveLocation();
    if (picked == null) return;
    final destination = picked.endsWith(kFundLensBackupExtension)
        ? picked
        : '$picked$kFundLensBackupExtension';

    setState(() => _busy = true);
    try {
      await service.create(destination, _createPassword.text);
      _setFeedback('备份已创建：$destination', isError: false);
    } on Exception {
      _setFeedback('备份创建失败，请重试。', isError: true);
    } finally {
      _createPassword.clear();
      _createConfirm.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final service = ref.read(databaseRestoreServiceProvider);
    if (service == null || _busy || _restorePassword.text.isEmpty) return;
    final picked = await ref.read(backupFilePickerProvider).pickBackupFile();
    if (picked == null) return;
    if (!mounted) return;

    final fileName = p.basename(picked);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复备份'),
        content: Text(
          '将用备份文件“$fileName”替换当前数据。替换前会在本机保留当前数据的恢复副本。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      _restorePassword.clear();
      return;
    }

    setState(() => _busy = true);
    try {
      await service.restore(picked, _restorePassword.text);
      _setFeedback('恢复完成。', isError: false);
    } on BackupAuthenticationException {
      _setFeedback('备份密码不正确或备份文件已损坏。', isError: true);
    } on BackupFormatException {
      _setFeedback('备份文件已损坏或格式不受支持。', isError: true);
    } on Exception {
      _setFeedback('恢复失败，当前数据未受影响。', isError: true);
    } finally {
      _restorePassword.clear();
      if (mounted) setState(() => _busy = false);
    }
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
          const SizedBox(height: 12),
          if (!available)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '备份功能当前不可用。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('backup-create-password'),
              controller: _createPassword,
              obscureText: true,
              enabled: available && !_busy,
              decoration: const InputDecoration(
                labelText: '备份密码',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('backup-create-confirm'),
              controller: _createConfirm,
              obscureText: true,
              enabled: available && !_busy,
              decoration: InputDecoration(
                labelText: '再次输入备份密码',
                isDense: true,
                errorText: _showMismatch ? '两次输入的密码不一致' : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const ValueKey('backup-create-button'),
            onPressed:
                available && !_busy && _passwordsMatch ? _create : null,
            child: const Text('创建加密备份'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('backup-restore-password'),
              controller: _restorePassword,
              obscureText: true,
              enabled: available && !_busy,
              decoration: const InputDecoration(
                labelText: '备份密码',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('backup-restore-button'),
            onPressed: available && !_busy && _restorePassword.text.isNotEmpty
                ? _restore
                : null,
            child: const Text('选择备份文件并恢复'),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
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
}
