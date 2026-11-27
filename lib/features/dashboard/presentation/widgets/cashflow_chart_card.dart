import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/transaction_models.dart';
import '../../providers/dashboard_provider.dart';

// Bất biến I1: mọi tổng tiền là int lấy từ DAO. Chỉ đổi sang double đúng lúc
// đưa vào fl_chart để vẽ (toY / value); không cộng trừ trên double.

/// Biểu đồ cột Thu–Chi [dashboardSeriesMonths] tháng gần nhất.
class CashflowBarChartCard extends ConsumerWidget {
  const CashflowBarChartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(dashboardMonthlySeriesProvider);
    final theme = Theme.of(context);

    return _ChartCard(
      title: 'Dòng tiền $dashboardSeriesMonths tháng gần nhất',
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: AppColors.income, label: 'Thu'),
          SizedBox(width: 12),
          _LegendDot(color: AppColors.expense, label: 'Chi'),
        ],
      ),
      child: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ErrorText('Không tải được biểu đồ dòng tiền.'),
        data: (series) {
          final maxValue = series.fold<int>(
            0,
            (m, s) => [m, s.income, s.expense].reduce((a, b) => a > b ? a : b),
          );
          if (maxValue == 0) {
            return const _EmptyText('Chưa có giao dịch trong 6 tháng này.');
          }
          final interval = _niceInterval(maxValue);
          final maxY = interval * ((maxValue + maxValue ~/ 10) ~/ interval + 1);
          final labelStyle = theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );

          return BarChart(
            BarChartData(
              maxY: maxY.toDouble(),
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval.toDouble(),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: interval.toDouble(),
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        formatVndCompact(value.round()),
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= series.length) {
                        return const SizedBox.shrink();
                      }
                      final isCurrent = i == series.length - 1;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          _axisMonthLabel(series[i].yearMonth, i == 0),
                          style: labelStyle?.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isCurrent
                                ? theme.colorScheme.onSurface
                                : labelStyle.color,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  maxContentWidth: 180,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final s = series[groupIndex];
                    final isIncome = rodIndex == 0;
                    final amount = isIncome ? s.income : s.expense;
                    return BarTooltipItem(
                      '${isIncome ? 'Thu' : 'Chi'} '
                      '${formatMonthLabel(s.yearMonth)}\n${formatVnd(amount)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < series.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      _rod(series[i].income, AppColors.income),
                      _rod(series[i].expense, AppColors.expense),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static BarChartRodData _rod(int amount, Color color) => BarChartRodData(
    toY: amount.toDouble(),
    color: color,
    width: 14,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );

  /// `T11`; kèm năm ở cột đầu tiên và tháng 1 để không nhầm năm.
  static String _axisMonthLabel(String yearMonth, bool isFirst) {
    final parts = yearMonth.split('-');
    final month = int.parse(parts[1]);
    return isFirst || month == 1 ? 'T$month/${parts[0]}' : 'T$month';
  }
}

/// PieChart cơ cấu chi tiêu theo danh mục của tháng đang xem.
class ExpenseBreakdownCard extends ConsumerWidget {
  const ExpenseBreakdownCard({super.key});

  /// Số danh mục hiển thị riêng; phần còn lại gộp thành "Danh mục khác".
  static const int maxSlices = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(dashboardExpenseBreakdownProvider);
    final monthLabel = formatMonthLabel(ref.watch(dashboardYearMonthProvider));
    final theme = Theme.of(context);

    return _ChartCard(
      title: 'Cơ cấu chi tiêu tháng $monthLabel',
      child: breakdownAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ErrorText('Không tải được cơ cấu chi tiêu.'),
        data: (items) {
          final slices = _toSlices(items, theme.colorScheme.outline);
          final total = slices.fold<int>(0, (s, e) => s + e.total);
          if (total == 0) {
            return const _EmptyText('Chưa có khoản chi nào trong tháng này.');
          }

          return Row(
            children: [
              SizedBox.square(
                dimension: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 46,
                        sections: [
                          for (final s in slices)
                            PieChartSectionData(
                              value: s.total.toDouble(),
                              color: s.color,
                              radius: 30,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tổng chi',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          formatVndCompact(total),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final s in slices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _BreakdownLegendRow(
                          slice: s,
                          percent: _percent(s.total, total),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<_Slice> _toSlices(List<CategoryTotal> items, Color otherColor) {
    final sorted = items.where((c) => c.total > 0).toList();
    final head = sorted
        .take(maxSlices)
        .map(
          (c) => _Slice(c.category.name, c.total, Color(c.category.colorHex)),
        );
    final rest = sorted.skip(maxSlices).fold<int>(0, (s, c) => s + c.total);
    return [...head, if (rest > 0) _Slice('Danh mục khác', rest, otherColor)];
  }

  /// Phần trăm làm tròn, chỉ dùng số nguyên.
  static int _percent(int part, int total) =>
      (part * 100 + total ~/ 2) ~/ total;
}

class _Slice {
  const _Slice(this.name, this.total, this.color);

  final String name;
  final int total;
  final Color color;
}

class _BreakdownLegendRow extends StatelessWidget {
  const _BreakdownLegendRow({required this.slice, required this.percent});

  final _Slice slice;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '${slice.name}: ${formatVnd(slice.total)}',
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.name,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung Card chung cho 2 biểu đồ: tiêu đề + nội dung chiếm phần còn lại.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// Khoảng chia trục Y "đẹp" (1, 2, 5 × 10^k) để có khoảng 4 vạch lưới.
int _niceInterval(int maxValue) {
  final raw = (maxValue + 3) ~/ 4;
  var magnitude = 1;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final step in const [1, 2, 5]) {
    if (step * magnitude >= raw) return step * magnitude;
  }
  return 10 * magnitude;
}
