import 'package:shared_preferences/shared_preferences.dart';

/// Lưu cấu hình cục bộ (đường dẫn file CSV iCloud do người dùng chọn).
/// Không hard-code đường dẫn của máy nào vào source.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _csvPathKey = 'csv_path';

  final SharedPreferences _prefs;

  String? get csvPath => _prefs.getString(_csvPathKey);

  Future<void> setCsvPath(String path) => _prefs.setString(_csvPathKey, path);

  Future<void> clearCsvPath() => _prefs.remove(_csvPathKey);
}
