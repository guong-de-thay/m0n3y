import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../repositories/settings_repository.dart';
import '../repositories/transaction_repository.dart';

/// Phải được override trong `main()` bằng instance đã khởi tạo.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.persistent();
  ref.onDispose(db.close);
  return db;
});

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Danh mục theo loại — Stream, UI tự cập nhật khi sync tạo danh mục mới.
final categoriesProvider = StreamProvider.family<List<CategoryRow>, TxType?>((
  ref,
  type,
) {
  return ref.watch(transactionRepositoryProvider).watchCategories(type: type);
});
