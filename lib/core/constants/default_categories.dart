/// Danh mục seed mặc định lần đầu mở app (IMPLEMENTATION_PLAN.md mục 4.2).
class DefaultCategory {
  const DefaultCategory(this.name, this.colorHex, this.iconName);

  final String name;
  final int colorHex; // ARGB
  final String iconName; // tên icon Material
}

const List<DefaultCategory> defaultExpenseCategories = [
  DefaultCategory('Ăn uống', 0xFFE53935, 'restaurant'),
  DefaultCategory('Di chuyển', 0xFFFB8C00, 'directions_car'),
  DefaultCategory('Mua sắm', 0xFF8E24AA, 'shopping_bag'),
  DefaultCategory('Hóa đơn & Tiện ích', 0xFF1E88E5, 'receipt_long'),
  DefaultCategory('Nhà cửa', 0xFF6D4C41, 'home'),
  DefaultCategory('Giải trí', 0xFFD81B60, 'sports_esports'),
  DefaultCategory('Sức khỏe', 0xFF00ACC1, 'favorite'),
  DefaultCategory('Giáo dục', 0xFF3949AB, 'school'),
  DefaultCategory('Khác', 0xFF757575, 'category'),
];

const List<DefaultCategory> defaultIncomeCategories = [
  DefaultCategory('Lương', 0xFF43A047, 'payments'),
  DefaultCategory('Thưởng', 0xFF7CB342, 'card_giftcard'),
  DefaultCategory('Đầu tư', 0xFF00897B, 'trending_up'),
  DefaultCategory('Thu nhập phụ', 0xFF039BE5, 'work'),
  DefaultCategory('Khác', 0xFF757575, 'category'),
];

/// Bảng màu gán cho danh mục tự tạo khi sync CSV (xoay vòng).
const List<int> autoCategoryPalette = [
  0xFFEF5350,
  0xFFAB47BC,
  0xFF5C6BC0,
  0xFF29B6F6,
  0xFF26A69A,
  0xFF9CCC65,
  0xFFFFCA28,
  0xFFFF7043,
  0xFF8D6E63,
  0xFF78909C,
];

const String autoCategoryIcon = 'label';

/// Tên danh mục dùng khi CSV để trống cột Danh mục.
const String fallbackCategoryName = 'Khác';

/// Ngưỡng chi tiêu lớn (VNĐ) để vào Visual Notes (Business Rule #4).
const int notableAmountThreshold = 500000;
