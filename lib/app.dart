import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/desktop_shell.dart';
import 'features/calendar_view/presentation/calendar_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';

/// Khung ứng dụng chính: `AppTheme` và các màn hình gắn vào `DesktopShell`.
class M0n3yApp extends StatelessWidget {
  const M0n3yApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'm0n3y',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const DesktopShell(
        calendar: CalendarScreen(),
        transactions: TransactionsScreen(),
      ),
    );
  }
}
