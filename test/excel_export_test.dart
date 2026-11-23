import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/features/excel_export/services/excel_export_service.dart';

void main() {
  late AppDatabase db;
  const service = ExcelExportService();

  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<int> cat(String name, TxType type) =>
      db.categoriesDao.getOrCreateByName(name: name, type: type);

  Future<void> add(
    DateTime date,
    TxType type,
    String category,
    int amount, {
    String note = '',
    bool notable = false,
  }) async {
    await db.transactionsDao.insertTransaction(
      NewTransaction(
        transactionDate: date,
        type: type,
        categoryId: await cat(category, type),
        amount: amount,
        note: note,
        isNotable: notable,
      ),
    );
  }

  Excel decode(List<int> bytes) => Excel.decodeBytes(bytes);

  String text(Sheet s, int col, int row) => s
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value
      .toString();

  test(
    'chia Sheet theo MM-YYYY của transaction_date, không theo created_at',
    () async {
      await add(DateTime(2026, 11, 13), TxType.expense, 'Ăn uống', 65000);
      await add(DateTime(2026, 10, 28), TxType.income, 'Thưởng', 3000000);
      await add(DateTime(2026, 10, 2), TxType.expense, 'Ăn uống', 40000);

      final excel = decode(
        service.build(await db.transactionsDao.getAllForExport()),
      );
      expect(excel.tables.keys.toList(), ['10-2026', '11-2026']);
      expect(excel.tables.containsKey('Sheet1'), isFalse);
    },
  );

  test(
    'số tiền ghi dạng số nguyên, ngày dd/MM/yyyy, sắp xếp tăng dần',
    () async {
      await add(DateTime(2026, 10, 28), TxType.income, 'Thưởng', 3000000);
      await add(DateTime(2026, 10, 2), TxType.expense, 'Ăn uống', 40000);

      final sheet = decode(
        service.build(await db.transactionsDao.getAllForExport()),
      ).tables['10-2026']!;

      expect(text(sheet, 0, 0), 'BÁO CÁO THU CHI THÁNG 10/2026');
      expect(text(sheet, 0, 3), 'STT');
      expect(text(sheet, 1, 4), '02/10/2026');
      expect(text(sheet, 1, 5), '28/10/2026');
      final amount = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4))
          .value;
      expect(amount, isA<IntCellValue>());
      expect((amount as IntCellValue).value, 40000);
    },
  );

  test('dòng tóm tắt đúng Thu - Chi - Dư', () async {
    await add(DateTime(2026, 10, 1), TxType.income, 'Lương', 10000000);
    await add(DateTime(2026, 10, 2), TxType.expense, 'Ăn uống', 2500000);

    final sheet = decode(
      service.build(await db.transactionsDao.getAllForExport()),
    ).tables['10-2026']!;
    final summary = text(sheet, 0, 1);
    expect(summary, contains('10.000.000'));
    expect(summary, contains('2.500.000'));
    expect(summary, contains('7.500.000'));
  });

  test('chống Formula Injection cho Ghi chú và Danh mục', () async {
    await add(
      DateTime(2026, 11, 1),
      TxType.expense,
      '=HYPERLINK("x")',
      1000,
      note: "=CMD|' /C calc'!A0",
    );
    await add(DateTime(2026, 11, 2), TxType.expense, 'Khác', 1000, note: '+1');
    await add(
      DateTime(2026, 11, 3),
      TxType.expense,
      'Khác',
      1000,
      note: '@SUM(1)',
    );
    await add(DateTime(2026, 11, 4), TxType.expense, 'Khác', 1000, note: '-2');

    final sheet = decode(
      service.build(await db.transactionsDao.getAllForExport()),
    ).tables['11-2026']!;
    expect(text(sheet, 3, 4), startsWith("'="));
    expect(text(sheet, 5, 4), startsWith("'="));
    expect(text(sheet, 5, 5), "'+1");
    expect(text(sheet, 5, 6), "'@SUM(1)");
    expect(text(sheet, 5, 7), "'-2");
  });

  test('sanitize xử lý tab, CR và giữ nguyên chuỗi an toàn', () {
    expect(ExcelExportService.sanitize('\tabc'), "'\tabc");
    expect(ExcelExportService.sanitize('\rabc'), "'\rabc");
    expect(ExcelExportService.sanitize('Phở bò'), 'Phở bò');
    expect(ExcelExportService.sanitize(''), '');
  });

  test('đánh dấu giao dịch đáng chú ý', () async {
    await add(
      DateTime(2026, 11, 1),
      TxType.expense,
      'Mua sắm',
      1250000,
      note: 'Bàn phím',
      notable: true,
    );
    final sheet = decode(
      service.build(await db.transactionsDao.getAllForExport()),
    ).tables['11-2026']!;
    expect(text(sheet, 6, 4), '*');
  });

  test('không có giao dịch thì báo lỗi tiếng Việt', () {
    expect(() => service.build(const []), throwsA(isA<ExportException>()));
  });

  test('ghi file ra đĩa', () async {
    await add(DateTime(2026, 11, 1), TxType.expense, 'Ăn uống', 65000);
    final dir = await Directory.systemTemp.createTemp('m0n3y_export');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/report.xlsx';

    await service.exportToFile(
      await db.transactionsDao.getAllForExport(),
      path,
    );
    expect(File(path).existsSync(), isTrue);
    expect(decode(File(path).readAsBytesSync()).tables.keys, ['11-2026']);
  });
}
