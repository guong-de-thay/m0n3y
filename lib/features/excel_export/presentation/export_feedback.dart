import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/export_controller.dart';
import '../services/excel_export_service.dart';

/// Câu báo kết quả xuất Excel, bằng tiếng Việt.
String describeExportOutcome(ExportOutcome o) =>
    'Đã xuất ${o.fileName} (${o.sheetCount} Sheet theo tháng).';

/// [ExportException] đã là tiếng Việt thân thiện; lỗi khác chỉ báo chung.
String describeExportError(Object error) {
  if (error is ExportException) return error.message;
  return 'Xuất Excel không thành công do lỗi không mong muốn.';
}

/// Lắng nghe [exportControllerProvider] và báo kết quả/lỗi bằng SnackBar.
/// Đặt bọc ngoài khung ứng dụng, bên dưới `MaterialApp`.
class ExportFeedbackListener extends ConsumerWidget {
  const ExportFeedbackListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<ExportOutcome?>>(exportControllerProvider, (_, next) {
      if (next.isLoading) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final String text;
      var isError = false;
      if (next.hasError) {
        text = describeExportError(next.error!);
        isError = true;
      } else if (next.value != null) {
        text = describeExportOutcome(next.value!);
      } else {
        return; // Người dùng hủy hộp thoại lưu.
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            duration: Duration(seconds: isError ? 8 : 5),
            backgroundColor: isError ? const Color(0xFFB3261E) : null,
          ),
        );
    });
    return child;
  }
}
