import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/default_categories.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/sync_models.dart';
import '../../../data/repositories/sync_repository.dart';
import '../domain/sync_result.dart';

/// Đồng bộ `pending_transactions.csv` vào SQLite.
///
/// Thứ tự bắt buộc (I2): đọc → kiểm tra từng dòng → ghi DB trong một
/// transaction → CHỈ KHI COMMIT thành công mới xóa các dòng đã nhập khỏi file.
/// Dòng lỗi luôn được giữ lại.
class CsvSyncService {
  CsvSyncService(this._repository, {this.maxFileBytes = defaultMaxFileBytes});

  static const defaultMaxFileBytes = 5 * 1024 * 1024;
  static const csvHeader = 'Ngày,Loại,Danh mục,Số tiền,Ghi chú';
  static const maxAmount = 1000000000000; // 1.000 tỷ VNĐ, chặn nhập nhầm.

  final SyncRepository _repository;
  final int maxFileBytes;

  Future<SyncResult> sync(String path) async {
    final file = File(path);
    final text = await _readFile(file);
    final table = _decode(text);

    final parsed = <_ParsedRow>[];
    final errors = <SyncRowError>[];
    var line = 0;
    for (final cells in table) {
      line++;
      final strings = cells.map((c) => c.toString()).toList();
      if (strings.every((c) => c.trim().isEmpty)) continue;
      if (line == 1 && _isHeader(strings)) continue;
      try {
        parsed.add(_ParsedRow(strings, _parseRow(strings)));
      } on FormatException catch (e) {
        errors.add(
          SyncRowError(line: line, message: e.message, cells: strings),
        );
      }
    }

    final totalRows = parsed.length + errors.length;
    if (parsed.isEmpty) {
      return SyncResult(
        totalRows: totalRows,
        importedRows: 0,
        errors: errors,
        newCategories: const [],
      );
    }

    final errorLog = errors.isEmpty
        ? null
        : errors.map((e) => 'Dòng ${e.line}: ${e.message}').join('\n');

    final SyncImportOutcome outcome;
    try {
      outcome = await _repository.importRows(
        parsed.map((p) => p.row).toList(),
        totalRows: totalRows,
        errorLog: errorLog,
      );
    } catch (_) {
      // Đã rollback; file CSV chưa bị đụng tới.
      throw const SyncException(
        'Không thể lưu dữ liệu vào cơ sở dữ liệu. '
        'File CSV vẫn được giữ nguyên, hãy thử đồng bộ lại.',
      );
    }

    String? warning;
    try {
      await _removeImportedRows(file, parsed.map((p) => p.cells).toList());
    } on FileSystemException {
      warning =
          'Đã lưu ${outcome.importedRows} giao dịch nhưng không dọn được file '
          'CSV (có thể đang bị khóa). Đừng đồng bộ lại để tránh trùng; hãy xóa '
          'các dòng đã nhập trong file thủ công.';
    }

    return SyncResult(
      totalRows: totalRows,
      importedRows: outcome.importedRows,
      errors: errors,
      newCategories: outcome.newCategories,
      batchId: outcome.batchId,
      cleanupWarning: warning,
    );
  }

  // ------------------------------------------------------------ Đọc file

  Future<String> _readFile(File file) async {
    try {
      if (!await file.exists()) {
        throw const SyncException(
          'Không tìm thấy file CSV. Hãy chọn lại đường dẫn file.',
        );
      }
      if (await file.length() > maxFileBytes) {
        throw SyncException(
          'File CSV quá lớn (trên ${maxFileBytes ~/ (1024 * 1024)} MB). '
          'Hãy kiểm tra lại file.',
        );
      }
      return _decodeUtf8(await file.readAsBytes());
    } on FileSystemException {
      throw const SyncException(
        'Không đọc được file CSV. File có thể đang được mở hoặc bị khóa '
        'bởi ứng dụng khác, hãy đóng nó rồi thử lại.',
      );
    }
  }

