import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/year_month.dart';
import '../../../data/models/transaction_models.dart';
import '../../../data/providers/data_providers.dart';

/// Ngày hiện tại (00:00), tách thành provider để có thể override trong test.
final calendarTodayProvider = Provider<DateTime>(
  (ref) => dateOnly(DateTime.now()),
);

/// Trạng thái điều hướng của màn hình Lịch chi tiêu.
class CalendarViewState {
  const CalendarViewState({
    required this.focusedMonth,
    required this.selectedDate,
  });

  /// Luôn chuẩn hóa về ngày mùng 1 của tháng đang xem (`YYYY-MM-01`).
  final DateTime focusedMonth;

  /// Ngày đang chọn trên lưới (luôn chuẩn hóa về 00:00).
  final DateTime selectedDate;

  String get yearMonth => yearMonthOf(focusedMonth);

  CalendarViewState copyWith({DateTime? focusedMonth, DateTime? selectedDate}) {
    return CalendarViewState(
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarViewState &&
        other.focusedMonth == focusedMonth &&
        other.selectedDate == selectedDate;
  }

  @override
  int get hashCode => Object.hash(focusedMonth, selectedDate);
}

/// Quản lý tháng đang xem và ngày đang chọn cho Calendar View.
class CalendarViewNotifier extends Notifier<CalendarViewState> {
  @override
  CalendarViewState build() {
    final today = dateOnly(ref.watch(calendarTodayProvider));
    return CalendarViewState(
      focusedMonth: DateTime(today.year, today.month),
      selectedDate: today,
    );
  }

  void selectDate(DateTime date) {
    final normalized = dateOnly(date);
    state = CalendarViewState(
      focusedMonth: DateTime(normalized.year, normalized.month),
      selectedDate: normalized,
    );
  }

  void previousMonth() {
    _shiftMonth(-1);
  }

  void nextMonth() {
    _shiftMonth(1);
  }

  void goToToday() {
    final today = dateOnly(ref.read(calendarTodayProvider));
    state = CalendarViewState(
      focusedMonth: DateTime(today.year, today.month),
      selectedDate: today,
    );
  }

  void _shiftMonth(int delta) {
    final nextMonth = DateTime(
      state.focusedMonth.year,
      state.focusedMonth.month + delta,
    );
    final today = dateOnly(ref.read(calendarTodayProvider));
    final isTodayMonth =
        today.year == nextMonth.year && today.month == nextMonth.month;
    state = CalendarViewState(
      focusedMonth: nextMonth,
      selectedDate: isTodayMonth ? today : nextMonth,
    );
  }
}

final calendarViewProvider =
    NotifierProvider<CalendarViewNotifier, CalendarViewState>(
      CalendarViewNotifier.new,
    );

/// Stream dữ liệu thu/chi theo từng ngày trong tháng đang xem (I3, I5).
final monthlyDailyCashflowProvider =
    StreamProvider<Map<DateTime, DailyCashflow>>((ref) {
      final yearMonth = ref.watch(
        calendarViewProvider.select((state) => state.yearMonth),
      );
      return ref
          .watch(transactionRepositoryProvider)
          .watchDailyCashflow(yearMonth);
    });

/// Dữ liệu chi tiết của ngày đang chọn trên lưới lịch.
final selectedDayCashflowProvider = Provider<DailyCashflow?>((ref) {
  final selectedDate = ref.watch(
    calendarViewProvider.select((state) => state.selectedDate),
  );
  final map = ref.watch(monthlyDailyCashflowProvider).asData?.value;
  return map?[selectedDate];
});

/// Tổng thu/chi của tháng đang xem tính bằng số nguyên int (I1).
final calendarMonthTotalsProvider = Provider<MonthTotals>((ref) {
  final map = ref.watch(monthlyDailyCashflowProvider).asData?.value;
  if (map == null || map.isEmpty) {
    return const MonthTotals();
  }
  var totalIncome = 0;
  var totalExpense = 0;
  for (final day in map.values) {
    totalIncome += day.income;
    totalExpense += day.expense;
  }
  return MonthTotals(income: totalIncome, expense: totalExpense);
});
