import 'package:material_ui/material_ui.dart';

import 'top_action_bar.dart';

/// Khung màn hình ngang cho ứng dụng Windows Desktop:
/// [NavigationRail] bên trái gồm 3 mục (Dashboard, Calendar, Transactions)
/// và phần nội dung kèm [TopActionBar] bên phải.
class DesktopShell extends StatefulWidget {
  const DesktopShell({
    super.key,
    this.dashboard,
    this.calendar,
    this.transactions,
    this.onSyncCsv,
    this.onExportExcel,
    this.initialIndex = 0,
  });

  final Widget? dashboard;
  final Widget? calendar;
  final Widget? transactions;
  final VoidCallback? onSyncCsv;
  final VoidCallback? onExportExcel;
  final int initialIndex;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  static const List<String> _sectionTitles = [
    'Dashboard',
    'Calendar',
    'Transactions',
  ];

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _sectionTitles.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 1200;

    final pages = [
      widget.dashboard ??
          const _SectionPlaceholder(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            subtitle: 'Màn hình tổng quan sẽ được tích hợp tại đây.',
          ),
      widget.calendar ??
          const _SectionPlaceholder(
            icon: Icons.calendar_month_outlined,
            title: 'Calendar',
            subtitle: 'Lịch thu chi theo tháng sẽ được tích hợp tại đây.',
          ),
      widget.transactions ??
          const _SectionPlaceholder(
            icon: Icons.receipt_long_outlined,
            title: 'Transactions',
            subtitle: 'Danh sách và bộ lọc giao dịch sẽ được tích hợp tại đây.',
          ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: isWide,
            labelType: isWide
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 8),
                    Text(
                      'm0n3y',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('Calendar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Transactions'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                TopActionBar(
                  title: _sectionTitles[_selectedIndex],
                  onSyncCsv: widget.onSyncCsv,
                  onExportExcel: widget.onExportExcel,
                ),
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
