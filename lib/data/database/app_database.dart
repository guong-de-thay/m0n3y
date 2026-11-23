import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/default_categories.dart';
import 'daos/categories_dao.dart';
import 'daos/transactions_dao.dart';

part 'app_database.g.dart';

/// Loại giao dịch / danh mục. Lưu DB dạng text: `income` | `expense`.
enum TxType { income, expense }

/// Nguồn giao dịch. Lưu DB dạng text: `manual` | `icloud_csv` | `receipt_ocr`.
enum TxSource {
  manual('manual'),
  icloudCsv('icloud_csv'),
  receiptOcr('receipt_ocr');

  const TxSource(this.dbValue);
  final String dbValue;
}

/// Trạng thái một phiên sync. Lưu DB: `success` | `partial` | `failed`.
enum SyncStatus { success, partial, failed }

class TxSourceConverter extends TypeConverter<TxSource, String> {
  const TxSourceConverter();

  @override
  TxSource fromSql(String fromDb) =>
      TxSource.values.firstWhere((s) => s.dbValue == fromDb);

  @override
  String toSql(TxSource value) => value.dbValue;
}

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// `name.trim().toLowerCase()` — khóa so khớp khi sync CSV (bất biến I4).
  TextColumn get normalizedName => text()();
  TextColumn get type => textEnum<TxType>()();
  IntColumn get colorHex => integer()();
  TextColumn get iconName => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {normalizedName, type},
  ];
}

@DataClassName('SyncBatchRow')
class SyncBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get totalRows => integer().withDefault(const Constant(0))();
  IntColumn get importedRows => integer().withDefault(const Constant(0))();
  TextColumn get status => textEnum<SyncStatus>()();
  TextColumn get errorLog => text().nullable()();
}

@DataClassName('TransactionRow')
@TableIndex.sql(
  'CREATE INDEX idx_transactions_date ON transactions (transaction_date DESC)',
)
@TableIndex(name: 'idx_transactions_ym_type', columns: {#yearMonth, #type})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Ngày thực tế phát sinh (hỗ trợ backdate). Mọi báo cáo tính theo cột này.
  DateTimeColumn get transactionDate => dateTime()();

  /// `YYYY-MM`, do [TransactionsDao] tự tính từ `transactionDate`.
  TextColumn get yearMonth => text()();
  TextColumn get type => textEnum<TxType>()();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// VNĐ, INTEGER — TUYỆT ĐỐI KHÔNG dùng Real (bất biến I1).
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get isNotable => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().map(const TxSourceConverter())();
  IntColumn get syncBatchId =>
      integer().nullable().references(SyncBatches, #id)();

  // Dự phòng cho giai đoạn 2 (OCR hóa đơn).
  TextColumn get merchantName => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  TextColumn get externalRef => text().nullable()();

  /// Thời điểm bản ghi được lưu vào DB (KHÔNG dùng cho báo cáo).
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [Categories, Transactions, SyncBatches],
  daos: [CategoriesDao, TransactionsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// DB thật: file `m0n3y.sqlite` trong thư mục dữ liệu ứng dụng của user.
  factory AppDatabase.persistent() => AppDatabase(_openConnection());

  /// DB trong RAM, dùng cho test.
  factory AppDatabase.inMemory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultCategories();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now();
    Future<void> seed(List<DefaultCategory> items, TxType type) async {
      for (final c in items) {
        await into(categories).insert(
          CategoriesCompanion.insert(
            name: c.name,
            normalizedName: CategoriesDao.normalize(c.name),
            type: type,
            colorHex: c.colorHex,
            iconName: c.iconName,
            isDefault: const Value(true),
            createdAt: Value(now),
          ),
        );
      }
    }

    await seed(defaultExpenseCategories, TxType.expense);
    await seed(defaultIncomeCategories, TxType.income);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'm0n3y.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
