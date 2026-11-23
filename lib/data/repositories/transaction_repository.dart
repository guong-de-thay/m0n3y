import '../database/app_database.dart';
import '../database/daos/categories_dao.dart';
import '../database/daos/transactions_dao.dart';
import '../models/transaction_models.dart';

/// Cổng duy nhất để tầng Providers/UI đọc-ghi dữ liệu giao dịch.
/// UI KHÔNG được gọi DAO hay viết SQL trực tiếp.
class TransactionRepository {
  TransactionRepository(AppDatabase db)
    : _tx = db.transactionsDao,
      _cat = db.categoriesDao;

  final TransactionsDao _tx;
  final CategoriesDao _cat;

  // Danh mục
  Stream<List<CategoryRow>> watchCategories({TxType? type}) =>
      _cat.watchAll(type: type);
  Future<int> getOrCreateCategory(String name, TxType type) =>
      _cat.getOrCreateByName(name: name, type: type);

  // Giao dịch — CRUD
  Future<int> add(NewTransaction t) => _tx.insertTransaction(t);
  Future<bool> update(int id, NewTransaction t) => _tx.updateTransaction(id, t);
  Future<int> delete(int id) => _tx.deleteTransaction(id);

  // Giao dịch — stream cho Transactions screen
  Stream<List<TransactionWithCategory>> watchFiltered({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    TxType? type,
    String? keyword,
  }) => _tx.watchFiltered(
    from: from,
    to: to,
    categoryId: categoryId,
    type: type,
    keyword: keyword,
  );

  // Calendar
  Stream<Map<DateTime, DailyCashflow>> watchDailyCashflow(String yearMonth) =>
      _tx.watchDailyCashflow(yearMonth);

  // Dashboard
  Stream<MonthTotals> watchMonthTotals(String yearMonth) =>
      _tx.watchMonthTotals(yearMonth);
  Stream<MonthTotals> watchAllTimeTotals() => _tx.watchAllTimeTotals();
  Stream<List<CategoryTotal>> watchCategoryBreakdown(
    String yearMonth,
    TxType type,
  ) => _tx.watchCategoryBreakdown(yearMonth, type);
  Stream<List<TransactionWithCategory>> watchVisualNotes(String yearMonth) =>
      _tx.watchVisualNotes(yearMonth);

  // Excel
  Future<List<TransactionWithCategory>> getAllForExport() =>
      _tx.getAllForExport();
}
