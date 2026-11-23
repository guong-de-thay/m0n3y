import '../../../data/database/app_database.dart';

/// Hàm format tạm cho phân hệ Transactions.
/// Sẽ chuyển sang dùng chung `lib/core/utils/formatters.dart` sau khi PO merge.
String formatVnd(int amount) {
  final isNegative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    buffer.write(digits[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buffer.write('.');
    }
  }
  final prefix = isNegative ? '-' : '';
  return '$prefix${buffer.toString()} ₫';
}

/// Định dạng ngày chuẩn Việt Nam `dd/MM/yyyy`.
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatTxType(TxType type) => switch (type) {
  TxType.income => 'Thu',
  TxType.expense => 'Chi',
};
