import '../database/app_database.dart';

/// Dữ liệu để tạo/sửa một giao dịch. `year_month` KHÔNG nằm ở đây: DAO tự
/// tính từ [transactionDate] (IMPLEMENTATION_PLAN.md mục 4.2).
class NewTransaction {
  const NewTransaction({
    required this.transactionDate,
    required this.type,
    required this.categoryId,
    required this.amount,
    this.note = '',
    this.isNotable = false,
    this.source = TxSource.manual,
    this.syncBatchId,
    this.merchantName,
    this.receiptImagePath,
    this.externalRef,
  });

  final DateTime transactionDate;
  final TxType type;
  final int categoryId;

  /// VNĐ, số nguyên dương (bất biến I1).
  final int amount;
  final String note;
  final bool isNotable;
  final TxSource source;
  final int? syncBatchId;
  final String? merchantName;
  final String? receiptImagePath;
  final String? externalRef;
}

/// Một giao dịch kèm danh mục (kết quả join cho UI/Excel).
class TransactionWithCategory {
  const TransactionWithCategory(this.transaction, this.category);

  final TransactionRow transaction;
  final CategoryRow category;
}

/// Tổng thu/chi của một tháng (VNĐ, int).
class MonthTotals {
  const MonthTotals({this.income = 0, this.expense = 0});

  final int income;
  final int expense;
  int get balance => income - expense;
}

/// Tổng thu/chi của một tháng trong chuỗi nhiều tháng (cho biểu đồ cột).
class MonthlySummary {
  const MonthlySummary({
    required this.yearMonth,
    this.income = 0,
    this.expense = 0,
  });

  /// Dạng `YYYY-MM`, tính từ `transaction_date` (I3).
  final String yearMonth;
  final int income;
  final int expense;
  int get balance => income - expense;
}

/// Tổng tiền theo danh mục (cho PieChart).
class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});

  final CategoryRow category;
  final int total;
}

/// Tổng thu/chi của một ngày (cho Calendar View).
class DailyCashflow {
  const DailyCashflow({
    required this.date,
    required this.income,
    required this.expense,
    required this.transactions,
  });

  final DateTime date;
  final int income;
  final int expense;
  final List<TransactionWithCategory> transactions;
}
