import 'package:drift/drift.dart';

import '../../../core/constants/default_categories.dart';
import '../../../core/utils/year_month.dart';
import '../../models/transaction_models.dart';
import '../app_database.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  // ---------------------------------------------------------------- Ghi

  /// Thêm giao dịch. `transaction_date` được cắt về 00:00 và `year_month` tự
  /// tính ở đây (không để tầng khác tự điền).
  Future<int> insertTransaction(NewTransaction t) {
    return into(transactions).insert(_toCompanion(t));
  }

  /// Thêm hàng loạt — gọi bên trong `db.transaction()` của sync CSV.
  Future<void> insertMany(List<NewTransaction> items) async {
    await batch((b) {
      b.insertAll(transactions, items.map(_toCompanion).toList());
    });
  }

  /// Sửa giao dịch; `year_month` được tính lại theo `transaction_date` mới.
  Future<bool> updateTransaction(int id, NewTransaction t) async {
    final updated = await (update(
      transactions,
    )..where((x) => x.id.equals(id))).write(_toCompanion(t));
    return updated > 0;
  }

  Future<int> deleteTransaction(int id) {
    return (delete(transactions)..where((x) => x.id.equals(id))).go();
  }

  TransactionsCompanion _toCompanion(NewTransaction t) {
    if (t.amount <= 0) {
      throw ArgumentError.value(t.amount, 'amount', 'Số tiền phải > 0');
    }
    final date = dateOnly(t.transactionDate);
    return TransactionsCompanion(
      transactionDate: Value(date),
      yearMonth: Value(yearMonthOf(date)),
      type: Value(t.type),
      categoryId: Value(t.categoryId),
      amount: Value(t.amount),
      note: Value(t.note),
      isNotable: Value(t.isNotable),
      source: Value(t.source),
      syncBatchId: Value(t.syncBatchId),
      merchantName: Value(t.merchantName),
      receiptImagePath: Value(t.receiptImagePath),
      externalRef: Value(t.externalRef),
    );
  }

  // --------------------------------------------------------------- Đọc

  JoinedSelectStatement<HasResultSet, dynamic> _joined() {
    return select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);
  }

  TransactionWithCategory _map(TypedResult r) => TransactionWithCategory(
    r.readTable(transactions),
    r.readTable(categories),
  );

  /// Stream danh sách giao dịch (mới nhất trước) với bộ lọc đa chiều.
  ///
  /// - [from]/[to]: khoảng ngày, gồm cả hai đầu.
  /// - [keyword]: lọc ở phía Dart (không nối chuỗi SQL), không phân biệt
  ///   hoa/thường & hỗ trợ tiếng Việt có dấu; tìm trong ghi chú, tên danh mục
  ///   và tên cửa hàng.
  Stream<List<TransactionWithCategory>> watchFiltered({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    TxType? type,
    String? keyword,
  }) {
    final q = _joined();
    final conds = <Expression<bool>>[];
    if (from != null) {
      conds.add(
        transactions.transactionDate.isBiggerOrEqualValue(dateOnly(from)),
      );
    }
    if (to != null) {
      final endExclusive = dateOnly(to).add(const Duration(days: 1));
      conds.add(transactions.transactionDate.isSmallerThanValue(endExclusive));
    }
    if (categoryId != null) {
      conds.add(transactions.categoryId.equals(categoryId));
    }
    if (type != null) conds.add(transactions.type.equalsValue(type));
    if (conds.isNotEmpty) q.where(conds.reduce((a, b) => a & b));
    q.orderBy([
      OrderingTerm.desc(transactions.transactionDate),
      OrderingTerm.desc(transactions.id),
    ]);

    final kw = keyword?.trim().toLowerCase() ?? '';
    return q.watch().map((rows) {
      final list = rows.map(_map).toList();
      if (kw.isEmpty) return list;
      return list.where((t) {
        return t.transaction.note.toLowerCase().contains(kw) ||
            t.category.name.toLowerCase().contains(kw) ||
            (t.transaction.merchantName?.toLowerCase().contains(kw) ?? false);
      }).toList();
    });
  }

  /// Giao dịch của một tháng (`yearMonth` dạng `YYYY-MM`), cũ → mới.
  Stream<List<TransactionWithCategory>> watchMonth(String yearMonth) {
    final q = _joined()
      ..where(transactions.yearMonth.equals(yearMonth))
      ..orderBy([
        OrderingTerm.asc(transactions.transactionDate),
        OrderingTerm.asc(transactions.id),
      ]);
    return q.watch().map((rows) => rows.map(_map).toList());
  }

  /// Gom giao dịch của tháng theo từng ngày (cho Calendar View).
  Stream<Map<DateTime, DailyCashflow>> watchDailyCashflow(String yearMonth) {
    return watchMonth(yearMonth).map((list) {
      final byDay = <DateTime, List<TransactionWithCategory>>{};
      for (final t in list) {
        byDay
            .putIfAbsent(dateOnly(t.transaction.transactionDate), () => [])
            .add(t);
      }
      return {
        for (final e in byDay.entries)
          e.key: DailyCashflow(
            date: e.key,
            income: _sum(e.value, TxType.income),
            expense: _sum(e.value, TxType.expense),
            transactions: e.value,
          ),
      };
    });
  }

  int _sum(List<TransactionWithCategory> l, TxType type) => l
      .where((t) => t.transaction.type == type)
      .fold<int>(0, (s, t) => s + t.transaction.amount);

  /// Tổng thu/chi của một tháng — SUM thực hiện trong SQLite trên INTEGER.
  Stream<MonthTotals> watchMonthTotals(String yearMonth) {
    return _watchTotals(where: transactions.yearMonth.equals(yearMonth));
  }

  /// Tổng thu/chi toàn thời gian (số dư = thu - chi).
  Stream<MonthTotals> watchAllTimeTotals() => _watchTotals();

  /// Tổng thu/chi từng tháng trong khoảng [fromYm]..[toYm] (cả hai đầu, dạng
  /// `YYYY-MM`), cũ → mới, cho biểu đồ cột Thu–Chi. Tháng không có giao dịch
  /// vẫn được trả về với 0 để trục thời gian liên tục. Gom theo `year_month`
  /// (I3) và cộng trong SQLite trên INTEGER (I1).
  Stream<List<MonthlySummary>> watchMonthlySeries(String fromYm, String toYm) {
    final months = _monthsBetween(fromYm, toYm);
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([transactions.yearMonth, transactions.type, total])
      ..where(
        transactions.yearMonth.isBiggerOrEqualValue(fromYm) &
            transactions.yearMonth.isSmallerOrEqualValue(toYm),
      )
      ..groupBy([transactions.yearMonth, transactions.type]);
    return q.watch().map((rows) {
      final income = <String, int>{};
      final expense = <String, int>{};
      for (final r in rows) {
        final ym = r.read(transactions.yearMonth)!;
        final sum = (r.read(total) ?? 0).toInt();
        switch (r.readWithConverter(transactions.type)) {
          case TxType.income:
            income[ym] = sum;
          case TxType.expense:
            expense[ym] = sum;
          case null:
            break;
        }
      }
      return [
        for (final ym in months)
          MonthlySummary(
            yearMonth: ym,
            income: income[ym] ?? 0,
            expense: expense[ym] ?? 0,
          ),
      ];
    });
  }

  /// Danh sách `YYYY-MM` từ [fromYm] đến [toYm]; rỗng nếu [fromYm] > [toYm].
  List<String> _monthsBetween(String fromYm, String toYm) {
    final re = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$');
    final a = re.firstMatch(fromYm);
    final b = re.firstMatch(toYm);
    if (a == null || b == null) {
      throw ArgumentError('Tháng phải có dạng YYYY-MM: $fromYm, $toYm');
    }
    var y = int.parse(a.group(1)!);
    var m = int.parse(a.group(2)!);
    final endY = int.parse(b.group(1)!);
    final endM = int.parse(b.group(2)!);
    final out = <String>[];
    while (y < endY || (y == endY && m <= endM)) {
      out.add(yearMonthOf(DateTime(y, m)));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return out;
  }

  Stream<MonthTotals> _watchTotals({Expression<bool>? where}) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([transactions.type, total])
      ..groupBy([transactions.type]);
    if (where != null) q.where(where);
    return q.watch().map((rows) {
      var income = 0;
      var expense = 0;
      for (final r in rows) {
        final sum = (r.read(total) ?? 0).toInt();
        final type = r.readWithConverter(transactions.type);
        if (type == TxType.income) income = sum;
        if (type == TxType.expense) expense = sum;
      }
      return MonthTotals(income: income, expense: expense);
    });
  }

  /// Tổng theo danh mục của một loại trong tháng, lớn → nhỏ (PieChart).
  Stream<List<CategoryTotal>> watchCategoryBreakdown(
    String yearMonth,
    TxType type,
  ) {
    final total = transactions.amount.sum();
    final q = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);
    // Dùng join + groupBy trên bảng đã join để lấy cả CategoryRow.
    final grouped = q
      ..addColumns([total])
      ..where(
        transactions.yearMonth.equals(yearMonth) &
            transactions.type.equalsValue(type),
      )
      ..groupBy([categories.id])
      ..orderBy([OrderingTerm.desc(total)]);
    return grouped.watch().map(
      (rows) => rows
          .map(
            (r) => CategoryTotal(
              category: r.readTable(categories),
              total: (r.read(total) ?? 0).toInt(),
            ),
          )
          .toList(),
    );
  }

  /// Visual Notes (Business Rule #4): giao dịch được gắn `is_notable`, hoặc
  /// khoản chi có ghi chú và số tiền >= [threshold]. Lớn nhất trước.
  Stream<List<TransactionWithCategory>> watchVisualNotes(
    String yearMonth, {
    int threshold = notableAmountThreshold,
  }) {
    final q = _joined()
      ..where(
        transactions.yearMonth.equals(yearMonth) &
            (transactions.isNotable.equals(true) |
                (transactions.type.equalsValue(TxType.expense) &
                    transactions.note.equals('').not() &
                    transactions.amount.isBiggerOrEqualValue(threshold))),
      )
      ..orderBy([OrderingTerm.desc(transactions.amount)]);
    return q.watch().map((rows) => rows.map(_map).toList());
  }

  /// Toàn bộ giao dịch cho xuất Excel: `transaction_date ASC, id ASC`.
  Future<List<TransactionWithCategory>> getAllForExport() async {
    final q = _joined()
      ..orderBy([
        OrderingTerm.asc(transactions.transactionDate),
        OrderingTerm.asc(transactions.id),
      ]);
    final rows = await q.get();
    return rows.map(_map).toList();
  }

  Future<int> countAll() async {
    final c = transactions.id.count();
    final row = await (selectOnly(transactions)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }
}
