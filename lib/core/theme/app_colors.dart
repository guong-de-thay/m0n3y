import 'package:material_ui/material_ui.dart';

/// Màu ngữ nghĩa dùng chung toàn app.
abstract final class AppColors {
  /// Màu gốc sinh `ColorScheme` (xanh dương).
  static const Color seed = Color(0xFF1E88E5);

  /// Khoản Thu.
  static const Color income = Color(0xFF2E7D32);

  /// Khoản Chi.
  static const Color expense = Color(0xFFC62828);

  /// Đánh dấu "đáng chú ý" (icon sao, Visual Notes).
  static const Color notable = Color(0xFFFFA000);
}
