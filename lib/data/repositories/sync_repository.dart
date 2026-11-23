import 'package:drift/drift.dart' show Value;

import '../../core/constants/default_categories.dart';
import '../database/app_database.dart';
import '../database/daos/categories_dao.dart';
import '../models/sync_models.dart';
import '../models/transaction_models.dart';

/// Ghi dữ liệu sync CSV vào DB. Chỉ tầng `lib/data/` được đụng DB.
class SyncRepository {
  SyncRepository(this._db);

  final AppDatabase _db;

  /// Ghi `sync_batches` + toàn bộ giao dịch trong MỘT `db.transaction`.
  /// Lỗi ở bất kỳ dòng nào thì rollback hết và ném lại lỗi; khi đó caller
  /// KHÔNG được động vào file CSV (bất biến I2).
  ///
  /// `transaction_date` lấy đúng ngày trong CSV, `created_at` là lúc sync (I3).
  Future<SyncImportOutcome> importRows(
    List<SyncImportRow> rows, {
    required int totalRows,
    String? errorLog,
  }) {
    return _db.transaction(() async {
      final batchId = await _db
          .into(_db.syncBatches)
          .insert(
            SyncBatchesCompanion.insert(
              totalRows: Value(totalRows),
              importedRows: Value(rows.length),
              status: errorLog == null
                  ? SyncStatus.success
                  : SyncStatus.partial,
              errorLog: Value(errorLog),
            ),
          );

      final categoryIds = <String, int>{};
      final created = <String>[];
      final items = <NewTransaction>[];

      for (final r in rows) {
        // Tên rỗng rơi vào "Khác" giống `getOrCreateByName`.
        final name = r.categoryName.trim().isEmpty
            ? fallbackCategoryName
            : r.categoryName.trim();
        final key = '${r.type.name}|${CategoriesDao.normalize(name)}';
        var id = categoryIds[key];
        if (id == null) {
          final existed = await _db.categoriesDao.findByName(name, r.type);
          id = await _db.categoriesDao.getOrCreateByName(
            name: name,
            type: r.type,
          );
          if (existed == null) created.add(name);
          categoryIds[key] = id;
        }
        items.add(
          NewTransaction(
            transactionDate: r.date,
            type: r.type,
            categoryId: id,
            amount: r.amount,
            note: r.note,
            isNotable: r.isNotable,
            source: TxSource.icloudCsv,
            syncBatchId: batchId,
          ),
        );
      }

      await _db.transactionsDao.insertMany(items);
      return SyncImportOutcome(
        batchId: batchId,
        importedRows: items.length,
        newCategories: created,
      );
    });
  }
}
