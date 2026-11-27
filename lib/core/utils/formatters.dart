/// Định dạng hiển thị dùng chung (tiền VNĐ, ngày, tháng).
///
/// Tiền luôn là `int` (bất biến I1); các hàm ở đây chỉ dùng phép chia nguyên.
library;

/// `1250000` → `1.250.000 ₫`; số âm giữ dấu `-` ở đầu.
String formatVnd(int amount) => '${_groupThousands(amount)} ₫';

/// Dạng rút gọn cho trục biểu đồ: `950`, `65k`, `1,2tr`, `3,5 tỷ`.
/// Làm tròn xuống một chữ số thập phân, chỉ dùng số nguyên.
String formatVndCompact(int amount) {
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  if (abs >= 1000000000) return '$sign${_oneDecimal(abs, 1000000000)} tỷ';
  if (abs >= 1000000) return '$sign${_oneDecimal(abs, 1000000)}tr';
  if (abs >= 1000) return '$sign${abs ~/ 1000}k';
  return '$sign$abs';
}

/// Ngày chuẩn Việt Nam `dd/MM/yyyy`.
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// `2026-11` → `11/2026`.
String formatMonthLabel(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) {
    throw ArgumentError.value(yearMonth, 'yearMonth', 'Phải có dạng YYYY-MM');
  }
  return '${parts[1]}/${parts[0]}';
}

String _groupThousands(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    buffer.write(digits[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

/// `1250000, 1000000` → `1,2`; `3000000, 1000000` → `3`.
String _oneDecimal(int value, int unit) {
  final whole = value ~/ unit;
  final tenth = (value % unit) * 10 ~/ unit;
  return tenth == 0 ? '$whole' : '$whole,$tenth';
}
