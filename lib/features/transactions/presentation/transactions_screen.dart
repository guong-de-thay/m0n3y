import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/transaction_models.dart';
import '../domain/transaction_formatters.dart';
import '../providers/transactions_provider.dart';
import 'widgets/transaction_filter_bar.dart';
import 'widgets/transaction_form_dialog.dart';

const Color _incomeColor = Color(0xFF2E7D32);
const Color _expenseColor = Color(0xFFC62828);

/// Màn hình Quản lý Giao dịch cho Desktop:
/// thanh lọc đa chiều, tóm tắt nhanh và bảng danh sách cập nhật thời gian thực.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  Future<void> _openForm(
    BuildContext context, {
    TransactionWithCategory? initial,
  }) async {
    final saved = await showTransactionFormDialog(context, initial: initial);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              initial == null
                  ? 'Đã thêm giao dịch mới.'
                  : 'Đã cập nhật giao dịch.',
            ),
          ),
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategory item,
  ) async {
    final confirmed = await showDeleteTransactionDialog(context, item);
    if (confirmed != true) return;

    await ref.read(transactionActionsProvider).delete(item.transaction.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã xóa giao dịch.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionFilterBar(onAddPressed: () => _openForm(context)),
          const SizedBox(height: 16),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Không thể tải danh sách giao dịch. Vui lòng thử lại.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(
                    hasFilter: !filter.isEmpty,
                    onClearFilter: () =>
                        ref.read(transactionFilterProvider.notifier).clear(),
                    onAddPressed: () => _openForm(context),
                  );
                }

                // Bất biến I1: tính tổng hoàn toàn bằng số nguyên int (VNĐ).
                var totalIncome = 0;
                var totalExpense = 0;
                for (final item in items) {
                  if (item.transaction.type == TxType.income) {
                    totalIncome += item.transaction.amount;
                  } else {
                    totalExpense += item.transaction.amount;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(
                      count: items.length,
                      totalIncome: totalIncome,
                      totalExpense: totalExpense,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _TransactionsTable(
                        items: items,
                        onEdit: (item) => _openForm(context, initial: item),
                        onDelete: (item) => _confirmDelete(context, ref, item),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.count,
    required this.totalIncome,
    required this.totalExpense,
  });

  final int count;
  final int totalIncome;
  final int totalExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = totalIncome - totalExpense;

    return Wrap(
      spacing: 24,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Hiển thị $count giao dịch',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          'Thu: +${formatVnd(totalIncome)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _incomeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Chi: -${formatVnd(totalExpense)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _expenseColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Chênh lệch: ${formatVnd(balance)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TransactionWithCategory> items;
  final ValueChanged<TransactionWithCategory> onEdit;
  final ValueChanged<TransactionWithCategory> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                SizedBox(width: 112, child: Text('Ngày', style: headerStyle)),
                SizedBox(width: 76, child: Text('Loại', style: headerStyle)),
                Expanded(flex: 2, child: Text('Danh mục', style: headerStyle)),
                Expanded(flex: 3, child: Text('Ghi chú', style: headerStyle)),
                SizedBox(
                  width: 150,
                  child: Text(
                    'Số tiền',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    'Thao tác',
                    textAlign: TextAlign.center,
                    style: headerStyle,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, index) {
                final item = items[index];
                final tx = item.transaction;
                final cat = item.category;
                final isIncome = tx.type == TxType.income;
                final amountColor = isIncome ? _incomeColor : _expenseColor;
                final sign = isIncome ? '+' : '-';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        child: Text(formatDate(tx.transactionDate)),
                      ),
                      SizedBox(
                        width: 76,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: amountColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              formatTxType(tx.type),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: amountColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(cat.colorHex),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            if (tx.isNotable) ...[
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                tx.note.isEmpty ? '—' : tx.note,
                                overflow: TextOverflow.ellipsis,
                                style: tx.note.isEmpty
                                    ? TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          '$sign${formatVnd(tx.amount)}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: amountColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Sửa',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => onEdit(item),
                            ),
                            IconButton(
                              tooltip: 'Xóa',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: () => onDelete(item),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilter,
    required this.onClearFilter,
    required this.onAddPressed,
  });

  final bool hasFilter;
  final VoidCallback onClearFilter;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'Không có giao dịch nào khớp bộ lọc'
                : 'Chưa có giao dịch nào',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (hasFilter)
            OutlinedButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Xóa bộ lọc'),
            )
          else
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm giao dịch đầu tiên'),
            ),
        ],
      ),
    );
  }
}
