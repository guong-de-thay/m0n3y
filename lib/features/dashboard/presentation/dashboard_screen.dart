import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/year_month.dart';
import '../providers/dashboard_provider.dart';
import 'widgets/balance_kpi_cards.dart';
import 'widgets/cashflow_chart_card.dart';

/// Màn hình Tổng quan: bộ chọn tháng, 3 thẻ KPI, biểu đồ cột Thu–Chi và
/// PieChart cơ cấu chi. Mọi số liệu đi qua Stream (I5).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(),
          SizedBox(height: 16),
          BalanceKpiCards(),
          SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: CashflowBarChartCard()),
                SizedBox(width: 16),
                Expanded(flex: 2, child: ExpenseBreakdownCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(dashboardMonthProvider);
    final today = ref.watch(dashboardTodayProvider);
    final notifier = ref.read(dashboardMonthProvider.notifier);
    final isCurrentMonth = month == firstDayOfMonth(today);

    return Row(
      children: [
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: notifier.previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 148,
          child: Text(
            'Tháng ${formatMonthLabel(yearMonthOf(month))}',
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
          onPressed: isCurrentMonth ? null : notifier.goToCurrentMonth,
          child: const Text('Tháng này'),
        ),
        const Spacer(),
      ],
    );
  }
}
