import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/sync_result.dart';
import '../providers/sync_controller.dart';

/// Câu tóm tắt một lần đồng bộ, bằng tiếng Việt.
String describeSyncResult(SyncResult r) {
  if (r.totalRows == 0) return 'File CSV không có dòng giao dịch nào.';
  final parts = <String>['Đã nhập ${r.importedRows}/${r.totalRows} dòng'];
  if (r.newCategories.isNotEmpty) {
    parts.add(
      'tạo ${r.newCategories.length} danh mục mới '
      '(${r.newCategories.join(', ')})',
    );
  }
  if (r.hasErrors) {
    parts.add('${r.errors.length} dòng lỗi được giữ lại trong file');
  }
  return parts.join(' · ');
}

/// Thông điệp cho lỗi đồng bộ: [SyncException] đã là tiếng Việt thân thiện,
/// mọi lỗi khác chỉ báo chung (không lộ chi tiết kỹ thuật ra UI).
String describeSyncError(Object error) {
  if (error is SyncException) return error.message;
  return 'Đồng bộ không thành công do lỗi không mong muốn. '
      'File CSV chưa bị thay đổi.';
}

/// Lắng nghe [syncControllerProvider] và báo kết quả/lỗi bằng SnackBar.
/// Đặt bọc ngoài khung ứng dụng, bên dưới `MaterialApp`.
class SyncFeedbackListener extends ConsumerWidget {
  const SyncFeedbackListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<SyncResult?>>(syncControllerProvider, (_, next) {
      if (next.isLoading) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      if (next.hasError) {
        _show(messenger, describeSyncError(next.error!), isError: true);
        return;
      }
      final result = next.value;
      if (result == null) return; // Người dùng hủy chọn file.
      _showResult(context, messenger, result);
    });
    return child;
  }

  void _showResult(
    BuildContext context,
    ScaffoldMessengerState messenger,
    SyncResult result,
  ) {
    final warning = result.cleanupWarning;
    final text = warning == null
        ? describeSyncResult(result)
        : '${describeSyncResult(result)}\n$warning';
    final needsAttention = result.hasErrors || warning != null;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: Duration(seconds: needsAttention ? 10 : 5),
          action: result.hasErrors
              ? SnackBarAction(
                  label: 'Xem chi tiết',
                  onPressed: () => showSyncErrorsDialog(context, result.errors),
                )
              : null,
        ),
      );
  }

  void _show(
    ScaffoldMessengerState messenger,
    String text, {
    required bool isError,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 8),
          backgroundColor: isError ? const Color(0xFFB3261E) : null,
        ),
      );
  }
}

/// Danh sách các dòng CSV bị từ chối (vẫn còn trong file để sửa và sync lại).
Future<void> showSyncErrorsDialog(
  BuildContext context,
  List<SyncRowError> errors,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${errors.length} dòng chưa nhập được'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Các dòng này vẫn nằm trong file CSV. Hãy sửa rồi bấm Sync lại.',
            ),
            const SizedBox(height: 12),
            for (final e in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Dòng ${e.line}: ${e.message}'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
