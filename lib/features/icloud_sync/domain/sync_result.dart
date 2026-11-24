/// Một dòng CSV bị từ chối, được giữ lại trong file để người dùng sửa (I2).
class SyncRowError {
  const SyncRowError({
    required this.line,
    required this.message,
    required this.cells,
  });

  /// Số dòng trong file (đếm từ 1, tính cả header).
  final int line;
  final String message;
  final List<String> cells;
}

/// Kết quả một lần đồng bộ CSV.
class SyncResult {
  const SyncResult({
    required this.totalRows,
    required this.importedRows,
    required this.errors,
    required this.newCategories,
    this.batchId,
    this.cleanupWarning,
  });

  /// Số dòng dữ liệu đọc được (không tính header, dòng trống).
  final int totalRows;
  final int importedRows;
  final List<SyncRowError> errors;
  final List<String> newCategories;
  final int? batchId;

  /// Có giá trị khi đã ghi DB xong nhưng không dọn được file CSV.
  final String? cleanupWarning;

  bool get hasErrors => errors.isNotEmpty;
}

/// Lỗi có thể báo thẳng cho người dùng bằng tiếng Việt, không làm app crash.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
