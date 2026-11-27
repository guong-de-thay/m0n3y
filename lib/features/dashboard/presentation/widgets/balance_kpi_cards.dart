import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/dashboard_provider.dart';

/// 3 thẻ KPI: Số dư lũy kế, Thu tháng, Chi tháng (VNĐ, int — I1).
class BalanceKpiCards extends ConsumerWidget {
  const BalanceKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthLabel = formatMonthLabel(ref.watch(dashboardYearMonthProvider));
    final balance = ref.watch(dashboardBalanceProvider);
    final totals = ref.watch(dashboardMonthTotalsProvider);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _KpiCard(
            key: const ValueKey('kpi_balance'),
            icon: Icons.account_balance_wallet_outlined,
            accent: theme.colorScheme.primary,
            title: 'Số dư',
            value: balance.whenData((v) => v),
            valueColor: (v) =>
                v < 0 ? AppColors.expense : theme.colorScheme.onSurface,
            subtitle: (_) => 'Lũy kế đến hết tháng $monthLabel',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            key: const ValueKey('kpi_income'),
            icon: Icons.arrow_downward,
            accent: AppColors.income,
            title: 'Thu tháng $monthLabel',
            value: totals.whenData((t) => t.income),
            valueColor: (_) => AppColors.income,
            subtitle: (_) => 'Tổng các khoản thu trong tháng',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            key: const ValueKey('kpi_expense'),
            icon: Icons.arrow_upward,
            accent: AppColors.expense,
            title: 'Chi tháng $monthLabel',
            value: totals.whenData((t) => t.expense),
            valueColor: (_) => AppColors.expense,
            subtitle: (_) {
              final diff = totals.asData?.value.balance ?? 0;
              final sign = diff > 0 ? '+' : '';
              return 'Thu − Chi trong tháng: $sign${formatVnd(diff)}';
            },
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final AsyncValue<int> value;
  final Color Function(int value) valueColor;
  final String Function(int value) subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            value.when(
              loading: () => const SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => Text(
                'Không tải được số liệu',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              data: (v) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatVnd(v),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: valueColor(v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle(v),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
