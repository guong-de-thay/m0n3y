import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/year_month.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/transaction_models.dart';

/// Lỗi báo thẳng cho người dùng bằng tiếng Việt.
class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Xuất giao dịch ra `.xlsx`, mỗi tháng một Sheet tên `MM-YYYY`.
///
/// Gom nhóm theo `transaction_date` (I3), không theo `created_at`. Số tiền
/// ghi dạng số nguyên (I1) để Excel `SUM` được ngay.
class ExcelExportService {
  const ExcelExportService();

  static const headers = [
    'STT',
    'Ngày',
    'Loại',
    'Danh mục',
    'Số tiền (VNĐ)',
    'Ghi chú',
    'Đáng chú ý',
  ];

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _moneyFormat = NumberFormat.decimalPattern('vi_VN');

  /// Chống CSV/Excel Formula Injection: chuỗi bắt đầu bằng `= + - @ \t \r`
  /// được thêm `'` ở đầu.
  static String sanitize(String value) {
    if (value.isEmpty) return value;
    const triggers = ['=', '+', '-', '@', '\t', '\r'];
    return triggers.contains(value[0]) ? "'$value" : value;
  }

  /// Tên Sheet `MM-YYYY` từ `year_month` dạng `YYYY-MM`.
  static String sheetNameOf(DateTime date) {
    final ym = yearMonthOf(date); // YYYY-MM
    return '${ym.substring(5)}-${ym.substring(0, 4)}';
  }

  /// Dựng nội dung file. Danh sách rỗng → ném [ExportException].
  List<int> build(List<TransactionWithCategory> items) {
    if (items.isEmpty) {
      throw const ExportException('Chưa có giao dịch nào để xuất.');
    }

    final sorted = [...items]
      ..sort((a, b) {
        final c = a.transaction.transactionDate.compareTo(
          b.transaction.transactionDate,
        );
        return c != 0 ? c : a.transaction.id.compareTo(b.transaction.id);
      });

    // Map giữ thứ tự chèn nên các Sheet đi từ tháng cũ đến tháng mới.
    final byMonth = <String, List<TransactionWithCategory>>{};
    for (final t in sorted) {
      byMonth
          .putIfAbsent(sheetNameOf(t.transaction.transactionDate), () => [])
          .add(t);
    }

    final excel = Excel.createExcel();
    final bold = CellStyle(bold: true);

    for (final entry in byMonth.entries) {
      final name = entry.key;
      final list = entry.value;
      final sheet = excel[name];

      var income = 0;
      var expense = 0;
      for (final t in list) {
        if (t.transaction.type == TxType.income) {
          income += t.transaction.amount;
        } else {
          expense += t.transaction.amount;
        }
      }

      final title = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
      title.value = TextCellValue(
        'BÁO CÁO THU CHI THÁNG ${name.replaceFirst('-', '/')}',
      );
      title.cellStyle = bold;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = TextCellValue(
        'Tổng Thu: ${_money(income)} VNĐ | Tổng Chi: ${_money(expense)} VNĐ'
        ' | Chênh lệch (Dư): ${_money(income - expense)} VNĐ',
      );

      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3),
        );
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = bold;
      }

      for (var i = 0; i < list.length; i++) {
        final t = list[i];
        final tx = t.transaction;
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(_dateFormat.format(tx.transactionDate)),
          TextCellValue(tx.type == TxType.income ? 'Thu' : 'Chi'),
          TextCellValue(sanitize(t.category.name)),
          IntCellValue(tx.amount),
          TextCellValue(sanitize(tx.note)),
          TextCellValue(tx.isNotable ? '*' : ''),
        ]);
      }
    }

    // Xóa Sheet mặc định nếu thừa (không trùng tên tháng nào).
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null && !byMonth.containsKey(defaultName)) {
      excel.delete(defaultName);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw const ExportException('Không tạo được nội dung file Excel.');
    }
    return bytes;
  }

  /// Ghi ra [path]. Bắt lỗi file đang mở/bị khóa thay vì để app crash.
  Future<void> exportToFile(
    List<TransactionWithCategory> items,
    String path,
  ) async {
    final bytes = build(items);
    try {
      await File(path).writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      throw const ExportException(
        'Không ghi được file Excel. File có thể đang được mở trong Excel '
        'hoặc thư mục không cho phép ghi, hãy đóng file rồi thử lại.',
      );
    }
  }

  static String _money(int v) => _moneyFormat.format(v);
}
