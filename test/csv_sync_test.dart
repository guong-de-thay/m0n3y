import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/sync_models.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/repositories/sync_repository.dart';
import 'package:m0n3y/features/icloud_sync/domain/sync_result.dart';
import 'package:m0n3y/features/icloud_sync/services/csv_sync_service.dart';

/// Repository giả lập DB lỗi giữa chừng (để kiểm tra I2).
class _FailingRepository extends SyncRepository {
  _FailingRepository(super.db);

  @override
  Future<SyncImportOutcome> importRows(
    List<SyncImportRow> rows, {
    required int totalRows,
    String? errorLog,
  }) => throw StateError('DB lỗi');
}

/// Repository giả lập iPhone ghi thêm dòng vào file ngay lúc đang sync.
class _AppendingRepository extends SyncRepository {
  _AppendingRepository(super.db, this.file, this.extra);

  final File file;
  final String extra;

  @override
  Future<SyncImportOutcome> importRows(
    List<SyncImportRow> rows, {
    required int totalRows,
    String? errorLog,
  }) async {
    final outcome = await super.importRows(
      rows,
      totalRows: totalRows,
      errorLog: errorLog,
    );
    await file.writeAsString(extra, mode: FileMode.append);
    return outcome;
  }
}

const _header = 'Ngày,Loại,Danh mục,Số tiền,Ghi chú';

