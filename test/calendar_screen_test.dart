import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/calendar_view/presentation/calendar_screen.dart';
import 'package:m0n3y/features/calendar_view/providers/calendar_provider.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('CalendarScreen', () {
    late AppDatabase db;
    late ProviderContainer container;
    final fixedToday = DateTime(2026, 11, 15);

    setUp(() {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          calendarTodayProvider.overrideWithValue(fixedToday),
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

    Future<void> pumpCalendar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
        ),
      );
      await flushDb(tester);
    }

    Future<int> seedTx({
      required DateTime date,
      required TxType type,
      required String categoryName,
      required int amount,
      String note = '',
      bool isNotable = false,
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
          isNotable: isNotable,
        ),
      );
    }

    testWidgets('ô ngày hiện đúng tổng Thu/Chi và panel hiện chi tiết ngày', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 11, 15),
          type: TxType.income,
          categoryName: 'Lương',
          amount: 10000000,
          note: 'Lương tháng 11',
        );
        await seedTx(
          date: DateTime(2026, 11, 15),
          type: TxType.expense,
          categoryName: 'Ăn uống',
          amount: 65000,
          note: 'Phở bò sáng',
          isNotable: true,
        );
        await seedTx(
          date: DateTime(2026, 11, 10),
          type: TxType.expense,
          categoryName: 'Mua sắm',
          amount: 500000,
          note: 'Tai nghe mới',
        );
      });

      await pumpCalendar(tester);

      expect(find.text('Tháng 11/2026'), findsOneWidget);
      expect(find.text('Thu: +10.000.000 ₫'), findsWidgets);
      expect(find.text('Chi: -565.000 ₫'), findsOneWidget);

      // Kiểm tra ô ngày 15/11 có tổng Thu/Chi riêng.
      final day15Cell = find.byKey(const ValueKey('calendar_day_2026_11_15'));
      expect(
        find.descendant(of: day15Cell, matching: find.text('+10.000.000 ₫')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: day15Cell, matching: find.text('-65.000 ₫')),
        findsOneWidget,
      );

      // Panel phải mặc định đang mở hôm nay (15/11/2026).
      expect(find.text('Ngày 15/11/2026'), findsOneWidget);
      expect(find.text('Lương tháng 11'), findsOneWidget);
      expect(find.text('Phở bò sáng'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Click sang ngày 10/11 -> panel cập nhật đúng danh sách ngày 10.
      await tester.tap(find.byKey(const ValueKey('calendar_day_2026_11_10')));
      await tester.pumpAndSettle();
      expect(find.text('Ngày 10/11/2026'), findsOneWidget);
      expect(find.text('Tai nghe mới'), findsOneWidget);
      expect(find.text('Phở bò sáng'), findsNothing);

      // Click sang ngày 02/11 (không có giao dịch) -> trạng thái rỗng.
      await tester.tap(find.byKey(const ValueKey('calendar_day_2026_11_2')));
      await tester.pumpAndSettle();
      expect(find.text('Ngày 02/11/2026'), findsOneWidget);
      expect(find.text('Không có giao dịch nào'), findsOneWidget);
    });

    testWidgets('chuyển tháng hiển thị đúng dữ liệu tháng trước (I3)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 10, 28),
          type: TxType.income,
          categoryName: 'Thưởng',
          amount: 3000000,
          note: 'Thưởng dự án tháng 10',
        );
      });

      await pumpCalendar(tester);
      expect(find.text('Tháng 11/2026'), findsOneWidget);
      expect(find.text('Không có giao dịch nào'), findsOneWidget);

      await tester.tap(find.byTooltip('Tháng trước'));
      await flushDb(tester);
      expect(find.text('Tháng 10/2026'), findsOneWidget);

      final day28Cell = find.byKey(const ValueKey('calendar_day_2026_10_28'));
      expect(
        find.descendant(of: day28Cell, matching: find.text('+3.000.000 ₫')),
        findsOneWidget,
      );

      await tester.tap(day28Cell);
      await tester.pumpAndSettle();
      expect(find.text('Ngày 28/10/2026'), findsOneWidget);
      expect(find.text('Thưởng dự án tháng 10'), findsOneWidget);
    });

    testWidgets('lưới và panel tự cập nhật khi DB thay đổi (I5)', (
      tester,
    ) async {
      await pumpCalendar(tester);
      expect(find.text('Không có giao dịch nào'), findsOneWidget);

      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 11, 15),
          type: TxType.expense,
          categoryName: 'Ăn uống',
          amount: 95000,
          note: 'Cơm trưa văn phòng',
        );
      });
      await flushDb(tester);

      expect(find.text('Cơm trưa văn phòng'), findsOneWidget);
      final day15Cell = find.byKey(const ValueKey('calendar_day_2026_11_15'));
      expect(
        find.descendant(of: day15Cell, matching: find.text('-95.000 ₫')),
        findsOneWidget,
      );
    });
  });
}
