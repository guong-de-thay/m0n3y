import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/database/mock_data.dart';
import 'package:m0n3y/data/models/transaction_models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<int> cat(String name, TxType type) =>
      db.categoriesDao.getOrCreateByName(name: name, type: type);

  Future<int> add(
    DateTime date,
    int amount, {
    TxType type = TxType.expense,
    String category = 'Ăn uống',
    String note = '',
    bool notable = false,
  }) async {
    return db.transactionsDao.insertTransaction(
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

  group('Seed danh mục', () {
    test('có 9 danh mục chi và 5 danh mục thu mặc định', () async {
      expect((await db.categoriesDao.getAll(type: TxType.expense)).length, 9);
      expect((await db.categoriesDao.getAll(type: TxType.income)).length, 5);
    });
  });

  group('I4 - không trùng danh mục', () {
    test(
      'các cách viết hoa/thường/thừa khoảng trắng cho cùng một id',
      () async {
        final a = await cat('Ăn uống', TxType.expense);
        final b = await cat('ăn uống ', TxType.expense);
        final c = await cat('ĂN UỐNG', TxType.expense);
        expect({a, b, c}.length, 1);
      },
    );

    test(
      'cùng tên nhưng khác loại thu/chi là hai danh mục khác nhau',
      () async {
        final expense = await cat('Khác', TxType.expense);
        final income = await cat('Khác', TxType.income);
        expect(expense, isNot(income));
      },
    );

    test('danh mục mới tự tạo, gọi lại không tạo thêm', () async {
      final before = (await db.categoriesDao.getAll()).length;
      final first = await cat('Thú cưng', TxType.expense);
      final again = await cat('  thú cưng', TxType.expense);
      expect(again, first);
      expect((await db.categoriesDao.getAll()).length, before + 1);
    });

    test('tên rỗng quy về "Khác"', () async {
      final id = await cat('   ', TxType.expense);
      final other = await db.categoriesDao.findByName('Khác', TxType.expense);
      expect(id, other!.id);
    });
  });

  group('I1 - tiền tệ là int', () {
    test('lưu và cộng tổng chính xác tuyệt đối', () async {
      for (var i = 0; i < 1000; i++) {
        await add(DateTime(2026, 11, 1), 33333);
      }
      final totals = await db.transactionsDao.watchMonthTotals('2026-11').first;
      expect(totals.expense, 33333000);
      expect(totals.expense, isA<int>());
    });

    test('từ chối số tiền <= 0', () async {
      final id = await cat('Ăn uống', TxType.expense);
      expect(
        () => db.transactionsDao.insertTransaction(
          NewTransaction(
            transactionDate: DateTime(2026, 11, 1),
            type: TxType.expense,
            categoryId: id,
            amount: 0,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('I3 - tính theo transaction_date', () {
    test(
      'year_month tự tính từ ngày giao dịch (không phải created_at)',
      () async {
        final id = await add(DateTime(2026, 10, 28, 15, 30), 3000000);
        final row = await (db.select(
          db.transactions,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(row.yearMonth, '2026-10');
        expect(row.transactionDate, DateTime(2026, 10, 28)); // cắt về 00:00
      },
    );

    test('sửa ngày sang tháng khác thì year_month được tính lại', () async {
      final id = await add(DateTime(2026, 10, 31), 100000);
      await db.transactionsDao.updateTransaction(
        id,
        NewTransaction(
          transactionDate: DateTime(2026, 11, 1),
          type: TxType.expense,
          categoryId: await cat('Ăn uống', TxType.expense),
          amount: 100000,
        ),
      );
      final row = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.yearMonth, '2026-11');
    });

    test(
      'giao dịch lùi sang tháng trước không lẫn vào tháng hiện tại',
      () async {
        await add(DateTime(2026, 11, 13), 65000);
        await add(DateTime(2026, 10, 28), 500000);
        final nov = await db.transactionsDao.watchMonthTotals('2026-11').first;
        final oct = await db.transactionsDao.watchMonthTotals('2026-10').first;
        expect(nov.expense, 65000);
        expect(oct.expense, 500000);
      },
    );
  });

  group('I5 - stream phản ứng tức thời', () {
    test('watchMonthTotals phát lại khi thêm giao dịch', () async {
      final emissions = <int>[];
      final sub = db.transactionsDao
          .watchMonthTotals('2026-11')
          .listen((t) => emissions.add(t.expense));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await add(DateTime(2026, 11, 2), 70000);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.first, 0);
      expect(emissions.last, 70000);
    });
  });

  group('Bộ lọc & truy vấn', () {
    setUp(() async {
      await add(DateTime(2026, 11, 1), 50000, note: 'Phở bò');
      await add(DateTime(2026, 11, 5), 80000, note: 'Cà phê');
      await add(
        DateTime(2026, 11, 9),
        20000000,
        type: TxType.income,
        category: 'Lương',
        note: 'Lương T11',
      );
    });

    test('lọc theo loại', () async {
      final r = await db.transactionsDao
          .watchFiltered(type: TxType.income)
          .first;
      expect(r.length, 1);
      expect(r.single.transaction.amount, 20000000);
    });

    test('lọc khoảng ngày gồm cả hai đầu', () async {
      final r = await db.transactionsDao
          .watchFiltered(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 5))
          .first;
      expect(r.length, 2);
    });

    test('từ khóa không phân biệt hoa/thường, có dấu tiếng Việt', () async {
      final r = await db.transactionsDao.watchFiltered(keyword: 'PHỞ').first;
      expect(r.single.transaction.note, 'Phở bò');
    });

    test('từ khóa chứa ký tự đặc biệt SQL không làm hỏng truy vấn', () async {
      final r = await db.transactionsDao
          .watchFiltered(keyword: "'; DROP TABLE transactions;--")
          .first;
      expect(r, isEmpty);
      expect(await db.transactionsDao.countAll(), 3);
    });

    test('sắp xếp mới nhất trước', () async {
      final r = await db.transactionsDao.watchFiltered().first;
      final dates = r.map((e) => e.transaction.transactionDate).toList();
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
    });

    test('getAllForExport sắp xếp tăng dần theo ngày', () async {
      final r = await db.transactionsDao.getAllForExport();
      final dates = r.map((e) => e.transaction.transactionDate).toList();
      expect(dates, [...dates]..sort());
    });

    test('xóa giao dịch', () async {
      final all = await db.transactionsDao.watchFiltered().first;
      await db.transactionsDao.deleteTransaction(all.first.transaction.id);
      expect(await db.transactionsDao.countAll(), 2);
    });
  });

  group('Dashboard / Calendar', () {
    test(
      'Visual Notes: chi lớn có ghi chú, hoặc đánh dấu is_notable',
      () async {
        await add(
          DateTime(2026, 11, 3),
          600000,
          note: 'Mua giày',
        ); // lớn + note
        await add(DateTime(2026, 11, 4), 700000); // lớn nhưng không có note
        await add(
          DateTime(2026, 11, 5),
          50000,
          note: 'Quan trọng',
          notable: true,
        );
        await add(DateTime(2026, 11, 6), 50000, note: 'Bình thường');
        final notes = await db.transactionsDao
            .watchVisualNotes('2026-11')
            .first;
        expect(notes.map((n) => n.transaction.note), [
          'Mua giày',
          'Quan trọng',
        ]);
      },
    );

    test('cơ cấu danh mục chỉ cộng đúng loại và tháng, lớn → nhỏ', () async {
      await add(DateTime(2026, 11, 1), 100000, category: 'Ăn uống');
      await add(DateTime(2026, 11, 2), 50000, category: 'Ăn uống');
      await add(DateTime(2026, 11, 3), 400000, category: 'Mua sắm');
      await add(DateTime(2026, 10, 3), 999999, category: 'Mua sắm');
      final r = await db.transactionsDao
          .watchCategoryBreakdown('2026-11', TxType.expense)
          .first;
      expect(r.map((e) => e.category.name), ['Mua sắm', 'Ăn uống']);
      expect(r.map((e) => e.total), [400000, 150000]);
    });

    test('chuỗi nhiều tháng: đúng tháng, đúng loại, tháng trống = 0', () async {
      await add(DateTime(2026, 10, 30), 100000);
      await add(
        DateTime(2026, 10, 31),
        1000000,
        type: TxType.income,
        category: 'Lương',
      );
      await add(DateTime(2026, 12, 1), 250000);
      await add(DateTime(2026, 9, 30), 999999); // ngoài khoảng
      await add(DateTime(2027, 1, 1), 999999); // ngoài khoảng
      final s = await db.transactionsDao
          .watchMonthlySeries('2026-10', '2026-12')
          .first;
      expect(s.map((e) => e.yearMonth), ['2026-10', '2026-11', '2026-12']);
      expect(s.map((e) => e.income), [1000000, 0, 0]);
      expect(s.map((e) => e.expense), [100000, 0, 250000]);
      expect(s.first.balance, 900000);
    });

    test('chuỗi nhiều tháng: qua năm, ngược khoảng và sai định dạng', () async {
      final dao = db.transactionsDao;
      final r = await dao.watchMonthlySeries('2026-11', '2027-02').first;
      expect(r.map((e) => e.yearMonth), [
        '2026-11',
        '2026-12',
        '2027-01',
        '2027-02',
      ]);
      expect(await dao.watchMonthlySeries('2026-12', '2026-11').first, isEmpty);
      expect(
        () => dao.watchMonthlySeries('2026-13', '2026-12'),
        throwsArgumentError,
      );
      expect(
        () => dao.watchMonthlySeries('2026/11', '2026-12'),
        throwsArgumentError,
      );
    });

    test(
      'chuỗi nhiều tháng: stream phát lại khi thêm giao dịch (I5)',
      () async {
        final emissions = <int>[];
        final sub = db.transactionsDao
            .watchMonthlySeries('2026-11', '2026-11')
            .listen((s) => emissions.add(s.single.expense));
        await pumpEventQueue();
        await add(DateTime(2026, 11, 2), 70000);
        await pumpEventQueue();
        await sub.cancel();
        expect(emissions.first, 0);
        expect(emissions.last, 70000);
      },
    );

    test('lịch gom theo ngày với tổng thu và chi', () async {
      await add(DateTime(2026, 11, 7), 40000);
      await add(DateTime(2026, 11, 7), 60000);
      await add(
        DateTime(2026, 11, 7),
        1000000,
        type: TxType.income,
        category: 'Thưởng',
      );
      final m = await db.transactionsDao.watchDailyCashflow('2026-11').first;
      final day = m[DateTime(2026, 11, 7)]!;
      expect(day.expense, 100000);
      expect(day.income, 1000000);
      expect(day.transactions.length, 3);
    });
  });

  group('Mock data', () {
    test(
      'nạp 29 giao dịch trải qua hai tháng 10 và 11/2026, idempotent',
      () async {
        await seedMockData(db);
        final count = await db.transactionsDao.countAll();
        expect(count, 29);
        await seedMockData(db);
        expect(await db.transactionsDao.countAll(), count);
        final oct = await db.transactionsDao.watchMonthTotals('2026-10').first;
        final nov = await db.transactionsDao.watchMonthTotals('2026-11').first;
        expect(oct.income, greaterThan(0));
        expect(nov.income, greaterThan(0));
      },
    );
  });
}
