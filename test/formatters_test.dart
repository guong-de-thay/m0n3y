import 'package:flutter_test/flutter_test.dart';
import 'package:m0n3y/core/utils/formatters.dart';
import 'package:m0n3y/core/utils/year_month.dart';

void main() {
  group('formatVnd', () {
    test('nhóm hàng nghìn bằng dấu chấm và thêm ₫', () {
      expect(formatVnd(0), '0 ₫');
      expect(formatVnd(999), '999 ₫');
      expect(formatVnd(1000), '1.000 ₫');
      expect(formatVnd(65000), '65.000 ₫');
      expect(formatVnd(1250000), '1.250.000 ₫');
      expect(formatVnd(1000000000), '1.000.000.000 ₫');
    });

    test('số âm giữ dấu trừ ở đầu', () {
      expect(formatVnd(-500), '-500 ₫');
      expect(formatVnd(-1250000), '-1.250.000 ₫');
    });
  });

  group('formatVndCompact', () {
    test('rút gọn theo k, tr, tỷ, làm tròn xuống 1 chữ số', () {
      expect(formatVndCompact(0), '0');
      expect(formatVndCompact(950), '950');
      expect(formatVndCompact(65000), '65k');
      expect(formatVndCompact(999999), '999k');
      expect(formatVndCompact(1000000), '1tr');
      expect(formatVndCompact(1250000), '1,2tr');
      expect(formatVndCompact(15990000), '15,9tr');
      expect(formatVndCompact(3500000000), '3,5 tỷ');
      expect(formatVndCompact(-2000000), '-2tr');
    });
  });

  group('ngày và tháng', () {
    test('formatDate theo dd/MM/yyyy', () {
      expect(formatDate(DateTime(2026, 1, 5)), '05/01/2026');
      expect(formatDate(DateTime(2026, 11, 25, 23, 59)), '25/11/2026');
    });

    test('formatMonthLabel đổi YYYY-MM thành MM/YYYY', () {
      expect(formatMonthLabel('2026-11'), '11/2026');
      expect(formatMonthLabel('2027-01'), '01/2027');
      expect(() => formatMonthLabel('112026'), throwsArgumentError);
    });

    test('firstDayOfMonth và addMonths xử lý giáp năm', () {
      expect(firstDayOfMonth(DateTime(2026, 11, 25, 8)), DateTime(2026, 11));
      expect(addMonths(DateTime(2026, 11, 25), 1), DateTime(2026, 12));
      expect(addMonths(DateTime(2026, 12, 31), 1), DateTime(2027, 1));
      expect(addMonths(DateTime(2026, 1, 31), -1), DateTime(2025, 12));
      expect(addMonths(DateTime(2026, 11), -5), DateTime(2026, 6));
      expect(yearMonthOf(addMonths(DateTime(2026, 3), -5)), '2025-10');
    });
  });
}