  static String _decodeUtf8(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      return text.startsWith('﻿') ? text.substring(1) : text;
    } on FormatException {
      throw const SyncException(
        'File CSV không đúng mã hóa UTF-8. Hãy lưu lại file với '
        'bảng mã UTF-8 rồi đồng bộ lại.',
      );
    }
  }

  /// Tách dòng/cột. Hỗ trợ dấu phân cách `,` (mặc định) hoặc `;` (Excel VN).
  static List<List<dynamic>> _decode(String text) {
    final firstLine = text.split(RegExp(r'\r\n|\r|\n')).first;
    final semicolon = firstLine.contains(';') && !firstLine.contains(',');
    return Csv(
      fieldDelimiter: semicolon ? ';' : ',',
      autoDetect: false,
      skipEmptyLines: false,
    ).decode(text);
  }

  static bool _isHeader(List<String> cells) {
    final first = cells.first.trim().toLowerCase();
    return first == 'ngày' || first == 'ngay' || first == 'date';
  }

  // --------------------------------------------------------- Parse dòng

  static SyncImportRow _parseRow(List<String> cells) {
    if (cells.length < 4) {
      throw const FormatException(
        'Thiếu cột (cần: Ngày, Loại, Danh mục, Số tiền, Ghi chú)',
      );
    }
    final date = parseDate(cells[0]);
    final type = parseType(cells[1]);
    final category = cells[2].trim();
    final amount = parseAmount(cells[3]);
    // Ghi chú chứa dấu phẩy mà không đặt trong ngoặc kép sẽ bị tách cột: nối lại.
    final rawNote = cells.length > 4 ? cells.sublist(4).join(',') : '';
    final note = parseNote(rawNote);

    final byAmount =
        type == TxType.expense &&
        amount >= notableAmountThreshold &&
        note.text.isNotEmpty;

    return SyncImportRow(
      date: date,
      type: type,
      categoryName: category,
      amount: amount,
      note: note.text,
      isNotable: note.flagged || byAmount,
    );
  }

  /// `dd/MM/yyyy`, dự phòng `yyyy-MM-dd`. Trả về 00:00 của ngày đó.
  static DateTime parseDate(String raw) {
    final s = raw.trim();
    DateTime? d;
    for (final pattern in const ['dd/MM/yyyy', 'yyyy-MM-dd']) {
      try {
        d = DateFormat(pattern).parseStrict(s);
        break;
      } on FormatException {
        continue;
      }
    }
    if (d == null) {
      throw FormatException('Ngày không hợp lệ: "$s" (cần dd/MM/yyyy)');
    }
    if (d.year < 2000 || d.year > 2100) {
      throw FormatException('Năm ngoài khoảng cho phép: "$s"');
    }
    return DateTime(d.year, d.month, d.day);
  }

  static TxType parseType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'thu' || 'income':
        return TxType.income;
      case 'chi' || 'expense':
        return TxType.expense;
    }
    throw FormatException(
      'Loại không hợp lệ: "${raw.trim()}" (cần Thu hoặc Chi)',
    );
  }

  /// Số tiền nguyên VNĐ. Chấp nhận `1250000`, `1.250.000`, `1,250,000 đ`.
  /// Từ chối số thập phân (`65.5`), số âm, chữ `k`... thay vì đoán sai (I1).
  static int parseAmount(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'(₫|đ|vnd|vnđ)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s'), '');
    final valid =
        RegExp(r'^\d+$').hasMatch(cleaned) ||
        RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(cleaned);
    final value = valid
        ? int.tryParse(cleaned.replaceAll(RegExp(r'[.,]'), ''))
        : null;
    if (value == null) {
      throw FormatException('Số tiền không hợp lệ: "${raw.trim()}"');
    }
    if (value <= 0) throw const FormatException('Số tiền phải lớn hơn 0');
    if (value > maxAmount) {
      throw FormatException('Số tiền quá lớn: "${raw.trim()}"');
    }
    return value;
  }

  /// Ghi chú bắt đầu bằng `*` hoặc `!`, hoặc chứa `#note` → đáng chú ý.
  /// Ký hiệu được cắt đi để hiển thị sạch.
  static ({String text, bool flagged}) parseNote(String raw) {
    var text = raw.trim();
    var flagged = false;
    if (text.startsWith('*') || text.startsWith('!')) {
      flagged = true;
      text = text.replaceFirst(RegExp(r'^[*!\s]+'), '');
    }
    final tag = RegExp('#note', caseSensitive: false);
    if (tag.hasMatch(text)) {
      flagged = true;
      text = text.replaceAll(tag, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return (text: text, flagged: flagged);
  }

  // ------------------------------------------- Dọn file sau khi COMMIT (I2)

  /// Đọc lại file (iPhone có thể vừa thêm dòng mới qua iCloud), bỏ đúng các
  /// dòng đã nhập, giữ header + dòng lỗi + dòng mới phát sinh.
  Future<void> _removeImportedRows(
    File file,
    List<List<String>> imported,
  ) async {
    final pending = <String, int>{};
    for (final cells in imported) {
      pending.update(_key(cells), (n) => n + 1, ifAbsent: () => 1);
    }

    final current = _decode(_decodeUtf8(await file.readAsBytes()));
    final kept = <List<String>>[];
    var index = 0;
    for (final raw in current) {
      index++;
      final cells = raw.map((c) => c.toString()).toList();
      if (cells.every((c) => c.trim().isEmpty)) continue;
      if (index == 1 && _isHeader(cells)) continue;
      final k = _key(cells);
      final left = pending[k] ?? 0;
      if (left > 0) {
        pending[k] = left - 1;
        continue;
      }
      kept.add(cells);
    }

    final out = StringBuffer('$csvHeader\n');
    if (kept.isNotEmpty) {
      out.write(Csv(lineDelimiter: '\n').encode(kept));
      out.write('\n');
    }
    // Ghi file tạm rồi đổi tên để không bao giờ để lại file ghi dở.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(out.toString(), flush: true);
    await tmp.rename(file.path);
  }

  static String _key(List<String> cells) =>
      cells.map((c) => c.trim()).join('\u0000');
}

class _ParsedRow {
  _ParsedRow(this.cells, this.row);

  final List<String> cells;
  final SyncImportRow row;
}
