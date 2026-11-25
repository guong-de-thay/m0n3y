import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/transactions/presentation/transactions_screen.dart';
import 'package:m0n3y/features/transactions/providers/transactions_provider.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('TransactionsScreen', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
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

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
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
      TxSource source = TxSource.manual,
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
          source: source,
        ),
      );
    }

    testWidgets('hiển thị trạng thái rỗng khi chưa có giao dịch', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
      expect(find.text('Thêm giao dịch đầu tiên'), findsOneWidget);
    });

    testWidgets('hiển thị bảng giao dịch, sao đáng chú ý và thanh tóm tắt I1', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 11, 5),
          type: TxType.income,
          categoryName: 'Lương',
          amount: 10000000,
          note: 'Lương tháng 11',
        );
        await seedTx(
          date: DateTime(2026, 11, 13),
          type: TxType.expense,
          categoryName: 'Ăn uống',
          amount: 65000,
          note: 'Phở bò sáng',
          isNotable: true,
        );
      });

      await pumpScreen(tester);

      expect(find.text('Hiển thị 2 giao dịch'), findsOneWidget);
      expect(find.text('Thu: +10.000.000 ₫'), findsOneWidget);
      expect(find.text('Chi: -65.000 ₫'), findsOneWidget);
      expect(find.text('Chênh lệch: 9.935.000 ₫'), findsOneWidget);

      expect(find.text('05/11/2026'), findsOneWidget);
      expect(find.text('13/11/2026'), findsOneWidget);
      expect(find.text('Lương tháng 11'), findsOneWidget);
      expect(find.text('Phở bò sáng'), findsOneWidget);
      expect(find.text('+10.000.000 ₫'), findsOneWidget);
      expect(find.text('-65.000 ₫'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('lọc theo từ khóa, loại, danh mục, ngày và xóa bộ lọc', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 10, 28),
          type: TxType.expense,
          categoryName: 'Ăn uống',
          amount: 50000,
          note: 'Bún bò Huế',
        );
        await seedTx(
          date: DateTime(2026, 11, 5),
          type: TxType.income,
          categoryName: 'Lương',
          amount: 12000000,
          note: 'Lương chính thức',
        );
        await seedTx(
          date: DateTime(2026, 11, 15),
          type: TxType.expense,
          categoryName: 'Mua sắm',
          amount: 800000,
          note: 'Tai nghe mới',
        );
      });

      await pumpScreen(tester);
      expect(find.text('Hiển thị 3 giao dịch'), findsOneWidget);

      // 1. Lọc theo từ khóa ghi chú.
      await tester.enterText(find.byType(TextField), 'Tai nghe');
      await flushDb(tester);
      expect(find.text('Hiển thị 1 giao dịch'), findsOneWidget);
      expect(find.text('Tai nghe mới'), findsOneWidget);
      expect(find.text('Bún bò Huế'), findsNothing);

      // Bấm nút xóa từ khóa.
      await tester.tap(find.byTooltip('Xóa từ khóa'));
      await flushDb(tester);
      expect(find.text('Hiển thị 3 giao dịch'), findsOneWidget);

      // 2. Lọc theo Loại (Thu).
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thu').last);
      await flushDb(tester);
      expect(find.text('Hiển thị 1 giao dịch'), findsOneWidget);
      expect(find.text('Lương chính thức'), findsOneWidget);

      // Bấm nút Xóa lọc trên thanh filter bar.
      await tester.tap(find.text('Xóa lọc'));
      await flushDb(tester);
      expect(find.text('Hiển thị 3 giao dịch'), findsOneWidget);

      // 3. Lọc theo Danh mục (Ăn uống).
      await tester.tap(find.text('Tất cả danh mục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await flushDb(tester);
      expect(find.text('Hiển thị 1 giao dịch'), findsOneWidget);
      expect(find.text('Bún bò Huế'), findsOneWidget);

      // 4. Lọc theo khoảng ngày -> không khớp với giao dịch tháng 10.
      container
          .read(transactionFilterProvider.notifier)
          .setFrom(DateTime(2026, 11, 1));
      await flushDb(tester);
      expect(find.text('Từ: 01/11/2026'), findsOneWidget);
      expect(find.text('Không có giao dịch nào khớp bộ lọc'), findsOneWidget);

      // Bấm Xóa bộ lọc từ EmptyState để khôi phục toàn bộ.
      await tester.tap(find.text('Xóa bộ lọc'));
      await flushDb(tester);
      expect(find.text('Hiển thị 3 giao dịch'), findsOneWidget);
    });

    testWidgets('thêm giao dịch: kiểm tra validation và lưu cập nhật UI (I5)', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Thêm giao dịch'));
      await flushDb(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Bỏ trống số tiền -> báo lỗi.
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập số tiền.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Nhập 0 -> báo lỗi số nguyên dương > 0.
      final amountField = find.widgetWithText(TextFormField, 'Số tiền (VNĐ)');
      await tester.enterText(amountField, '0');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(
        find.text('Số tiền phải là số nguyên dương lớn hơn 0.'),
        findsOneWidget,
      );

      // Chọn loại Thu, nhập hợp lệ và đánh dấu đáng chú ý.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Thu'),
        ),
      );
      await flushDb(tester);

      await tester.enterText(amountField, '500000');
      final noteField = find.widgetWithText(TextFormField, 'Ghi chú');
      await tester.enterText(noteField, 'Thưởng dự án');
      await tester.tap(find.text('Đánh dấu đáng chú ý (Visual Notes)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu'));
      await flushDb(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Đã thêm giao dịch mới.'), findsOneWidget);
      expect(find.text('Hiển thị 1 giao dịch'), findsOneWidget);
      expect(find.text('Thưởng dự án'), findsOneWidget);
      expect(find.text('+500.000 ₫'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      final all = await tester.runAsync(
        () => container.read(transactionRepositoryProvider).getAllForExport(),
      );
      expect(all, hasLength(1));
      expect(all!.single.transaction.amount, 500000);
      expect(all.single.transaction.type, TxType.income);
      expect(all.single.transaction.isNotable, isTrue);
    });

    testWidgets('sửa giao dịch: cập nhật UI tức thì và giữ nguyên source', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 11, 10),
          type: TxType.expense,
          categoryName: 'Ăn uống',
          amount: 65000,
          note: 'Phở bò',
          source: TxSource.icloudCsv,
        );
      });

      await pumpScreen(tester);
      expect(find.text('Phở bò'), findsOneWidget);
      expect(find.text('-65.000 ₫'), findsOneWidget);

      await tester.tap(find.byTooltip('Sửa'));
      await flushDb(tester);
      expect(find.text('Sửa giao dịch'), findsOneWidget);
      expect(find.text('65000'), findsOneWidget);
      expect(find.text('Phở bò'), findsWidgets);

      final amountField = find.widgetWithText(TextFormField, 'Số tiền (VNĐ)');
      final noteField = find.widgetWithText(TextFormField, 'Ghi chú');
      await tester.enterText(amountField, '120000');
      await tester.enterText(noteField, 'Phở đặc biệt');
      await tester.tap(find.text('Đánh dấu đáng chú ý (Visual Notes)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu'));
      await flushDb(tester);

      expect(find.text('Đã cập nhật giao dịch.'), findsOneWidget);
      expect(find.text('Phở đặc biệt'), findsOneWidget);
      expect(find.text('-120.000 ₫'), findsOneWidget);
      expect(find.text('Chi: -120.000 ₫'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      final all = await tester.runAsync(
        () => container.read(transactionRepositoryProvider).getAllForExport(),
      );
      expect(all, hasLength(1));
      expect(all!.single.transaction.amount, 120000);
      expect(all.single.transaction.note, 'Phở đặc biệt');
      expect(all.single.transaction.source, TxSource.icloudCsv);
    });

    testWidgets('xóa giao dịch: hủy giữ nguyên, xác nhận xóa khỏi UI và DB', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedTx(
          date: DateTime(2026, 11, 18),
          type: TxType.expense,
          categoryName: 'Ăn uống',
          amount: 45000,
          note: 'Cà phê sáng',
        );
      });

      await pumpScreen(tester);
      expect(find.text('Cà phê sáng'), findsOneWidget);

      // Bấm Xóa rồi Hủy -> giao dịch vẫn còn.
      await tester.tap(find.byTooltip('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa giao dịch?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Cà phê sáng'), findsOneWidget);

      // Bấm Xóa rồi xác nhận Xóa -> biến mất khỏi UI và DB.
      await tester.tap(find.byTooltip('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Xóa'),
        ),
      );
      await flushDb(tester);

      expect(find.text('Đã xóa giao dịch.'), findsOneWidget);
      expect(find.text('Cà phê sáng'), findsNothing);
      expect(find.text('Chưa có giao dịch nào'), findsOneWidget);

      final all = await tester.runAsync(
        () => container.read(transactionRepositoryProvider).getAllForExport(),
      );
      expect(all, isEmpty);
    });

    testWidgets(
      'xóa giao dịch gặp lỗi: hiện SnackBar tiếng Việt, không crash',
      (tester) async {
        final failingContainer = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            transactionActionsProvider.overrideWith(
              (ref) => _FailingDeleteActions(
                ref.watch(transactionRepositoryProvider),
              ),
            ),
          ],
        );
        addTearDown(failingContainer.dispose);

        await tester.runAsync(() async {
          final repo = failingContainer.read(transactionRepositoryProvider);
          final catId = await repo.getOrCreateCategory(
            'Ăn uống',
            TxType.expense,
          );
          await repo.add(
            NewTransaction(
              transactionDate: DateTime(2026, 11, 18),
              type: TxType.expense,
              categoryId: catId,
              amount: 45000,
              note: 'Cà phê lỗi xóa',
            ),
          );
        });

        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: failingContainer,
            child: const MaterialApp(
              home: Scaffold(body: TransactionsScreen()),
            ),
          ),
        );
        await flushDb(tester);

        await tester.tap(find.byTooltip('Xóa'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Xóa'),
          ),
        );
        await flushDb(tester);

        expect(
          find.text('Không thể xóa giao dịch. Vui lòng thử lại.'),
          findsOneWidget,
        );
        expect(find.text('Cà phê lỗi xóa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _FailingDeleteActions extends TransactionActions {
  _FailingDeleteActions(super.repo);

  @override
  Future<int> delete(int id) async => throw StateError('Lỗi DB giả lập');
}
