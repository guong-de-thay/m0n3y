import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/data/repositories/settings_repository.dart';
import 'package:m0n3y/features/dashboard/presentation/dashboard_screen.dart';
import 'package:m0n3y/features/dashboard/providers/dashboard_provider.dart';
import 'package:m0n3y/features/icloud_sync/presentation/csv_path_dialog.dart';
import 'package:m0n3y/features/icloud_sync/providers/sync_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CsvPathDialog', () {
    late Directory tempDir;
    late String existingCsv;
    late AppDatabase db;
    late ProviderContainer container;
    late SettingsRepository settings;
    String? pickerResult;
    var pickerCalls = 0;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('m0n3y_csv_path_');
      existingCsv = '${tempDir.path}${Platform.pathSeparator}pending.csv';
      File(existingCsv).writeAsStringSync('Ngày,Loại,Danh mục,Số tiền\n');
      pickerResult = null;
      pickerCalls = 0;

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          dashboardTodayProvider.overrideWithValue(DateTime(2026, 11, 15)),
          pickCsvDialogProvider.overrideWithValue(() async {
            pickerCalls++;
            return pickerResult;
          }),
        ],
      );
      settings = container.read(settingsRepositoryProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      tempDir.deleteSync(recursive: true);
    });

    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCsvPathDialog(context),
                  child: const Text('Mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
    }

    testWidgets('chọn file thì lưu đường dẫn, bỏ đường dẫn thì xóa', (
      tester,
    ) async {
      await openDialog(tester);
      expect(find.textContaining('Chưa chọn file'), findsOneWidget);

      pickerResult = existingCsv;
      await tester.tap(find.text('Chọn file…'));
      await tester.pumpAndSettle();

      expect(pickerCalls, 1);
      expect(settings.csvPath, existingCsv);
      expect(find.text(existingCsv), findsOneWidget);
      expect(find.textContaining('Không tìm thấy file'), findsNothing);

      await tester.tap(find.text('Bỏ đường dẫn'));
      await tester.pumpAndSettle();
      expect(settings.csvPath, isNull);
      expect(find.textContaining('Chưa chọn file'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('file đã lưu không còn tồn tại thì cảnh báo; hủy chọn giữ '
        'nguyên đường dẫn', (tester) async {
      final missing = '${tempDir.path}${Platform.pathSeparator}da_xoa.csv';
      await settings.setCsvPath(missing);

      await openDialog(tester);
      expect(find.text(missing), findsOneWidget);
      expect(find.textContaining('Không tìm thấy file'), findsOneWidget);

      pickerResult = null; // Người dùng bấm Hủy trong hộp chọn file.
      await tester.tap(find.text('Chọn file…'));
      await tester.pumpAndSettle();
      expect(pickerCalls, 1);
      expect(settings.csvPath, missing);
    });

    testWidgets('nút "Cấu hình file CSV" trên Dashboard mở hộp thoại', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cấu hình file CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Cấu hình file CSV iCloud'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
