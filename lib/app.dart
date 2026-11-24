import 'package:material_ui/material_ui.dart';

import 'core/widgets/desktop_shell.dart';
import 'features/calendar_view/presentation/calendar_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';

/// Khung ứng dụng chính. `AppTheme` (PO) và các màn hình chi tiết sẽ được
/// gắn vào `DesktopShell` khi hoàn thiện.
class M0n3yApp extends StatelessWidget {
  const M0n3yApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'm0n3y',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E88E5)),
      home: const DesktopShell(
        calendar: CalendarScreen(),
        transactions: TransactionsScreen(),
      ),
    );
  }
}
