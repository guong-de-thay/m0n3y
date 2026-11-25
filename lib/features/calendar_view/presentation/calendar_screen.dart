import 'package:material_ui/material_ui.dart';

import 'widgets/day_transactions_panel.dart';
import 'widgets/month_calendar_grid.dart';

/// Màn hình Lịch chi tiêu cho Desktop:
/// bố cục 2 panel ngang gồm Lưới lịch tháng (65% trái) và Chi tiết ngày (35% phải).
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 65, child: MonthCalendarGrid()),
          SizedBox(width: 20),
          Expanded(flex: 35, child: DayTransactionsPanel()),
        ],
      ),
    );
  }
}
