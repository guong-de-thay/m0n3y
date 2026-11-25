import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/default_categories.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/database/app_database.dart' show TxType;
import '../../../../data/models/transaction_models.dart';
import '../../providers/dashboard_provider.dart';

/// Khu vực "Visual Notes" (Business Rule #4): giao dịch được đánh dấu đáng chú
/// ý, hoặc khoản chi có ghi chú và lớn từ [notableAmountThreshold] trở lên.
class VisualNotesBoard extends ConsumerWidget {
  const VisualNotesBoard({super.key});

  static const double _minNoteWidth = 240;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(dashboardVisualNotesProvider);
    final monthLabel = formatMonthLabel(ref.watch(dashboardYearMonthProvider));
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Visual Notes — tháng $monthLabel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notesAsync.asData?.value case final notes?
                    when notes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _CountBadge(count: notes.length),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Khoản chi từ ${formatVnd(notableAmountThreshold)} có ghi chú, '
              'hoặc giao dịch được đánh dấu đáng chú ý.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            notesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được Visual Notes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Tháng này chưa có ghi chú đáng chú ý nào.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        ((constraints.maxWidth + _gap) ~/
                                (_minNoteWidth + _gap))
                            .clamp(1, 4);
                    final width =
                        (constraints.maxWidth - _gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: _gap,
                      runSpacing: _gap,
                      children: [
                        for (final n in notes)
                          SizedBox(
                            width: width,
                            child: _NoteTile(item: n),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.item});

  final TransactionWithCategory item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = item.transaction;
    final categoryColor = Color(item.category.colorHex);
    final isIncome = tx.type == TxType.income;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final isLarge = !isIncome && tx.amount >= notableAmountThreshold;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: categoryColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tx.isNotable) ...[
                const Icon(Icons.star, size: 16, color: AppColors.notable),
                const SizedBox(width: 4),
              ],
              if (isLarge) const _Tag(label: 'Chi lớn'),
              const Spacer(),
              Text(
                formatDate(tx.transactionDate),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${isIncome ? '+' : '-'}${formatVnd(tx.amount)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tx.note.isEmpty ? '(Không có ghi chú)' : tx.note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.category.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.expense, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
