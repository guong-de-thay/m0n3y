import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/data/database/app_database.dart';
import 'package:m0n3y/data/models/transaction_models.dart';
import 'package:m0n3y/data/providers/data_providers.dart';
import 'package:m0n3y/features/excel_export/providers/export_controller.dart';
import 'package:m0n3y/features/excel_export/services/excel_export_service.dart';
import 'package:m0n3y/features/icloud_sync/providers/sync_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late Directory dir;
  String? savedName;
  var saveCalls = 0;
  var pickReturn = (() => null as String?);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.inMemory();
    dir = await Directory.systemTemp.createTemp('m0n3y_ctl');
    savedName = null;
    saveCalls = 0;
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        saveFileDialogProvider.overrideWithValue((name, Uint8List bytes) async {
          saveCalls++;
          savedName = name;
          return true;
        }),
        pickCsvDialogProvider.overrideWithValue(() async => pickReturn()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'sync: chưa cấu hình đường dẫn thì mở hộp thoại, lưu lại và nhập',
    () async {
      final csv = File('${dir.path}/pending.csv')
        ..writeAsStringSync(
          'Ngày,Loại,Danh mục,Số tiền,Ghi chú\n13/11/2026,Chi,Thú cưng,65000,Cát\n',
        );
      pickReturn = () => csv.path;

      await container.read(syncControllerProvider.notifier).sync();

      final result = container.read(syncControllerProvider).requireValue!;
      expect(result.importedRows, 1);
      expect(result.newCategories, ['Thú cưng']);
      expect(container.read(settingsRepositoryProvider).csvPath, csv.path);
    },
  );

  test('sync: người dùng hủy chọn file thì không lỗi, không nhập', () async {
    pickReturn = () => null;
    await container.read(syncControllerProvider.notifier).sync();
    expect(container.read(syncControllerProvider).requireValue, isNull);
  });

  test('export: không có giao dịch thì state là lỗi tiếng Việt', () async {
    await container.read(exportControllerProvider.notifier).export();
    final state = container.read(exportControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<ExportException>());
    expect(saveCalls, 0);
  });

  test('export: có dữ liệu thì lưu file .xlsx và báo số Sheet', () async {
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
    await container.read(exportControllerProvider.notifier).export();
    final outcome = container.read(exportControllerProvider).requireValue!;
    expect(outcome.sheetCount, 2);
    expect(savedName, endsWith('.xlsx'));
  });
}
