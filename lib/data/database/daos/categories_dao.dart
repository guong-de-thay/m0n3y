import 'package:drift/drift.dart';

import '../../../core/constants/default_categories.dart';
import '../app_database.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  /// Khóa so khớp danh mục: `trim().toLowerCase()` (bất biến I4).
  static String normalize(String name) => name.trim().toLowerCase();

  Stream<List<CategoryRow>> watchAll({TxType? type}) {
    final q = select(categories);
    if (type != null) q.where((c) => c.type.equalsValue(type));
    q.orderBy([(c) => OrderingTerm.asc(c.id)]);
    return q.watch();
  }

  Future<List<CategoryRow>> getAll({TxType? type}) {
    final q = select(categories);
    if (type != null) q.where((c) => c.type.equalsValue(type));
    q.orderBy([(c) => OrderingTerm.asc(c.id)]);
    return q.get();
  }

  Future<CategoryRow?> findByName(String name, TxType type) {
    return (select(categories)..where(
          (c) =>
              c.normalizedName.equals(normalize(name)) &
              c.type.equalsValue(type),
        ))
        .getSingleOrNull();
  }

  /// Tìm danh mục theo tên đã chuẩn hóa + loại; chưa có thì tự tạo (màu/icon
  /// lấy từ bảng màu mặc định) và trả về `id`. Tên rỗng → "Khác".
  ///
  /// Idempotent: gọi nhiều lần với `"Ăn uống"`, `"ăn uống "`, `"ĂN UỐNG"`
  /// luôn trả về cùng một `id`.
  Future<int> getOrCreateByName({
    required String name,
    required TxType type,
  }) async {
    final trimmed = name.trim();
    final displayName = trimmed.isEmpty ? fallbackCategoryName : trimmed;

    final existing = await findByName(displayName, type);
    if (existing != null) return existing.id;

    final count =
        await (selectOnly(categories)..addColumns([categories.id.count()]))
            .map((r) => r.read(categories.id.count()) ?? 0)
            .getSingle();

    await into(categories).insert(
      CategoriesCompanion.insert(
        name: displayName,
        normalizedName: normalize(displayName),
        type: type,
        colorHex: autoCategoryPalette[count % autoCategoryPalette.length],
        iconName: autoCategoryIcon,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // Đọc lại để an toàn nếu bị ignore do UNIQUE(normalized_name, type).
    final created = await findByName(displayName, type);
    return created!.id;
  }
}
