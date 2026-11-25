import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/database/app_database.dart' show TxType;
import '../../../../data/models/transaction_models.dart';
import '../../../transactions/domain/transaction_formatters.dart';
import '../../providers/calendar_provider.dart';

const Color _incomeColor = Color(0xFF2E7D32);
const Color _expenseColor = Color(0xFFC62828);

/// Panel bên phải (35%): danh sách chi tiết thu/chi của ngày đang chọn.
class DayTransactionsPanel extends ConsumerWidget {
  const DayTransactionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(
      calendarViewProvider.select((state) => state.selectedDate),
    );
    final today = ref.watch(calendarTodayProvider);
    final monthlyAsync = ref.watch(monthlyDailyCashflowProvider);
    final dayCashflow = ref.watch(selectedDayCashflowProvider);

    final isToday = selectedDate == today;
    final items =
        dayCashflow?.transactions ?? const <TransactionWithCategory>[];
    final dayIncome = dayCashflow?.income ?? 0;
    final dayExpense = dayCashflow?.expense ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ngày ${formatDate(selectedDate)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Hôm nay',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Thu: +${formatVnd(dayIncome)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _incomeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Chi: -${formatVnd(dayExpense)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _expenseColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: monthlyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Không thể tải chi tiết giao dịch ngày này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              data: (_) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 40,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Không có giao dịch nào',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ngày ${formatDate(selectedDate)} chưa có khoản thu chi nào.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(cat.colorHex),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cat.name,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (tx.isNotable) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber.shade700,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tx.note.isEmpty
                                      ? 'Không có ghi chú'
                                      : tx.note,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tx.note.isEmpty
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sign${formatVnd(tx.amount)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: amountColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatTxType(tx.type),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: amountColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
