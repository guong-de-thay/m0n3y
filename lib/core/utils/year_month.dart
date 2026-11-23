/// Chuỗi gom nhóm `YYYY-MM` tính từ `transaction_date` (bất biến I3).
String yearMonthOf(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// Chỉ giữ phần ngày (00:00 giờ địa phương) để lịch/bộ lọc so khớp đúng ngày.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
