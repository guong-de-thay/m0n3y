import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/repositories/sync_repository.dart';
import 'package:m0n3y/features/excel_export/services/excel_export_service.dart';
import 'package:m0n3y/features/icloud_sync/domain/sync_result.dart';
import 'package:m0n3y/features/icloud_sync/services/csv_sync_service.dart';

void main() {
  group('QA bộ CSV bẫy — Sync và Export', () {
    late AppDatabase db;
    late Directory tempDir;
    late CsvSyncService syncService;
    const exportService = ExcelExportService();

    setUp(() async {
      db = AppDatabase.inMemory();
      tempDir = await Directory.systemTemp.createTemp('m0n3y_qa_trap_');
      syncService = CsvSyncService(SyncRepository(db));
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<File> copyFixture(String fileName) async {
      final source = File('test/fixtures/$fileName');
      expect(
        await source.exists(),
        isTrue,
        reason: 'Thiếu file fixture $fileName',
      );
      final target = File('${tempDir.path}/$fileName');
      await source.copy(target.path);
      return target;
    }

    test('file bẫy tổng hợp: nhập đủ dòng hợp lệ, giữ dòng lỗi (I1-I4) và chống Formula Injection', () async {
      final csvFile = await copyFixture(
        'pending_transactions_bay_tong_hop.csv',
      );
      final initialCategoryCount = (await db.categoriesDao.getAll()).length;

      final result = await syncService.sync(csvFile.path);

      // 11 dòng hợp lệ + 9 dòng lỗi = 20 dòng dữ liệu.
      expect(result.totalRows, 20);
      expect(result.importedRows, 11);
      expect(result.errors, hasLength(9));
      expect(result.hasErrors, isTrue);

      // I4: chỉ tạo mới đúng 2 danh mục ("Thú cưng" và "=Quà"), không tạo trùng
      // cho "  ăn uống  ", "ĂN UỐNG", "  thú cưng ".
      expect(result.newCategories, containsAll(['Thú cưng', '=Quà']));
      expect(result.newCategories, hasLength(2));
      final afterCategoryCount = (await db.categoriesDao.getAll()).length;
      expect(afterCategoryCount, initialCategoryCount + 2);

      final rows = await db.transactionsDao.getAllForExport();
      expect(rows, hasLength(11));

      // I1: mọi số tiền lưu trong DB đều là số nguyên dương (IntColumn).
      expect(rows.every((r) => r.transaction.amount > 0), isTrue);

      // I3: 2 dòng tháng 10 (1 backdate dd/MM/yyyy, 1 fallback yyyy-MM-dd)
      // và 9 dòng tháng 11.
      final octRows = rows
          .where((r) => r.transaction.yearMonth == '2026-10')
          .toList();
      final novRows = rows
          .where((r) => r.transaction.yearMonth == '2026-11')
          .toList();
      expect(octRows, hasLength(2));
      expect(novRows, hasLength(9));

      // RFC-4180: ghi chú chứa dấu phẩy và xuống dòng trong ngoặc kép không bị cắt.
      final multilineTx = rows.firstWhere(
        (r) => r.transaction.note.contains('Có xuất hóa đơn'),
      );
      expect(
        multilineTx.transaction.note,
        'Ăn tối, tráng miệng\nCó xuất hóa đơn',
      );

      // Dòng gắn dấu * và >= 500k được đánh dấu isNotable = true, đã bỏ dấu * đầu.
      final chairTx = rows.firstWhere(
        (r) => r.transaction.note.contains('Mua ghế công thái học'),
      );
      expect(chairTx.transaction.isNotable, isTrue);
      expect(chairTx.transaction.note, 'Mua ghế công thái học, bảo hành 2 năm');

      // I2: file CSV sau sync đã bỏ 11 dòng hợp lệ, giữ lại đúng 9 dòng lỗi.
      final remaining = await csvFile.readAsString();
      expect(remaining, isNot(contains('Phở bò buổi sáng')));
      expect(remaining, isNot(contains('Mua cát mèo')));
      expect(remaining, contains('31/02/2026'));
      expect(remaining, contains('khong-phai-ngay'));
      expect(remaining, contains('1.5'));
      expect(remaining, contains('-50000'));
      expect(remaining, contains('abc'));
      expect(remaining, contains('65k'));
      expect(remaining, contains('Chuyển khoản'));

      // Chạy sync lần 2 trên cùng file: không nhập thêm, vẫn báo đủ 9 dòng lỗi.
      final secondRun = await syncService.sync(csvFile.path);
      expect(secondRun.importedRows, 0);
      expect(secondRun.errors, hasLength(9));
      expect(await db.transactionsDao.getAllForExport(), hasLength(11));

      // Bảo mật: xuất Excel phải chia 2 Sheet (10-2026, 11-2026), cột tiền là
      // IntCellValue và mọi chuỗi bắt đầu bằng = + - @ đều được chèn dấu '.
      final bytes = exportService.build(rows);
      final workbook = Excel.decodeBytes(bytes);
      expect(workbook.tables.keys, containsAll(['10-2026', '11-2026']));

      final novSheet = workbook['11-2026'];
      final exportedNotes = <String>[];
      final exportedCategories = <String>[];
      for (var r = 4; r < novSheet.maxRows; r++) {
        final catCell = novSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r),
        );
        final amountCell = novSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r),
        );
        final noteCell = novSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r),
        );
        expect(amountCell.value, isA<IntCellValue>());
        exportedCategories.add(catCell.value.toString());
        exportedNotes.add(noteCell.value.toString());
      }

      expect(exportedCategories, contains("'=Quà"));
      expect(exportedNotes, contains("'=CMD|' /C calc'!A0"));
      expect(exportedNotes, contains("'+SUM(1;2)"));
      expect(exportedNotes, contains("'-1+1"));
      expect(exportedNotes, contains("'@SUM(A1:A5)"));
    });

    test('file có UTF-8 BOM và dấu phân cách chấm phẩy (;): đọc đúng, giữ dòng lỗi', () async {
      final csvFile = await copyFixture(
        'pending_transactions_bay_bom_semicolon.csv',
      );
      final rawBytes = await csvFile.readAsBytes();
      expect(rawBytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);

      final result = await syncService.sync(csvFile.path);
      expect(result.totalRows, 4);
      expect(result.importedRows, 2);
      expect(result.errors, hasLength(2));

      final rows = await db.transactionsDao.getAllForExport();
      expect(rows, hasLength(2));
      expect(
        rows.any(
          (r) =>
              r.category.name == 'Ăn uống' &&
              r.transaction.amount == 75000 &&
              r.transaction.note == 'Cơm tấm sườn bì',
        ),
        isTrue,
      );
      expect(
        rows.any(
          (r) =>
              r.transaction.type == TxType.income &&
              r.transaction.amount == 5000000 &&
              r.transaction.isNotable,
        ),
        isTrue,
      );

      final remaining = await csvFile.readAsString();
      expect(remaining, isNot(contains('Cơm tấm sườn bì')));
      expect(remaining, contains('1.5'));
      expect(remaining, contains('31/02/2026'));
    });

    test('đầu vào hỏng (sai UTF-8 hoặc vượt giới hạn dung lượng) báo lỗi thân thiện, không crash', () async {
      final badUtf8 = File('${tempDir.path}/bad_utf8.csv');
      await badUtf8.writeAsBytes([0xFF, 0xFE, 0x00, 0x80]);

      await expectLater(
        () => syncService.sync(badUtf8.path),
        throwsA(
          isA<SyncException>().having(
            (e) => e.message,
            'message',
            contains('UTF-8'),
          ),
        ),
      );

      final tinyLimitService = CsvSyncService(
        SyncRepository(db),
        maxFileBytes: 16,
      );
      final oversized = File('${tempDir.path}/oversized.csv');
      await oversized.writeAsString(
        'Ngày,Loại,Danh mục,Số tiền,Ghi chú\n24/11/2026,Chi,Ăn uống,50000,Test\n',
      );

      await expectLater(
        () => tinyLimitService.sync(oversized.path),
        throwsA(
          isA<SyncException>().having(
            (e) => e.message,
            'message',
            contains('quá lớn'),
          ),
        ),
      );
    });
  });
}
