import 'package:material_ui/material_ui.dart';

/// Khung ứng dụng tối thiểu. `AppTheme` (PO) và `DesktopShell` (Tester) sẽ
/// thay thế phần placeholder này khi nhánh của họ được merge.
class M0n3yApp extends StatelessWidget {
  const M0n3yApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'm0n3y',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E88E5)),
      home: const Scaffold(
        body: Center(child: Text('m0n3y — khung dự án đã sẵn sàng')),
      ),
    );
  }
}
