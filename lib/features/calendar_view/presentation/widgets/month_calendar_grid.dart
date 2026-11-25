import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/models/transaction_models.dart';
import '../../../transactions/domain/transaction_formatters.dart';
import '../../providers/calendar_provider.dart';

const Color _incomeColor = Color(0xFF2E7D32);
const Color _expenseColor = Color(0xFFC62828);

const List<String> _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Panel bên trái (65%): thanh chuyển tháng và lưới lịch hiển thị `+Thu / -Chi`.
class MonthCalendarGrid extends ConsumerWidget {
  const MonthCalendarGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewState = ref.watch(calendarViewProvider);
    final today = ref.watch(calendarTodayProvider);
    final cashflowAsync = ref.watch(monthlyDailyCashflowProvider);
    final monthTotals = ref.watch(calendarMonthTotalsProvider);
    final notifier = ref.read(calendarViewProvider.notifier);

    final focusedMonth = viewState.focusedMonth;
    final monthLabel =
        'Tháng ${focusedMonth.month.toString().padLeft(2, '0')}/${focusedMonth.year}';

    final dailyMap =
        cashflowAsync.asData?.value ?? const <DateTime, DailyCashflow>{};

    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final leadingEmpty = focusedMonth.weekday - 1;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;
    final rowCount = totalCells ~/ 7;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Tháng trước',
                      onPressed: notifier.previousMonth,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    SizedBox(
                      width: 148,
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tháng sau',
                      onPressed: notifier.nextMonth,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: notifier.goToToday,
                      child: const Text('Hôm nay'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Thu: +${formatVnd(monthTotals.income)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _incomeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Chi: -${formatVnd(monthTotals.expense)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            child: Row(
              children: [
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          if (cashflowAsync.isLoading && !cashflowAsync.hasValue)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (cashflowAsync.hasError && !cashflowAsync.hasValue)
            Expanded(
              child: Center(
                child: Text(
                  'Không thể tải dữ liệu lịch thu chi. Vui lòng thử lại.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (var row = 0; row < rowCount; row++)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var col = 0; col < 7; col++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: _buildCell(
                                    cellIndex: row * 7 + col,
                                    leadingEmpty: leadingEmpty,
                                    daysInMonth: daysInMonth,
                                    focusedMonth: focusedMonth,
                                    selectedDate: viewState.selectedDate,
                                    today: today,
                                    dailyMap: dailyMap,
                                    onSelect: notifier.selectDate,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required int cellIndex,
    required int leadingEmpty,
    required int daysInMonth,
    required DateTime focusedMonth,
    required DateTime selectedDate,
    required DateTime today,
    required Map<DateTime, DailyCashflow> dailyMap,
    required ValueChanged<DateTime> onSelect,
  }) {
    final dayNumber = cellIndex - leadingEmpty + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox.shrink();
    }

    final date = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
    return _DayCell(
      date: date,
      isSelected: date == selectedDate,
      isToday: date == today,
      cashflow: dailyMap[date],
      onTap: () => onSelect(date),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.cashflow,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final DailyCashflow? cashflow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIncome = (cashflow?.income ?? 0) > 0;
    final hasExpense = (cashflow?.expense ?? 0) > 0;

    final borderColor = isSelected
        ? theme.colorScheme.primary
        : isToday
        ? theme.colorScheme.primary.withValues(alpha: 0.6)
        : theme.dividerColor;

    final backgroundColor = isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
        : isToday
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.14)
        : theme.colorScheme.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('calendar_day_${date.year}_${date.month}_${date.day}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: isToday
                        ? BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (hasIncome || hasExpense)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasIncome) const _CashflowDot(color: _incomeColor),
                        if (hasIncome && hasExpense) const SizedBox(width: 3),
                        if (hasExpense)
                          const _CashflowDot(color: _expenseColor),
                      ],
                    ),
                ],
              ),
              const Spacer(),
              if (hasIncome)
                Text(
                  '+${formatVnd(cashflow!.income)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _incomeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (hasExpense)
                Text(
                  '-${formatVnd(cashflow!.expense)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _expenseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashflowDot extends StatelessWidget {
  const _CashflowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
