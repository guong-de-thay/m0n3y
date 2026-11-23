import 'app_database.dart';
import '../models/transaction_models.dart';

/// Dữ liệu mẫu 29 giao dịch trải qua tháng 10 và 11/2026 để PO/Tester dựng UI
/// ngay khi Sync CSV chưa xong. CHỈ bật khi chạy với
/// `--dart-define=SEED_MOCK=true`; không bao giờ tự chạy trên DB thật.
///
/// Idempotent: không làm gì nếu DB đã có giao dịch.
Future<void> seedMockData(AppDatabase db) async {
  if (await db.transactionsDao.countAll() > 0) return;

  await db.transaction(() async {
    Future<void> add(
      int y,
      int m,
      int d,
      TxType type,
      String category,
      int amount,
      String note, {
      bool notable = false,
    }) async {
      final catId = await db.categoriesDao.getOrCreateByName(
        name: category,
        type: type,
      );
      await db.transactionsDao.insertTransaction(
        NewTransaction(
          transactionDate: DateTime(y, m, d),
          type: type,
          categoryId: catId,
          amount: amount,
          note: note,
          isNotable: notable,
          source: TxSource.manual,
        ),
      );
    }

    const e = TxType.expense;
    const i = TxType.income;

    // ---- Tháng 10/2026
    await add(2026, 10, 1, i, 'Lương', 18000000, 'Lương tháng 10');
    await add(2026, 10, 2, e, 'Nhà cửa', 3500000, 'Tiền thuê phòng');
    await add(2026, 10, 3, e, 'Ăn uống', 65000, 'Phở bò buổi sáng');
    await add(2026, 10, 5, e, 'Di chuyển', 120000, 'Đổ xăng');
    await add(2026, 10, 7, e, 'Ăn uống', 230000, 'Ăn tối với bạn');
    await add(2026, 10, 9, e, 'Hóa đơn & Tiện ích', 480000, 'Tiền điện');
    await add(2026, 10, 12, e, 'Mua sắm', 890000, 'Áo khoác', notable: true);
    await add(2026, 10, 14, e, 'Giải trí', 150000, 'Xem phim');
    await add(2026, 10, 16, e, 'Ăn uống', 98000, 'Cà phê và bánh');
    await add(2026, 10, 18, i, 'Thu nhập phụ', 2000000, 'Làm thêm cuối tuần');
    await add(2026, 10, 20, e, 'Sức khỏe', 650000, 'Khám răng định kỳ');
    await add(2026, 10, 22, e, 'Di chuyển', 85000, 'Grab đi họp');
    await add(
      2026,
      10,
      25,
      e,
      'Giáo dục',
      1200000,
      'Khóa học tiếng Anh',
      notable: true,
    );
    await add(2026, 10, 27, e, 'Ăn uống', 175000, 'Đi chợ');
    await add(2026, 10, 28, i, 'Thưởng', 3000000, 'Thưởng dự án tháng 10');

    // ---- Tháng 11/2026
    await add(2026, 11, 1, i, 'Lương', 18000000, 'Lương tháng 11');
    await add(2026, 11, 2, e, 'Nhà cửa', 3500000, 'Tiền thuê phòng');
    await add(2026, 11, 3, e, 'Ăn uống', 72000, 'Bún chả');
    await add(2026, 11, 4, e, 'Di chuyển', 100000, 'Đổ xăng');
    await add(
      2026,
      11,
      6,
      e,
      'Mua sắm',
      1250000,
      'Bàn phím cơ (nhập bù)',
      notable: true,
    );
    await add(2026, 11, 8, e, 'Ăn uống', 310000, 'Sinh nhật bạn');
    await add(2026, 11, 10, e, 'Hóa đơn & Tiện ích', 520000, 'Tiền điện, nước');
    await add(2026, 11, 11, e, 'Giải trí', 200000, 'Karaoke');
    await add(2026, 11, 13, e, 'Ăn uống', 65000, 'Phở bò buổi sáng');
    await add(2026, 11, 15, i, 'Đầu tư', 450000, 'Lãi tiết kiệm');
    await add(2026, 11, 17, e, 'Thú cưng', 380000, 'Thức ăn cho mèo');
    await add(2026, 11, 19, e, 'Sức khỏe', 540000, 'Vitamin và thuốc');
    await add(2026, 11, 21, e, 'Di chuyển', 60000, 'Grab');
    await add(2026, 11, 22, e, 'Ăn uống', 135000, 'Cơm trưa văn phòng');
  });
}
