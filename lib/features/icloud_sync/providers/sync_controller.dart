import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/data_providers.dart';
import '../../../data/repositories/sync_repository.dart';
import '../domain/sync_result.dart';
import '../services/csv_sync_service.dart';

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepository(ref.watch(appDatabaseProvider)),
);

final csvSyncServiceProvider = Provider<CsvSyncService>(
  (ref) => CsvSyncService(ref.watch(syncRepositoryProvider)),
);

/// Mở hộp thoại chọn `pending_transactions.csv`; `null` nếu hủy.
typedef PickCsvDialog = Future<String?> Function();

final pickCsvDialogProvider = Provider<PickCsvDialog>((ref) {
  return () async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Chọn file pending_transactions.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    return file?.path;
  };
});

/// Điều khiển nút "Sync iCloud CSV". State là `AsyncValue<SyncResult?>`;
/// `error` mang [SyncException] với thông điệp tiếng Việt.
/// UI tự cập nhật nhờ Stream của Drift (I5), không cần reload.
class SyncController extends AsyncNotifier<SyncResult?> {
  bool _busy = false;

  @override
  Future<SyncResult?> build() async => null;

  Future<void> sync() async {
    if (_busy) return;
    _busy = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final settings = ref.read(settingsRepositoryProvider);
      var path = settings.csvPath;
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        path = await ref.read(pickCsvDialogProvider)();
        if (path == null) return null; // Người dùng hủy chọn file.
        await settings.setCsvPath(path);
      }
      return ref.read(csvSyncServiceProvider).sync(path);
    });
    _busy = false;
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncResult?>(SyncController.new);