void main() {
  late AppDatabase db;
  late Directory dir;
  late File csv;
  late CsvSyncService service;

  setUp(() async {
    db = AppDatabase.inMemory();
    dir = await Directory.systemTemp.createTemp('m0n3y_sync_');
    csv = File('${dir.path}/pending_transactions.csv');
    service = CsvSyncService(SyncRepository(db));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<SyncResult> run(String content) async {
    await csv.writeAsString(content);
    return service.sync(csv.path);
  }

  Future<List<TransactionWithCategory>> all() =>
      db.transactionsDao.getAllForExport();

  group('Đồng bộ thành công', () {
    test('file mẫu của đặc tả: lùi ngày, danh mục mới, file sạch', () async {
      final r = await run(
        '$_header\n'
        '13/11/2026,Chi,Ăn uống,65000,Phở bò buổi sáng\n'
        '10/11/2026,Chi,Mua sắm,1250000,"*Mua bàn phím cơ (nhập bù ngày 10/11)"\n'
        '28/10/2026,Thu,Thú cưng,3000000,Thưởng dự án tháng 10 nhập muộn\n',
      );

      expect(r.totalRows, 3);
      expect(r.importedRows, 3);
      expect(r.hasErrors, isFalse);
      expect(r.newCategories, ['Thú cưng']);

      final rows = await all();
      expect(rows.length, 3);
      // I3: theo transaction_date (sắp tăng dần), không theo ngày sync.
      expect(rows.first.transaction.yearMonth, '2026-10');
      expect(rows.first.transaction.transactionDate, DateTime(2026, 10, 28));
      expect(rows.last.transaction.transactionDate, DateTime(2026, 11, 13));
      expect(
        rows.every((e) => e.transaction.source == TxSource.icloudCsv),
        isTrue,
      );

      // Sau COMMIT file chỉ còn header.
      expect(await csv.readAsString(), '$_header\n');
    });

    test('ghi bản ghi sync_batches đúng số liệu', () async {
      final r = await run(
        '$_header\n13/11/2026,Chi,Ăn uống,65000,a\n99/99/2026,Chi,Ăn uống,1,b\n',
      );
      final batches = await db.select(db.syncBatches).get();
      expect(batches.length, 1);
      expect(batches.single.id, r.batchId);
      expect(batches.single.totalRows, 2);
      expect(batches.single.importedRows, 1);
      expect(batches.single.status, SyncStatus.partial);
      expect(batches.single.errorLog, contains('Dòng 3'));
    });

    test('chạy lần hai không nhập trùng', () async {
      await run('$_header\n13/11/2026,Chi,Ăn uống,65000,a\n');
      final again = await service.sync(csv.path);
      expect(again.totalRows, 0);
      expect((await all()).length, 1);
    });

    test('không bắt buộc có header, hỗ trợ BOM', () async {
      await csv.writeAsBytes([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('13/11/2026,Chi,Ăn uống,65000,a\n'),
      ]);
      final r = await service.sync(csv.path);
      expect(r.importedRows, 1);
    });

    test('hỗ trợ dấu phân cách ; (Excel tiếng Việt)', () async {
      final r = await run(
        'Ngày;Loại;Danh mục;Số tiền;Ghi chú\n13/11/2026;Chi;Ăn uống;65000;a\n',
      );
      expect(r.importedRows, 1);
    });

    test('ghi chú có dấu phẩy không đặt trong ngoặc kép vẫn đủ', () async {
      await run('$_header\n13/11/2026,Chi,Ăn uống,65000,cơm, canh, rau\n');
      expect((await all()).single.transaction.note, 'cơm, canh, rau');
    });

    test('ngày dự phòng yyyy-MM-dd', () async {
      await run('$_header\n2026-11-13,Chi,Ăn uống,65000,a\n');
      expect(
        (await all()).single.transaction.transactionDate,
        DateTime(2026, 11, 13),
      );
    });
  });

  group('I4 - danh mục', () {
    test(
      'khớp danh mục có sẵn không phân biệt hoa/thường, không tạo trùng',
      () async {
        final before = (await db.categoriesDao.getAll()).length;
        final r = await run(
          '$_header\n'
          '13/11/2026,Chi,  ĂN UỐNG ,1000,a\n'
          '13/11/2026,Chi,ăn uống,2000,b\n',
        );
        expect(r.newCategories, isEmpty);
        expect((await db.categoriesDao.getAll()).length, before);
      },
    );

    test('tên mới viết khác hoa/thường chỉ tạo một lần', () async {
      final r = await run(
        '$_header\n'
        '13/11/2026,Chi,Thú cưng,1000,a\n'
        '13/11/2026,Chi,THÚ CƯNG,2000,b\n',
      );
      expect(r.newCategories, ['Thú cưng']);
    });

    test('cùng tên nhưng khác loại là hai danh mục khác nhau', () async {
      final r = await run(
        '$_header\n'
        '13/11/2026,Chi,Quà tặng,1000,a\n'
        '13/11/2026,Thu,Quà tặng,2000,b\n',
      );
      expect(r.newCategories.length, 2);
    });

    test('danh mục trống rơi vào "Khác"', () async {
      await run('$_header\n13/11/2026,Chi,,1000,a\n');
      expect((await all()).single.category.name, 'Khác');
    });
  });

  group('I2 - xóa dòng chỉ sau COMMIT, giữ dòng lỗi', () {
    test('DB lỗi → rollback, file CSV giữ nguyên từng byte', () async {
      const content = '$_header\n13/11/2026,Chi,Ăn uống,65000,a\n';
      await csv.writeAsString(content);
      final failing = CsvSyncService(_FailingRepository(db));

      await expectLater(failing.sync(csv.path), throwsA(isA<SyncException>()));
      expect(await csv.readAsString(), content);
      expect((await all()), isEmpty);
    });

    test(
      'giao dịch hỏng giữa lô → rollback toàn bộ, không có dòng nào vào DB',
      () async {
        final repo = SyncRepository(db);
        final rows = [
          SyncImportRow(
            date: DateTime(2026, 11, 13),
            type: TxType.expense,
            categoryName: 'Mới',
            amount: 1000,
            note: '',
            isNotable: false,
          ),
          SyncImportRow(
            date: DateTime(2026, 11, 13),
            type: TxType.expense,
            categoryName: 'Mới',
            amount: 0, // DAO từ chối → ném lỗi
            note: '',
            isNotable: false,
          ),
        ];
        await expectLater(
          repo.importRows(rows, totalRows: 2),
          throwsArgumentError,
        );
        expect(await all(), isEmpty);
        expect(await db.select(db.syncBatches).get(), isEmpty);
        expect(
          await db.categoriesDao.findByName('Mới', TxType.expense),
          isNull,
        );
      },
    );

    test('dòng lỗi được giữ nguyên, dòng đúng được nhập', () async {
      final r = await run(
        '$_header\n'
        '13/11/2026,Chi,Ăn uống,65000,ok\n'
        '31/02/2026,Chi,Ăn uống,1000,ngày sai\n'
        '13/11/2026,Chi,Ăn uống,abc,tiền sai\n'
        '13/11/2026,Khác,Ăn uống,1000,loại sai\n',
      );
      expect(r.importedRows, 1);
      expect(r.errors.map((e) => e.line), [3, 4, 5]);
      expect(
        await csv.readAsString(),
        '$_header\n'
        '31/02/2026,Chi,Ăn uống,1000,ngày sai\n'
        '13/11/2026,Chi,Ăn uống,abc,tiền sai\n'
        '13/11/2026,Khác,Ăn uống,1000,loại sai\n',
      );
    });

    test('toàn bộ dòng lỗi → không ghi DB, file không đổi', () async {
      const content = '$_header\nxx,Chi,Ăn uống,1000,a\n';
      final r = await run(content);
      expect(r.importedRows, 0);
      expect(r.batchId, isNull);
      expect(await csv.readAsString(), content);
      expect(await db.select(db.syncBatches).get(), isEmpty);
    });

    test('dòng iPhone thêm vào giữa lúc sync không bị mất', () async {
      await csv.writeAsString('$_header\n13/11/2026,Chi,Ăn uống,65000,a\n');
      final s = CsvSyncService(
        _AppendingRepository(db, csv, '14/11/2026,Chi,Ăn uống,1000,mới\n'),
      );
      await s.sync(csv.path);
      expect(
        await csv.readAsString(),
        '$_header\n14/11/2026,Chi,Ăn uống,1000,mới\n',
      );
    });

    test('hai dòng giống hệt nhau đều được nhập và đều bị xóa', () async {
      final r = await run(
        '$_header\n'
        '13/11/2026,Chi,Ăn uống,65000,cà phê\n'
        '13/11/2026,Chi,Ăn uống,65000,cà phê\n',
      );
      expect(r.importedRows, 2);
      expect(await csv.readAsString(), '$_header\n');
    });
  });

  group('Đáng chú ý (is_notable)', () {
    test('tiền tố * hoặc !, hoặc #note → notable và được làm sạch', () async {
      await run(
        '$_header\n'
        '01/11/2026,Chi,Ăn uống,1000,*  mua đồ\n'
        '02/11/2026,Chi,Ăn uống,1000,! gấp\n'
        '03/11/2026,Chi,Ăn uống,1000,ăn tối #note\n'
        '04/11/2026,Chi,Ăn uống,1000,bình thường\n',
      );
      final r = await all();
      expect(r.map((e) => e.transaction.isNotable), [true, true, true, false]);
      expect(r.map((e) => e.transaction.note), [
        'mua đồ',
        'gấp',
        'ăn tối',
        'bình thường',
      ]);
    });

    test(
      'chi ≥ 500.000 có ghi chú → notable; không ghi chú thì không',
      () async {
        await run(
          '$_header\n'
          '01/11/2026,Chi,Mua sắm,500000,bàn phím\n'
          '02/11/2026,Chi,Mua sắm,500000,\n'
          '03/11/2026,Chi,Mua sắm,499999,bàn phím\n'
          '04/11/2026,Thu,Lương,9000000,lương\n',
        );
        final r = await all();
        expect(r.map((e) => e.transaction.isNotable), [
          true,
          false,
          false,
          false,
        ]);
      },
    );
  });

  group('I1 - số tiền', () {
    test('chấp nhận các cách viết số nguyên VNĐ', () {
      expect(CsvSyncService.parseAmount('1250000'), 1250000);
      expect(CsvSyncService.parseAmount('1.250.000'), 1250000);
      expect(CsvSyncService.parseAmount('1,250,000 đ'), 1250000);
      expect(CsvSyncService.parseAmount(' 65000 ₫ '), 65000);
      expect(CsvSyncService.parseAmount('65.000VNĐ'), 65000);
    });

    test('từ chối số thập phân, âm, 0, chữ, quá lớn', () {
      for (final bad in [
        '65.5',
        '65,5',
        '-1000',
        '0',
        '',
        'abc',
        '10k',
        '1.2.3',
        '99999999999999999999',
        '2000000000000',
      ]) {
        expect(
          () => CsvSyncService.parseAmount(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('số tiền lưu trong DB là int', () async {
      await run('$_header\n13/11/2026,Chi,Ăn uống,1.250.000,a\n');
      expect((await all()).single.transaction.amount, isA<int>());
      expect((await all()).single.transaction.amount, 1250000);
    });
  });

  group('Ngày và loại', () {
    test('ngày không tồn tại / sai định dạng / năm vô lý bị từ chối', () {
      for (final bad in [
        '31/02/2026',
        '2026/11/13',
        'hôm nay',
        '',
        '13/11/26',
        '13/11/1900',
      ]) {
        expect(
          () => CsvSyncService.parseDate(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('loại không phân biệt hoa/thường, nhận Thu/Chi/income/expense', () {
      expect(CsvSyncService.parseType(' THU '), TxType.income);
      expect(CsvSyncService.parseType('income'), TxType.income);
      expect(CsvSyncService.parseType('Chi'), TxType.expense);
      expect(CsvSyncService.parseType('expense'), TxType.expense);
      expect(() => CsvSyncService.parseType('x'), throwsFormatException);
    });

    test('dòng thiếu cột bị đưa vào danh sách lỗi', () async {
      final r = await run('$_header\n13/11/2026,Chi,Ăn uống\n');
      expect(r.errors.single.message, contains('Thiếu cột'));
    });
  });

  group('Lỗi file - báo tiếng Việt, không crash', () {
    test('file không tồn tại', () async {
      await expectLater(
        service.sync('${dir.path}/khong_co.csv'),
        throwsA(
          isA<SyncException>().having(
            (e) => e.message,
            'message',
            contains('Không tìm thấy'),
          ),
        ),
      );
    });

    test('sai mã hóa UTF-8, file không bị đụng', () async {
      final bytes = [0x31, 0x33, 0x2C, 0xFF, 0xFE, 0x2C, 0x80];
      await csv.writeAsBytes(bytes);
      await expectLater(
        service.sync(csv.path),
        throwsA(
          isA<SyncException>().having(
            (e) => e.message,
            'message',
            contains('UTF-8'),
          ),
        ),
      );
      expect(await csv.readAsBytes(), bytes);
    });

    test('file quá lớn bị từ chối trước khi đọc', () async {
      await csv.writeAsString('$_header\n${'x' * 200}\n');
      final small = CsvSyncService(SyncRepository(db), maxFileBytes: 100);
      await expectLater(
        small.sync(csv.path),
        throwsA(
          isA<SyncException>().having(
            (e) => e.message,
            'message',
            contains('quá lớn'),
          ),
        ),
      );
    });

    test('file đang bị khóa', () async {
      await csv.writeAsString('$_header\n13/11/2026,Chi,Ăn uống,65000,a\n');
      final raf = await csv.open(mode: FileMode.append);
      try {
        await raf.lock(FileLock.exclusive);
        await expectLater(
          service.sync(csv.path),
          throwsA(
            isA<SyncException>().having(
              (e) => e.message,
              'message',
              contains('khóa'),
            ),
          ),
        );
      } finally {
        await raf.unlock();
        await raf.close();
      }
      expect(await all(), isEmpty);
    }, skip: Platform.isWindows ? false : 'Khóa bắt buộc chỉ có trên Windows');
  });
}
