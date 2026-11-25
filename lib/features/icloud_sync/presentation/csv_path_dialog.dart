import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/providers/data_providers.dart';
import '../providers/sync_controller.dart';

/// Mở hộp thoại xem / đổi / bỏ đường dẫn file `pending_transactions.csv`.
Future<void> showCsvPathDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const CsvPathDialog(),
  );
}

/// Lần Sync đầu tiên app tự hỏi file rồi nhớ đường dẫn; hộp thoại này cho
/// người dùng xem app đang đọc file nào và đổi sang file khác khi cần.
/// Đường dẫn chỉ lưu cục bộ qua `SettingsRepository`, không hard-code.
class CsvPathDialog extends ConsumerStatefulWidget {
  const CsvPathDialog({super.key});

  @override
  ConsumerState<CsvPathDialog> createState() => _CsvPathDialogState();
}

class _CsvPathDialogState extends ConsumerState<CsvPathDialog> {
  String? _path;
  bool _fileExists = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setPath(ref.read(settingsRepositoryProvider).csvPath);
  }

  void _setPath(String? path) {
    _path = (path == null || path.isEmpty) ? null : path;
    _fileExists = _path != null && File(_path!).existsSync();
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(pickCsvDialogProvider)();
      if (picked == null || picked.isEmpty) return; // Người dùng hủy chọn.
      await ref.read(settingsRepositoryProvider).setCsvPath(picked);
      if (mounted) setState(() => _setPath(picked));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không mở được hộp chọn file. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearPath() async {
    await ref.read(settingsRepositoryProvider).clearCsvPath();
    if (mounted) setState(() => _setPath(null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = _path;

    return AlertDialog(
      title: const Text('Cấu hình file CSV iCloud'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nút "Sync iCloud CSV" đọc file pending_transactions.csv trong '
              'thư mục iCloud Drive mà bạn chọn. Đường dẫn chỉ lưu trên máy này.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    path == null
                        ? Icons.help_outline
                        : Icons.insert_drive_file_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path ?? 'Chưa chọn file. Lần đồng bộ tới app sẽ hỏi chọn file.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: path == null ? null : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (path != null && !_fileExists) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Không tìm thấy file ở đường dẫn này. Hãy chọn lại file.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: path == null || _busy ? null : _clearPath,
          child: const Text('Bỏ đường dẫn'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickFile,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Chọn file…'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
