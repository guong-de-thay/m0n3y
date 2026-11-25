import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/year_month.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/transaction_models.dart';
import '../../../data/providers/data_providers.dart';

/// Số tháng trên biểu đồ cột Thu–Chi, kết thúc ở tháng đang xem.
const int dashboardSeriesMonths = 6;

/// Ngày hiện tại (00:00), tách thành provider để override trong test.
final dashboardTodayProvider = Provider<DateTime>(
  (ref) => dateOnly(DateTime.now()),
);

/// Tháng đang xem trên Dashboard, luôn là ngày mùng 1 của tháng.
class DashboardMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => firstDayOfMonth(ref.watch(dashboardTodayProvider));

  void previousMonth() => state = addMonths(state, -1);

  void nextMonth() => state = addMonths(state, 1);

  void goToCurrentMonth() =>
      state = firstDayOfMonth(ref.read(dashboardTodayProvider));

  void selectMonth(DateTime month) => state = firstDayOfMonth(month);
}

final dashboardMonthProvider =
    NotifierProvider<DashboardMonthNotifier, DateTime>(
      DashboardMonthNotifier.new,
    );

/// `YYYY-MM` của tháng đang xem — khóa gom nhóm theo `transaction_date` (I3).
final dashboardYearMonthProvider = Provider<String>(
  (ref) => yearMonthOf(ref.watch(dashboardMonthProvider)),
);

/// Tổng Thu/Chi của tháng đang xem (SUM trên INTEGER — I1; Stream — I5).
final dashboardMonthTotalsProvider = StreamProvider<MonthTotals>((ref) {
  final ym = ref.watch(dashboardYearMonthProvider);
  return ref.watch(transactionRepositoryProvider).watchMonthTotals(ym);
});

/// Số dư lũy kế từ đầu đến hết tháng đang xem (VNĐ, int).
final dashboardBalanceProvider = StreamProvider<int>((ref) {
  final ym = ref.watch(dashboardYearMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotalsUntil(ym)
      .map((totals) => totals.balance);
});

/// Chuỗi [dashboardSeriesMonths] tháng cho biểu đồ cột, cũ → mới.
final dashboardMonthlySeriesProvider = StreamProvider<List<MonthlySummary>>((
  ref,
) {
  final month = ref.watch(dashboardMonthProvider);
  final from = yearMonthOf(addMonths(month, 1 - dashboardSeriesMonths));
  return ref
      .watch(transactionRepositoryProvider)
      .watchMonthlySeries(from, yearMonthOf(month));
});

/// Cơ cấu chi tiêu theo danh mục trong tháng đang xem, lớn → nhỏ.
final dashboardExpenseBreakdownProvider = StreamProvider<List<CategoryTotal>>((
  ref,
) {
  final ym = ref.watch(dashboardYearMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchCategoryBreakdown(ym, TxType.expense);
});

/// Visual Notes của tháng đang xem (Business Rule #4).
final dashboardVisualNotesProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      final ym = ref.watch(dashboardYearMonthProvider);
      return ref.watch(transactionRepositoryProvider).watchVisualNotes(ym);
    });
