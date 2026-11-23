import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/database/mock_data.dart';
import 'data/providers/data_providers.dart';

/// Chạy `flutter run -d windows --dart-define=SEED_MOCK=true` để nạp dữ liệu
/// mẫu vào DB cục bộ khi DB còn trống.
const bool _seedMock = bool.fromEnvironment('SEED_MOCK');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1200, 760),
    title: 'm0n3y',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  if (_seedMock) {
    await seedMockData(container.read(appDatabaseProvider));
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const M0n3yApp()),
  );
}
