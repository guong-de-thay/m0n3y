import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/transactions/domain/transaction_filter.dart';
import 'package:m0n3y/features/transactions/domain/transaction_formatters.dart';
import 'package:m0n3y/features/transactions/providers/transactions_provider.dart';

void main() {
  group('TransactionFilter và formatters', () {
    test('isEmpty, copyWith (gán và xóa về null), equality và hashCode', () {
      const empty = TransactionFilter();
      expect(empty.isEmpty, isTrue);

      final filled = empty.copyWith(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        categoryId: 3,
        type: TxType.expense,
        keyword: 'phở',
      );
      expect(filled.isEmpty, isFalse);
      expect(
        filled,
        TransactionFilter(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
          categoryId: 3,
          type: TxType.expense,
          keyword: 'phở',
        ),
      );
      expect(
        filled.hashCode,
        TransactionFilter(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
          categoryId: 3,
          type: TxType.expense,
          keyword: 'phở',
        ).hashCode,
      );

      final cleared = filled.copyWith(
        from: null,
        to: null,
        categoryId: null,
        type: null,
        keyword: '   ',
      );
      expect(cleared.from, isNull);
      expect(cleared.to, isNull);
      expect(cleared.categoryId, isNull);
      expect(cleared.type, isNull);
      expect(cleared.isEmpty, isTrue);
    });

    test('formatVnd định dạng số nguyên VNĐ đúng chuẩn', () {
      expect(formatVnd(0), '0 ₫');
      expect(formatVnd(65000), '65.000 ₫');
      expect(formatVnd(1250000), '1.250.000 ₫');
      expect(formatVnd(-500000), '-500.000 ₫');
    });

    test('formatDate định dạng dd/MM/yyyy và formatTxType', () {
      expect(formatDate(DateTime(2026, 3, 5)), '05/03/2026');
      expect(formatDate(DateTime(2026, 11, 24)), '24/11/2026');
      expect(formatTxType(TxType.income), 'Thu');
      expect(formatTxType(TxType.expense), 'Chi');
    });
  });

  group('TransactionFilterNotifier và filteredTransactionsProvider', () {
    late AppDatabase db;
    late ProviderContainer container;
    late ProviderSubscription<AsyncValue<List<TransactionWithCategory>>>
    filteredSub;
    late int foodCatId;
    late int shoppingCatId;
    late int salaryCatId;

    setUp(() async {
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      // Giữ listener active để Riverpod 3 không pause StreamProvider.
      filteredSub = container.listen(filteredTransactionsProvider, (_, _) {});

      final repo = container.read(transactionRepositoryProvider);
      foodCatId = await repo.getOrCreateCategory('Ăn uống', TxType.expense);
      shoppingCatId = await repo.getOrCreateCategory('Mua sắm', TxType.expense);
      salaryCatId = await repo.getOrCreateCategory('Lương', TxType.income);

      final actions = container.read(transactionActionsProvider);
      await actions.add(
        NewTransaction(
          transactionDate: DateTime(2026, 10, 28),
          type: TxType.expense,
          categoryId: foodCatId,
          amount: 55000,
          note: 'Bún chả tháng 10',
        ),
      );
      await actions.add(
        NewTransaction(
          transactionDate: DateTime(2026, 11, 5),
          type: TxType.income,
          categoryId: salaryCatId,
          amount: 15000000,
          note: 'Lương tháng 11',
        ),
      );
      await actions.add(
        NewTransaction(
          transactionDate: DateTime(2026, 11, 12),
          type: TxType.expense,
          categoryId: shoppingCatId,
          amount: 1250000,
          note: 'Mua bàn phím cơ',
          isNotable: true,
        ),
      );
    });

    tearDown(() async {
      filteredSub.close();
      container.dispose();
      await db.close();
    });

    Future<List<TransactionWithCategory>> readFiltered() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return container.read(filteredTransactionsProvider.future);
    }

    test('mặc định trả đủ toàn bộ giao dịch', () async {
      final items = await readFiltered();
      expect(items, hasLength(3));
    });

    test('lọc theo loại và tự reset categoryId khi đổi loại', () async {
      final notifier = container.read(transactionFilterProvider.notifier);
      notifier.setType(TxType.expense);
      notifier.setCategoryId(foodCatId);

      var items = await readFiltered();
      expect(items, hasLength(1));
      expect(items.single.category.id, foodCatId);

      // Đổi sang Thu phải reset categoryId để không giữ danh mục Chi.
      notifier.setType(TxType.income);
      expect(container.read(transactionFilterProvider).categoryId, isNull);

      items = await readFiltered();
      expect(items, hasLength(1));
      expect(items.single.transaction.type, TxType.income);
      expect(items.single.transaction.amount, 15000000);
    });

    test('lọc theo từ khóa tự trim và chuẩn hóa chuỗi rỗng về null', () async {
      final notifier = container.read(transactionFilterProvider.notifier);
      notifier.setKeyword('  bàn phím  ');
      expect(container.read(transactionFilterProvider).keyword, 'bàn phím');

      var items = await readFiltered();
      expect(items, hasLength(1));
      expect(items.single.transaction.note, 'Mua bàn phím cơ');

      notifier.setKeyword('   ');
      expect(container.read(transactionFilterProvider).keyword, isNull);
      items = await readFiltered();
      expect(items, hasLength(3));
    });

    test('lọc theo khoảng ngày from..to theo transaction_date (I3)', () async {
      final notifier = container.read(transactionFilterProvider.notifier);
      notifier.setFrom(DateTime(2026, 11, 1));
      notifier.setTo(DateTime(2026, 11, 10));

      var items = await readFiltered();
      expect(items, hasLength(1));
      expect(items.single.transaction.note, 'Lương tháng 11');

      notifier.clear();
      expect(container.read(transactionFilterProvider).isEmpty, isTrue);
      items = await readFiltered();
      expect(items, hasLength(3));
    });

    test(
      'add, update, delete cập nhật stream thời gian thực (I1, I5)',
      () async {
        final sub = container.listen(filteredTransactionsProvider, (_, _) {});
        addTearDown(sub.close);

        var items = await readFiltered();
        expect(items, hasLength(3));

        final actions = container.read(transactionActionsProvider);
        final newId = await actions.add(
          NewTransaction(
            transactionDate: DateTime(2026, 11, 20),
            type: TxType.expense,
            categoryId: foodCatId,
            amount: 45000,
            note: 'Cà phê sáng',
          ),
        );

        // Chờ Drift phát lại sự kiện mới qua Stream.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        items = container.read(filteredTransactionsProvider).requireValue;
        expect(items, hasLength(4));
        expect(items.first.transaction.amount, isA<int>());
        expect(items.first.transaction.note, 'Cà phê sáng');

        await actions.update(
          newId,
          NewTransaction(
            transactionDate: DateTime(2026, 11, 20),
            type: TxType.expense,
            categoryId: foodCatId,
            amount: 70000,
            note: 'Cà phê + bánh mì',
            isNotable: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        items = container.read(filteredTransactionsProvider).requireValue;
        final updated = items.firstWhere((e) => e.transaction.id == newId);
        expect(updated.transaction.amount, 70000);
        expect(updated.transaction.note, 'Cà phê + bánh mì');
        expect(updated.transaction.isNotable, isTrue);

        await actions.delete(newId);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        items = container.read(filteredTransactionsProvider).requireValue;
        expect(items, hasLength(3));
        expect(items.any((e) => e.transaction.id == newId), isFalse);
      },
    );
  });
}
