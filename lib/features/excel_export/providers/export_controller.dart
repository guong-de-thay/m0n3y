import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/data_providers.dart';
import '../services/excel_export_service.dart';

final excelExportServiceProvider = Provider<ExcelExportService>(
  (ref) => const ExcelExportService(),
);

/// Mở hộp thoại lưu file; trả `true` nếu người dùng đã chọn nơi lưu.
/// Tách thành provider để test thay bằng bản giả.
typedef SaveFileDialog = Future<bool> Function(
  String fileName,
  Uint8List bytes,
);

final saveFileDialogProvider = Provider<SaveFileDialog>((ref) {
  return (fileName, bytes) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Lưu báo cáo Excel',
      fileName: fileName,
      bytes: bytes,
    );
    return uri != null;
  };
});

/// Kết quả xuất: `null` khi người dùng bấm hủy ở hộp thoại lưu.
class ExportOutcome {
  const ExportOutcome({required this.fileName, required this.sheetCount});

  final String fileName;
  final int sheetCount;
}

/// Điều khiển nút "Export Excel". State là `AsyncValue<ExportOutcome?>`:
/// `loading` khi đang xuất, `error` mang [ExportException] (tiếng Việt).
class ExportController extends AsyncNotifier<ExportOutcome?> {
  bool _busy = false;

  @override
  Future<ExportOutcome?> build() async => null;

  Future<void> export() async {
    if (_busy) return;
    _busy = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await ref
          .read(transactionRepositoryProvider)
          .getAllForExport();
      final service = ref.read(excelExportServiceProvider);
      final bytes = Uint8List.fromList(service.build(items));
      final now = DateTime.now();
      final fileName =
          'm0n3y_report_${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.xlsx';
      final saved = await ref.read(saveFileDialogProvider)(fileName, bytes);
      if (!saved) return null;
      final sheets = items
          .map(
            (t) =>
                ExcelExportService.sheetNameOf(t.transaction.transactionDate),
          )
          .toSet()
          .length;
      return ExportOutcome(fileName: fileName, sheetCount: sheets);
    });
    _busy = false;
  }
}

final exportControllerProvider =
    AsyncNotifierProvider<ExportController, ExportOutcome?>(
      ExportController.new,
    );
