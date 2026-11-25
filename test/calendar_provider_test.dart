import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/calendar_view/providers/calendar_provider.dart';

void main() {
  group('CalendarViewNotifier và monthlyDailyCashflowProvider', () {
    late AppDatabase db;
    late ProviderContainer container;
    late ProviderSubscription<AsyncValue<Map<DateTime, DailyCashflow>>>
    cashflowSub;

    final fixedToday = DateTime(2026, 11, 15);

    setUp(() {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          calendarTodayProvider.overrideWithValue(fixedToday),
        ],
      );
      // Giữ listener active để Riverpod 3 không pause StreamProvider.
      cashflowSub = container.listen(monthlyDailyCashflowProvider, (_, _) {});
    });

    tearDown(() async {
      cashflowSub.close();
      container.dispose();
      await db.close();
    });

    Future<int> seedTx({
      required DateTime date,
      required TxType type,
      required String categoryName,
      required int amount,
      String note = '',
    }) async {
      final repo = container.read(transactionRepositoryProvider);
      final categoryId = await repo.getOrCreateCategory(categoryName, type);
      return repo.add(
        NewTransaction(
          transactionDate: date,
          type: type,
          categoryId: categoryId,
          amount: amount,
          note: note,
        ),
      );
    }

    Future<Map<DateTime, DailyCashflow>> readMonthly() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container.read(monthlyDailyCashflowProvider.future);
    }

    test('khởi tạo theo ngày hôm nay, chọn ngày và chuyển tháng', () {
      final initial = container.read(calendarViewProvider);
      expect(initial.focusedMonth, DateTime(2026, 11, 1));
      expect(initial.selectedDate, DateTime(2026, 11, 15));
      expect(initial.yearMonth, '2026-11');

      final notifier = container.read(calendarViewProvider.notifier);

      // Chọn ngày khác trong tháng.
      notifier.selectDate(DateTime(2026, 11, 20, 14, 30));
      expect(
        container.read(calendarViewProvider).selectedDate,
        DateTime(2026, 11, 20),
      );

      // Lùi về tháng 10 -> selectedDate đặt về ngày mùng 1 của tháng 10.
      notifier.previousMonth();
      var state = container.read(calendarViewProvider);
      expect(state.focusedMonth, DateTime(2026, 10, 1));
      expect(state.selectedDate, DateTime(2026, 10, 1));
      expect(state.yearMonth, '2026-10');

      // Tiến lại tháng 11 (trùng tháng hôm nay) -> selectedDate về hôm nay.
      notifier.nextMonth();
      state = container.read(calendarViewProvider);
      expect(state.focusedMonth, DateTime(2026, 11, 1));
      expect(state.selectedDate, fixedToday);

      // Nhảy sang tháng 12 rồi bấm goToToday -> quay lại tháng 11 ngày 15.
      notifier.nextMonth();
      expect(container.read(calendarViewProvider).yearMonth, '2026-12');
      notifier.goToToday();
      expect(container.read(calendarViewProvider).selectedDate, fixedToday);
    });

    test('gom nhóm theo transaction_date (I3) và tính tổng int (I1)', () async {
      await seedTx(
        date: DateTime(2026, 10, 28),
        type: TxType.expense,
        categoryName: 'Ăn uống',
        amount: 80000,
        note: 'Bữa tối tháng 10',
      );
      await seedTx(
        date: DateTime(2026, 11, 15),
        type: TxType.income,
        categoryName: 'Lương',
        amount: 12000000,
        note: 'Lương tháng 11',
      );
      await seedTx(
        date: DateTime(2026, 11, 15),
        type: TxType.expense,
        categoryName: 'Ăn uống',
        amount: 65000,
        note: 'Phở bò',
      );

      final novMap = await readMonthly();
      expect(novMap.keys, [DateTime(2026, 11, 15)]);

      final day = container.read(selectedDayCashflowProvider);
      expect(day, isNotNull);
      expect(day!.income, 12000000);
      expect(day.expense, 65000);
      expect(day.transactions, hasLength(2));

      final totals = container.read(calendarMonthTotalsProvider);
      expect(totals.income, isA<int>());
      expect(totals.expense, isA<int>());
      expect(totals.income, 12000000);
      expect(totals.expense, 65000);

      // Chuyển sang tháng 10 chỉ thấy giao dịch lùi ngày tháng 10.
      container.read(calendarViewProvider.notifier).previousMonth();
      final octMap = await readMonthly();
      expect(octMap.keys, [DateTime(2026, 10, 28)]);
      expect(octMap[DateTime(2026, 10, 28)]!.expense, 80000);
    });

    test('tự cập nhật khi thêm, sửa, xóa giao dịch (I5)', () async {
      var map = await readMonthly();
      expect(map, isEmpty);

      final id = await seedTx(
        date: DateTime(2026, 11, 15),
        type: TxType.expense,
        categoryName: 'Mua sắm',
        amount: 250000,
        note: 'Áo sơ mi',
      );

      map = await readMonthly();
      expect(map[DateTime(2026, 11, 15)]?.expense, 250000);

      final repo = container.read(transactionRepositoryProvider);
      final catId = map[DateTime(2026, 11, 15)]!.transactions.first.category.id;
      await repo.update(
        id,
        NewTransaction(
          transactionDate: DateTime(2026, 11, 15),
          type: TxType.expense,
          categoryId: catId,
          amount: 320000,
          note: 'Áo khoác',
        ),
      );
      map = await readMonthly();
      expect(map[DateTime(2026, 11, 15)]?.expense, 320000);

      await repo.delete(id);
      map = await readMonthly();
      expect(map, isEmpty);
    });
  });
}
