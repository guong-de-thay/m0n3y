import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/excel_export/presentation/export_feedback.dart';
import 'package:m0n3y/features/excel_export/providers/export_controller.dart';
import 'package:m0n3y/features/excel_export/services/excel_export_service.dart';
import 'package:m0n3y/features/icloud_sync/domain/sync_result.dart';
import 'package:m0n3y/features/icloud_sync/presentation/sync_feedback.dart';
import 'package:m0n3y/features/icloud_sync/providers/sync_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Thông điệp tiếng Việt', () {
    SyncResult result({
      int total = 3,
      int imported = 3,
      List<String> cats = const [],
      int errors = 0,
    }) => SyncResult(
      totalRows: total,
      importedRows: imported,
      newCategories: cats,
      errors: [
        for (var i = 0; i < errors; i++)
          SyncRowError(line: i + 2, message: 'lỗi', cells: const []),
      ],
    );

    test('đồng bộ sạch chỉ nêu số dòng', () {
      expect(describeSyncResult(result()), 'Đã nhập 3/3 dòng');
    });

    test('nêu danh mục mới và số dòng lỗi được giữ lại', () {
      expect(
        describeSyncResult(
          result(imported: 1, cats: ['Thú cưng', 'Quà'], errors: 2),
        ),
        'Đã nhập 1/3 dòng · tạo 2 danh mục mới (Thú cưng, Quà) · '
        '2 dòng lỗi được giữ lại trong file',
      );
    });

    test('file không có dòng giao dịch', () {
      expect(
        describeSyncResult(result(total: 0, imported: 0)),
        'File CSV không có dòng giao dịch nào.',
      );
    });

    test('lỗi nghiệp vụ giữ nguyên, lỗi lạ chỉ báo chung', () {
      expect(
        describeSyncError(const SyncException('File đang bị khóa')),
        'File đang bị khóa',
      );
      final generic = describeSyncError(StateError('chi tiết kỹ thuật'));
      expect(generic, isNot(contains('chi tiết kỹ thuật')));
      expect(
        describeExportError(const ExportException('Chưa có dữ liệu')),
        'Chưa có dữ liệu',
      );
      expect(
        describeExportError(StateError('x')),
        isNot(contains('StateError')),
      );
    });
  });

  group('Widget phản hồi', () {
    late AppDatabase db;
    late ProviderContainer container;
    late Directory dir;
    String? pickPath;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase.inMemory();
      dir = await Directory.systemTemp.createTemp('m0n3y_fb');
      pickPath = null;
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          pickCsvDialogProvider.overrideWithValue(() async => pickPath),
          saveFileDialogProvider.overrideWithValue(
            (String name, Uint8List bytes) async => true,
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });

    Future<void> pumpApp(WidgetTester tester) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SyncFeedbackListener(
                child: ExportFeedbackListener(child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      );
    }

    String writeCsv(String body) {
      final f = File('${dir.path}/pending.csv')
        ..writeAsStringSync('Ngày,Loại,Danh mục,Số tiền,Ghi chú\n$body');
      return f.path;
    }

    testWidgets('sync có dòng lỗi: SnackBar tóm tắt và Dialog chi tiết', (
      tester,
    ) async {
      pickPath = writeCsv(
        '13/11/2026,Chi,Thú cưng,65000,Cát\n'
        '14/11/2026,Chi,Ăn uống,abc,Sai tiền\n',
      );
      await pumpApp(tester);
      await tester.runAsync(
        () => container.read(syncControllerProvider.notifier).sync(),
      );
      await tester.pump();

      expect(
        find.text(
          'Đã nhập 1/2 dòng · tạo 1 danh mục mới (Thú cưng) · '
          '1 dòng lỗi được giữ lại trong file',
        ),
        findsOneWidget,
      );

      // Chờ SnackBar trượt vào hết màn hình rồi mới bấm được nút hành động.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text('Xem chi tiết'));
      await tester.pumpAndSettle();
      expect(find.text('1 dòng chưa nhập được'), findsOneWidget);
      expect(find.textContaining('Dòng 3:'), findsOneWidget);
    });

    testWidgets('sync sạch: không có nút Xem chi tiết', (tester) async {
      pickPath = writeCsv('13/11/2026,Chi,Ăn uống,65000,Phở\n');
      await pumpApp(tester);
      await tester.runAsync(
        () => container.read(syncControllerProvider.notifier).sync(),
      );
      await tester.pump();
      expect(find.text('Đã nhập 1/1 dòng'), findsOneWidget);
      expect(find.text('Xem chi tiết'), findsNothing);
    });

    testWidgets('sync lỗi file: SnackBar báo lỗi, không crash', (tester) async {
      pickPath = '${dir.path}/khong_ton_tai.csv';
      await pumpApp(tester);
      await tester.runAsync(
        () => container.read(syncControllerProvider.notifier).sync(),
      );
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sync: hủy chọn file thì không hiện gì', (tester) async {
      pickPath = null;
      await pumpApp(tester);
      await tester.runAsync(
        () => container.read(syncControllerProvider.notifier).sync(),
      );
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('export không có dữ liệu: SnackBar báo lỗi', (tester) async {
      await pumpApp(tester);
      await tester.runAsync(
        () => container.read(exportControllerProvider.notifier).export(),
      );
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('export có dữ liệu: báo tên file và số Sheet', (tester) async {
      await tester.runAsync(() async {
        final id = await db.categoriesDao.getOrCreateByName(
          name: 'Ăn uống',
          type: TxType.expense,
        );
        for (final d in [DateTime(2026, 10, 2), DateTime(2026, 11, 3)]) {
          await db.transactionsDao.insertTransaction(
            NewTransaction(
              transactionDate: d,
              type: TxType.expense,
              categoryId: id,
              amount: 1000,
            ),
          );
        }
      });
      await pumpApp(tester);
      await tester.runAsync(
        () => container.read(exportControllerProvider.notifier).export(),
      );
      await tester.pump();
      expect(find.textContaining('2 Sheet theo tháng'), findsOneWidget);
    });
  });
}
