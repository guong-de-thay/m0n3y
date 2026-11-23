import 'package:material_ui/material_ui.dart';

/// Thanh hành động trên cùng của khung ứng dụng Desktop.
///
/// Các callback `onSyncCsv` và `onExportExcel` sẽ được nối với controller thực
/// tế ở giai đoạn tích hợp; khi chưa gán, bấm nút sẽ hiện SnackBar "Sắp có".
class TopActionBar extends StatelessWidget {
  const TopActionBar({
    super.key,
    required this.title,
    this.onSyncCsv,
    this.onExportExcel,
  });

  final String title;
  final VoidCallback? onSyncCsv;
  final VoidCallback? onExportExcel;

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Sắp có')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: onSyncCsv ?? () => _showComingSoon(context),
            icon: const Icon(Icons.cloud_sync_outlined, size: 18),
            label: const Text('Sync iCloud CSV'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onExportExcel ?? () => _showComingSoon(context),
            icon: const Icon(Icons.table_view_outlined, size: 18),
            label: const Text('Xuất Excel'),
          ),
        ],
      ),
    );
  }
}
