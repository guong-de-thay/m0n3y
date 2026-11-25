import '../../../data/database/app_database.dart';

const Object _sentinel = Object();

/// Bộ lọc đa chiều cho màn hình Danh sách Giao dịch.
class TransactionFilter {
  const TransactionFilter({
    this.from,
    this.to,
    this.categoryId,
    this.type,
    this.keyword,
  });

  final DateTime? from;
  final DateTime? to;
  final int? categoryId;
  final TxType? type;
  final String? keyword;

  bool get isEmpty =>
      from == null &&
      to == null &&
      categoryId == null &&
      type == null &&
      (keyword == null || keyword!.trim().isEmpty);

  TransactionFilter copyWith({
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? categoryId = _sentinel,
    Object? type = _sentinel,
    Object? keyword = _sentinel,
  }) {
    return TransactionFilter(
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      to: identical(to, _sentinel) ? this.to : to as DateTime?,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as int?,
      type: identical(type, _sentinel) ? this.type : type as TxType?,
      keyword: identical(keyword, _sentinel)
          ? this.keyword
          : keyword as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionFilter &&
        other.from == from &&
        other.to == to &&
        other.categoryId == categoryId &&
        other.type == type &&
        other.keyword == keyword;
  }

  @override
  int get hashCode => Object.hash(from, to, categoryId, type, keyword);
}
