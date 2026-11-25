import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/dashboard/presentation/dashboard_screen.dart';
import 'package:m0n3y/features/dashboard/providers/dashboard_provider.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DashboardScreen', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dashboardTodayProvider.overrideWithValue(DateTime(2026, 11, 15)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> flushDb(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpDashboard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await flushDb(tester);
    }

    Future<void> seedTx(
      DateTime date,
      int amount, {
      TxType type = TxType.expense,
      String category = 'Ăn uống',
      String note = '',
    }) async {
      final repo = container.read(transactionRepositoryProvider);
      await repo.add(
        NewTransaction(
          transactionDate: date,
          type: type,
          categoryId: await repo.getOrCreateCategory(category, type),
          amount: amount,
          note: note,
        ),
      );
    }

    Finder inKpi(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(text),
    );

    testWidgets('KPI và chuyển tháng theo transaction_date', (tester) async {
      await tester.runAsync(() async {
        await seedTx(DateTime(2026, 10, 1), 10000000, type: TxType.income);
        await seedTx(DateTime(2026, 10, 31), 2000000); // nhập bù tháng 10
        await seedTx(
          DateTime(2026, 11, 5),
          800000,
          category: 'Mua sắm',
          note: 'Tủ lạnh mới',
        );
        await seedTx(DateTime(2026, 11, 10), 5000000, type: TxType.income);
      });
      await pumpDashboard(tester);

      expect(find.text('Tháng 11/2026'), findsOneWidget);
      expect(inKpi('kpi_balance', '12.200.000 ₫'), findsOneWidget);
      expect(inKpi('kpi_income', '5.000.000 ₫'), findsOneWidget);
      expect(inKpi('kpi_expense', '800.000 ₫'), findsOneWidget);

      await tester.tap(find.byTooltip('Tháng trước'));
      await flushDb(tester);

      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(inKpi('kpi_balance', '8.000.000 ₫'), findsOneWidget);
      expect(inKpi('kpi_income', '10.000.000 ₫'), findsOneWidget);
      expect(inKpi('kpi_expense', '2.000.000 ₫'), findsOneWidget);

      await tester.tap(find.text('Tháng này'));
      await flushDb(tester);
      expect(find.text('Tháng 11/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('thêm giao dịch thì KPI tự cập nhật (I5)', (tester) async {
      await tester.runAsync(
        () => seedTx(DateTime(2026, 11, 2), 4000000, type: TxType.income),
      );
      await pumpDashboard(tester);
      expect(inKpi('kpi_balance', '4.000.000 ₫'), findsOneWidget);

      await tester.runAsync(
        () => seedTx(
          DateTime(2026, 11, 12),
          1500000,
          category: 'Di chuyển',
          note: 'Sửa xe máy',
        ),
      );
      await flushDb(tester);

      expect(inKpi('kpi_balance', '2.500.000 ₫'), findsOneWidget);
      expect(inKpi('kpi_expense', '1.500.000 ₫'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chưa có dữ liệu: KPI hiện 0 ₫, biểu đồ báo trống', (
      tester,
    ) async {
      await pumpDashboard(tester);

      expect(inKpi('kpi_balance', '0 ₫'), findsOneWidget);
      expect(find.text('Chưa có giao dịch trong 6 tháng này.'), findsOneWidget);
      expect(
        find.text('Chưa có khoản chi nào trong tháng này.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
