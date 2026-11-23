import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/repositories/sync_repository.dart';
import 'package:m0n3y/features/excel_export/services/excel_export_service.dart';
import 'package:m0n3y/features/icloud_sync/services/csv_sync_service.dart';

/// Kịch bản nghiệm thu phần Dev (REQUIREMENTS.md mục 6): Sync bộ dữ liệu của
/// khách hàng (lùi ngày, danh mục mới, ghi chú `*`, một dòng sai số tiền,
/// công thức độc hại) rồi Export Excel.
void main() {
  late AppDatabase db;
  late Directory dir;
  late File csv;

  setUp(() async {
    db = AppDatabase.inMemory();
    dir = await Directory.systemTemp.createTemp('m0n3y_accept_');
    // Sync xóa dòng đã nhập, nên làm việc trên bản sao của fixture.
    csv = await File('test/fixtures/pending_transactions_nghiem_thu.csv')
        .copy('${dir.path}/pending_transactions.csv');
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'Sync rồi Export: đủ dữ liệu, giữ dòng lỗi, đúng Sheet, an toàn',
    () async {
      final result = await CsvSyncService(SyncRepository(db)).sync(csv.path);

      // Nhập 5/6 dòng; dòng sai số tiền bị giữ lại, không làm hỏng cả lô.
      expect(result.totalRows, 6);
      expect(result.importedRows, 5);
      expect(result.errors.single.line, 6);
      expect(result.newCategories, ['Thú cưng']);

      // I2: chỉ còn header + đúng dòng lỗi; dòng đã nhập đã bị xóa.
      final left = await csv.readAsString();
      expect(left, contains('abc'));
      expect(left, isNot(contains('Phở bò')));
      expect(left, isNot(contains('Thưởng dự án')));

      // I3: lùi ngày về tháng trước vẫn thuộc đúng tháng của transaction_date.
      final items = await db.transactionsDao.getAllForExport();
      expect(items.length, 5);
      expect(items.map((e) => e.transaction.yearMonth).toSet(), {
        '2026-10',
        '2026-11',
      });
      expect(items.first.transaction.transactionDate, DateTime(2026, 10, 28));

      // I1: tiền là int, tổng tháng 11 = 65.000 + 1.250.000 + 180.000 + 50.000.
      final nov = await db.transactionsDao.watchMonthTotals('2026-11').first;
      expect(nov.expense, 1545000);
      expect(nov.income, 0);
      final series = await db.transactionsDao
          .watchMonthlySeries('2026-10', '2026-11')
          .first;
      expect(series.map((e) => e.income), [3000000, 0]);
      expect(series.map((e) => e.expense), [0, 1545000]);

      // Quy tắc nghiệp vụ #4: ghi chú gắn `*` vào Visual Notes, đã bỏ dấu `*`.
      final notes = await db.transactionsDao.watchVisualNotes('2026-11').first;
      expect(notes.length, 1);
      expect(notes.single.transaction.note, startsWith('Mua bàn phím cơ'));
      expect(notes.single.transaction.isNotable, isTrue);

      // Export: mỗi tháng một Sheet MM-YYYY, tiền là số, công thức bị vô hiệu.
      final excel = Excel.decodeBytes(const ExcelExportService().build(items));
      expect(excel.tables.keys.toList(), ['10-2026', '11-2026']);
      expect(excel.tables.containsKey('Sheet1'), isFalse);

      final cells = excel.tables['11-2026']!.rows
          .expand((r) => r)
          .whereType<Data>()
          .toList();
      expect(
        cells.any((c) => c.value.toString() == "'=SUM(A1)"),
        isTrue,
        reason: 'Ghi chú bắt đầu bằng "=" phải được thêm dấu nháy đơn',
      );
      expect(
        cells.any(
          (c) =>
              c.value is IntCellValue &&
              (c.value as IntCellValue).value == 1250000,
        ),
        isTrue,
        reason: 'Số tiền phải là ô số để Excel SUM được',
      );
    },
  );
}
