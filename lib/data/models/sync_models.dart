import '../database/app_database.dart';

/// Một dòng CSV đã được kiểm tra hợp lệ, sẵn sàng ghi vào DB.
/// Tên danh mục để nguyên; repository sẽ khớp/tạo theo I4.
class SyncImportRow {
  const SyncImportRow({
    required this.date,
    required this.type,
    required this.categoryName,
    required this.amount,
    required this.note,
    required this.isNotable,
  });

  final DateTime date;
  final TxType type;
  final String categoryName;

  /// VNĐ, số nguyên dương (I1).
  final int amount;
  final String note;
  final bool isNotable;
}

/// Kết quả ghi một lô dòng vào DB.
class SyncImportOutcome {
  const SyncImportOutcome({
    required this.batchId,
    required this.importedRows,
    required this.newCategories,
  });

  final int batchId;
  final int importedRows;

  /// Tên các danh mục vừa được tạo mới trong lần sync này.
  final List<String> newCategories;
}
