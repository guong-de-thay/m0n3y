import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/transaction_models.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../domain/transaction_filter.dart';

/// Quản lý trạng thái bộ lọc của màn hình Giao dịch.
class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void setFrom(DateTime? from) {
    state = state.copyWith(from: from);
  }

  void setTo(DateTime? to) {
    state = state.copyWith(to: to);
  }

  void setType(TxType? type) {
    if (type == state.type) return;
    // Khi đổi loại Thu/Chi, reset danh mục để tránh giữ danh mục khác loại.
    state = state.copyWith(type: type, categoryId: null);
  }

  void setCategoryId(int? categoryId) {
    state = state.copyWith(categoryId: categoryId);
  }

  void setKeyword(String? keyword) {
    final normalized = keyword?.trim();
    state = state.copyWith(
      keyword: (normalized == null || normalized.isEmpty) ? null : normalized,
    );
  }

  void clear() {
    state = const TransactionFilter();
  }
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
      TransactionFilterNotifier.new,
    );

/// Stream danh sách giao dịch đã lọc (tự cập nhật khi DB thay đổi - I5).
final filteredTransactionsProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      final filter = ref.watch(transactionFilterProvider);
      final repo = ref.watch(transactionRepositoryProvider);
      return repo.watchFiltered(
        from: filter.from,
        to: filter.to,
        categoryId: filter.categoryId,
        type: filter.type,
        keyword: filter.keyword,
      );
    });

/// Cổng thao tác thêm/sửa/xóa giao dịch từ UI qua [TransactionRepository].
class TransactionActions {
  TransactionActions(this._repo);

  final TransactionRepository _repo;

  Future<int> add(NewTransaction transaction) => _repo.add(transaction);

  Future<bool> update(int id, NewTransaction transaction) =>
      _repo.update(id, transaction);

  Future<int> delete(int id) => _repo.delete(id);
}

final transactionActionsProvider = Provider<TransactionActions>(
  (ref) => TransactionActions(ref.watch(transactionRepositoryProvider)),
);
