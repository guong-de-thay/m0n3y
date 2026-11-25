import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/dashboard/providers/dashboard_provider.dart';

void main() {
  group('Dashboard providers', () {
    late AppDatabase db;
    late ProviderContainer container;
    final subs = <ProviderSubscription<Object?>>[];

    setUp(() {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dashboardTodayProvider.overrideWithValue(DateTime(2026, 11, 15)),
        ],
      );
      // Giữ listener để Riverpod 3 không tạm dừng các StreamProvider.
      for (final p in <ProviderListenable<Object?>>[
        dashboardMonthTotalsProvider,
        dashboardBalanceProvider,
        dashboardMonthlySeriesProvider,
        dashboardExpenseBreakdownProvider,
        dashboardVisualNotesProvider,
      ]) {
        subs.add(container.listen(p, (_, _) {}));
      }
    });

    tearDown(() async {
      for (final s in subs) {
        s.close();
      }
      subs.clear();
      container.dispose();
      await db.close();
    });

    Future<int> seedTx(
      DateTime date,
      int amount, {
      TxType type = TxType.expense,
      String category = 'Ăn uống',
      String note = '',
      bool notable = false,
    }) async {
      final repo = container.read(transactionRepositoryProvider);
      return repo.add(
        NewTransaction(
          transactionDate: date,
          type: type,
          categoryId: await repo.getOrCreateCategory(category, type),
          amount: amount,
          note: note,
          isNotable: notable,
        ),
      );
    }

    Future<T> readLatest<T>(ProviderListenable<Future<T>> provider) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container.read(provider);
    }

    DashboardMonthNotifier notifier() =>
        container.read(dashboardMonthProvider.notifier);

    test('tháng đang xem bắt đầu từ hôm nay và chuyển tháng qua năm', () {
      expect(container.read(dashboardMonthProvider), DateTime(2026, 11));
      expect(container.read(dashboardYearMonthProvider), '2026-11');

      notifier().previousMonth();
      expect(container.read(dashboardYearMonthProvider), '2026-10');

      notifier()
        ..nextMonth()
        ..nextMonth()
        ..nextMonth();
      expect(container.read(dashboardYearMonthProvider), '2027-01');

      notifier().goToCurrentMonth();
      expect(container.read(dashboardMonthProvider), DateTime(2026, 11));

      notifier().selectMonth(DateTime(2026, 3, 20));
      expect(container.read(dashboardMonthProvider), DateTime(2026, 3));
    });

    test('tổng tháng và số dư lũy kế theo transaction_date (I1, I3)', () async {
      await seedTx(DateTime(2026, 10, 1), 10000000, type: TxType.income);
      // Nhập bù cuối tháng 10 -> phải nằm ở tháng 10, không phải tháng 11.
      await seedTx(DateTime(2026, 10, 31), 2000000);
      await seedTx(DateTime(2026, 11, 5), 1000000);
      await seedTx(DateTime(2026, 11, 10), 5000000, type: TxType.income);
      await seedTx(DateTime(2026, 12, 1), 3000000);

      var totals = await readLatest(dashboardMonthTotalsProvider.future);
      expect(totals.income, 5000000);
      expect(totals.expense, 1000000);
      // 10tr + 5tr - 2tr - 1tr; khoản tháng 12 chưa tính.
      expect(await readLatest(dashboardBalanceProvider.future), 12000000);

      notifier().previousMonth();
      totals = await readLatest(dashboardMonthTotalsProvider.future);
      expect(totals.income, 10000000);
      expect(totals.expense, 2000000);
      expect(await readLatest(dashboardBalanceProvider.future), 8000000);
    });

    test('biểu đồ cột có đủ 6 tháng, tháng trống bằng 0', () async {
      await seedTx(DateTime(2026, 6, 15), 300000);
      await seedTx(DateTime(2026, 11, 2), 7000000, type: TxType.income);
      await seedTx(DateTime(2026, 5, 31), 999999); // ngoài khoảng

      final series = await readLatest(dashboardMonthlySeriesProvider.future);
      expect(series.map((m) => m.yearMonth), [
        '2026-06',
        '2026-07',
        '2026-08',
        '2026-09',
        '2026-10',
        '2026-11',
      ]);
      expect(series.first.expense, 300000);
      expect(series.last.income, 7000000);
      expect(
        series.sublist(1, 5).every((m) => m.income + m.expense == 0),
        true,
      );
    });

    test('cơ cấu chi chỉ lấy khoản chi của tháng, lớn → nhỏ', () async {
      await seedTx(DateTime(2026, 11, 1), 150000, category: 'Ăn uống');
      await seedTx(DateTime(2026, 11, 2), 400000, category: 'Mua sắm');
      await seedTx(DateTime(2026, 11, 3), 50000, category: 'Ăn uống');
      await seedTx(
        DateTime(2026, 11, 4),
        9000000,
        type: TxType.income,
        category: 'Lương',
      );
      await seedTx(DateTime(2026, 10, 4), 800000, category: 'Di chuyển');

      final breakdown = await readLatest(
        dashboardExpenseBreakdownProvider.future,
      );
      expect(breakdown.map((c) => c.category.name), ['Mua sắm', 'Ăn uống']);
      expect(breakdown.map((c) => c.total), [400000, 200000]);
    });

    test('Visual Notes: đánh dấu hoặc chi >= 500k có ghi chú', () async {
      await seedTx(DateTime(2026, 11, 3), 600000, note: 'Mua giày');
      await seedTx(DateTime(2026, 11, 4), 700000); // lớn nhưng không ghi chú
      await seedTx(DateTime(2026, 11, 5), 40000, note: 'Quà', notable: true);
      await seedTx(DateTime(2026, 11, 6), 499999, note: 'Gần ngưỡng');
      await seedTx(DateTime(2026, 10, 6), 900000, note: 'Tháng trước');

      final notes = await readLatest(dashboardVisualNotesProvider.future);
      expect(notes.map((n) => n.transaction.note), ['Mua giày', 'Quà']);
    });

    test('thêm, sửa, xóa giao dịch thì số liệu tự cập nhật (I5)', () async {
      expect(await readLatest(dashboardBalanceProvider.future), 0);

      final id = await seedTx(DateTime(2026, 11, 8), 800000, note: 'Tủ lạnh');
      var totals = await readLatest(dashboardMonthTotalsProvider.future);
      expect(totals.expense, 800000);
      expect(await readLatest(dashboardBalanceProvider.future), -800000);
      expect(
        await readLatest(dashboardVisualNotesProvider.future),
        hasLength(1),
      );

      final repo = container.read(transactionRepositoryProvider);
      final catId = await repo.getOrCreateCategory('Ăn uống', TxType.expense);
      await repo.update(
        id,
        NewTransaction(
          transactionDate: DateTime(2026, 11, 8),
          type: TxType.expense,
          categoryId: catId,
          amount: 300000,
          note: 'Tủ lạnh',
        ),
      );
      totals = await readLatest(dashboardMonthTotalsProvider.future);
      expect(totals.expense, 300000);
      expect(await readLatest(dashboardVisualNotesProvider.future), isEmpty);

      await repo.delete(id);
      totals = await readLatest(dashboardMonthTotalsProvider.future);
      expect(totals.expense, 0);
      expect(await readLatest(dashboardBalanceProvider.future), 0);
    });
  });
}
