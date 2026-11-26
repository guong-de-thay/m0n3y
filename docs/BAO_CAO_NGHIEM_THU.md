# Báo cáo nghiệm thu — phân hệ Dữ liệu & Đồng bộ (Dev)

- **Phạm vi:** `lib/data/**`, `lib/features/icloud_sync/**`, `lib/features/excel_export/**` (PR #3 từ nhánh `feat/dong-bo-csv-va-excel`, đã gộp vào `develop` ở commit 587624e).
- **Ngày lập:** 24/11/2026. **Cập nhật:** 26/11/2026, sau khi gộp PR #8 và #10 (khung `DesktopShell`, màn Transactions, Calendar) mở PR #11, #12 (số dư lũy kế, màn Dashboard) và duyệt lại PR #9 (bộ CSV bẫy của Tester).
- **Cách đọc:** mỗi mục có trạng thái và bằng chứng. `Đạt` = có test tự động hoặc kết quả lệnh ở mục 2. `Chờ tích hợp` = phụ thuộc phần chưa nằm trong `develop` hoặc chưa được nối vào giao diện. `Chưa chạy tay` = chưa kiểm bằng thao tác trên ứng dụng thật.

> Báo cáo này chỉ khẳng định những gì đã chạy được. Đủ 3 màn hình đã có (Dashboard nằm ở PR #12). Riêng hai nút Sync/Export trên giao diện chưa được nối; mục 7 và 9 ghi rõ các bước chưa kiểm.

## 1. Môi trường và cách tái lập

- Flutter 3.50.1 (stable), Windows 11.
- Chạy kiểm tra (CLAUDE.md mục 4):

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- Chạy với dữ liệu mẫu: `flutter run -d windows --dart-define=SEED_MOCK=true`.
- Dữ liệu nghiệm thu: `test/fixtures/pending_transactions_nghiem_thu.csv` (6 dòng: lùi ngày về tháng 10, danh mục mới "Thú cưng", ghi chú gắn `*`, một dòng sai số tiền `abc`, ghi chú `=SUM(A1)`, ghi chú có dấu phẩy trong ngoặc kép).

## 2. Kết quả kiểm tra tự động

Chạy lại ngày 26/11/2026 trên Windows 11, nhánh `feat/dashboard-va-bieu-do` (= `develop` + PR #11 + PR #12). Lần chạy đầu ngày 24/11/2026 cho kết quả 77 test.

| Lệnh | Kết quả |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Không có file cần định dạng lại |
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!` — **119 test** (riêng `develop` hiện tại: 99 test) |

CI GitHub Actions (PR #7) chạy cùng 3 lệnh này trên Ubuntu cho mọi PR vào `develop`.

Phân bổ test:

| File | Số test | Nội dung chính |
|---|---:|---|
| `test/csv_sync_test.dart` | 29 | Đồng bộ CSV, I1, I2, I4, đáng chú ý, ngày/loại, lỗi file |
| `test/database_test.dart` | 27 | Seed, I1, I3, I4, I5, bộ lọc, Dashboard/Calendar, chuỗi nhiều tháng, số dư lũy kế |
| `test/sync_feedback_test.dart` | 10 | Thông điệp tiếng Việt và widget phản hồi Sync/Export |
| `test/transactions_provider_test.dart` | 9 | Bộ lọc giao dịch, tự đảo khoảng ngày, stream thêm/sửa/xóa (Tester) |
| `test/excel_export_test.dart` | 8 | Sheet `MM-YYYY`, kiểu số, tóm tắt, Formula Injection |
| `test/transactions_screen_test.dart` | 7 | Màn Giao dịch: lọc, thêm/sửa/xóa, xóa lỗi không crash (Tester) |
| `test/formatters_test.dart` | 6 | `1.250.000 ₫`, dạng rút gọn, `dd/MM/yyyy`, cộng tháng qua năm |
| `test/dashboard_provider_test.dart` | 6 | Tháng đang xem, tổng tháng, số dư lũy kế, chuỗi 6 tháng, cơ cấu chi, Visual Notes, I5 |
| `test/controllers_test.dart` | 4 | `SyncController`, `ExportController` |
| `test/calendar_provider_test.dart` | 3 | Chuyển tháng, gom theo `transaction_date`, I5 (Tester) |
| `test/calendar_screen_test.dart` | 3 | Ô ngày, panel chi tiết, tự cập nhật (Tester) |
| `test/dashboard_screen_test.dart` | 3 | KPI, chuyển tháng, tự cập nhật, trạng thái rỗng |
| `test/csv_path_dialog_test.dart` | 3 | Hộp thoại đổi/bỏ đường dẫn CSV, cảnh báo file không tồn tại |
| `test/acceptance_flow_test.dart` | 1 | Sync → Export với CSV mẫu nghiệm thu |

## 3. Đối chiếu tiêu chí nghiệm thu (REQUIREMENTS mục 6)

| Nhóm (trọng số) | Tiêu chí | Trạng thái | Bằng chứng / ghi chú |
|---|---|---|---|
| 1. Sản phẩm chạy thực tế (35%) | Sync bộ dữ liệu có lùi ngày, danh mục mới, ghi chú `*`, 1 dòng sai số tiền: không crash, không mất dữ liệu | **Đạt (logic)** | `acceptance_flow_test.dart`; `csv_sync_test.dart` group "I2" |
| | Export ra `.xlsx` tách Sheet `MM-YYYY` | **Đạt (logic)** | `acceptance_flow_test.dart`; `excel_export_test.dart` |
| | Bấm nút **Sync iCloud CSV** / **Export Excel** trên giao diện | **Chờ tích hợp** | `DesktopShell` đã có trên `develop` (PR #8) và nhận `onSyncCsv`/`onExportExcel`, nhưng `lib/app.dart` chưa truyền vào, nên bấm nút chỉ hiện "Sắp có" (xem mục 9) |
| | Đủ 3 màn hình Dashboard, Calendar, Transactions | **Đạt** | Transactions và Calendar trên `develop` (PR #8, #10); Dashboard ở PR #12. Có widget test cho cả 3 màn; app đã chạy bằng `flutter run -d windows --dart-define=SEED_MOCK=true` trên Windows 11, log không có exception |
| 2. Kiến trúc, bảo mật, kiểm thử (25%) | Phân tầng đúng, Riverpod + Drift stream | **Đạt (phân hệ Dev)** | Mục 5 |
| | Đủ I1–I5 và biện pháp bảo mật | **Đạt (phân hệ Dev)** | Mục 5 và 6 |
| | `flutter analyze` 0 lỗi, `flutter test` pass | **Đạt** | Mục 2 |
| 3. Git và điều phối AI (20%) | Conventional Commits tiếng Việt; không `Co-Authored-By` AI; không file rác | **Đạt** | Mục 8 |
| | Có `CLAUDE.md` / `AGENTS.md` | **Đạt** | Hai file ở thư mục gốc |
| | Dùng PR template; review chéo | **Đạt** | Mọi PR dùng template. PR #3 do PO duyệt; PR #8, #10 của Tester do Dev duyệt; PR #9 của Tester bị yêu cầu sửa ngày 25/11 (1 test đỏ trên Windows), Tester thêm `.gitattributes`, Dev duyệt lại và Approve ngày 26/11 (102 test xanh trên bản checkout mới, Windows), chờ Tester gộp. Gộp bằng merge commit |
| 4. Tài liệu (20%) | README đầy đủ, ≥ 3 sơ đồ mermaid | **Một phần** | README mục 3 (trạng thái), mục 4 (3 sơ đồ mermaid và bảng quyết định kỹ thuật, PR #6), mục 5 (cài đặt, chạy thử) đã có. Mục 6 (nhật ký kiểm thử, hạn chế) còn trống |

## 4. Bốn quy tắc nghiệp vụ (IMPLEMENTATION_PLAN mục 3)

| # | Quy tắc | Trạng thái | Bằng chứng |
|---|---|---|---|
| 1 | Ngày `dd/MM/yyyy`, fallback `yyyy-MM-dd` | Đạt | `csv_sync_test`: "ngày dự phòng yyyy-MM-dd", "ngày không tồn tại / sai định dạng / năm vô lý bị từ chối"; Sheet Excel hiển thị `dd/MM/yyyy` (`excel_export_test`) |
| 2 | Backdate: lưu đúng `transaction_date` | Đạt | `csv_sync_test`: "file mẫu của đặc tả: lùi ngày…"; `acceptance_flow_test` (giao dịch 28/10 vào `2026-10`) |
| 3 | Tự tạo danh mục khi sync | Đạt | `csv_sync_test` group "I4 - danh mục"; `acceptance_flow_test` (`newCategories == ['Thú cưng']`) |
| 4 | Visual Notes: tự động + gắn dấu | Đạt | Dữ liệu: `csv_sync_test` group "Đáng chú ý"; `database_test`: "Visual Notes…"; `acceptance_flow_test`. Hiển thị: bảng Visual Notes trên Dashboard (PR #12), `dashboard_provider_test` ("Visual Notes: đánh dấu hoặc chi >= 500k có ghi chú"), `dashboard_screen_test` |

## 5. Bất biến dữ liệu I1–I5

| # | Bất biến | Trạng thái | Bằng chứng |
|---|---|---|---|
| I1 | Tiền là `int` | Đạt | `database_test` group "I1 - tiền tệ là int"; `csv_sync_test` group "I1 - số tiền" (từ chối số thập phân, âm, 0, chữ); Excel ghi `IntCellValue`. Quét lại ngày 26/11: không có `RealColumn`. `toDouble()` chỉ xuất hiện trong `cashflow_chart_card.dart`, ngay lúc đưa số vào `fl_chart` để vẽ; mọi tổng, số dư, phần trăm vẫn là `int` |
| I2 | Chỉ xóa CSV sau COMMIT; giữ dòng lỗi | Đạt | `csv_sync_test` group "I2": "DB lỗi → rollback, file CSV giữ nguyên từng byte", "dòng lỗi được giữ nguyên…", "dòng iPhone thêm vào giữa lúc sync không bị mất". Code: `SyncRepository.importRows` chạy trong một `db.transaction` (`sync_repository.dart:25`), file được dọn sau đó bằng ghi file tạm rồi đổi tên (`csv_sync_service.dart:293`) |
| I3 | Báo cáo theo `transaction_date` | Đạt | `database_test` group "I3"; `acceptance_flow_test`; `dashboard_provider_test` (khoản nhập bù 31/10 nằm ở tháng 10). `DateTime.now()` chỉ dùng để đặt tên file xuất, chọn tháng mặc định là "hôm nay" (Lịch, Dashboard) và điền sẵn ngày trong form, không dùng để gom nhóm |
| I4 | Danh mục khớp qua `normalized_name` + `type` | Đạt | `database_test` group "I4"; `csv_sync_test` group "I4 - danh mục" (viết hoa/thường, khoảng trắng, cùng tên khác loại) |
| I5 | UI tự cập nhật | Đạt (tự động) | Tầng dữ liệu: `database_test` group "I5", stream của `watchMonthlySeries`, `watchTotalsUntil`. Giao diện: `transactions_screen_test` (thêm/sửa/xóa cập nhật bảng), `calendar_screen_test` ("lưới và panel tự cập nhật khi DB thay đổi"), `dashboard_screen_test` ("thêm giao dịch thì KPI và Visual Notes tự cập nhật"). Luồng Sync → màn hình đổi theo chưa kiểm trên app vì nút Sync chưa nối |

## 6. Checklist bảo mật (REQUIREMENTS mục 5.2)

| Yêu cầu | Trạng thái | Bằng chứng |
|---|---|---|
| Chống Formula Injection khi xuất Excel (`= + - @ \t \r`) | Đạt | `excel_export_test`: "chống Formula Injection…", "sanitize xử lý tab, CR…"; `acceptance_flow_test` (ô `'=SUM(A1)`); hàm `ExcelExportService.sanitize` |
| Giới hạn kích thước file CSV trước khi đọc | Đạt | Giới hạn 5 MB (`csv_sync_service.dart:21`); `csv_sync_test`: "file quá lớn bị từ chối trước khi đọc" |
| File CSV bị khóa, sai UTF-8: báo tiếng Việt, không crash | Đạt | `csv_sync_test` group "Lỗi file": file không tồn tại, sai mã hóa (file không bị đụng), file đang bị khóa; `sync_feedback_test`: "sync lỗi file: SnackBar báo lỗi, không crash" |
| Truy vấn qua Drift type-safe API, không nối chuỗi SQL | Đạt | `database_test`: "từ khóa chứa ký tự đặc biệt SQL không làm hỏng truy vấn"; từ khóa được lọc phía Dart (`transactions_dao.dart`, `watchFiltered`) |
| Không hard-code đường dẫn máy cá nhân | Đạt | Quét `lib/` tìm `C:\Users`, `D:\phdtron`: 0 kết quả (không tính `.g.dart`). Đường dẫn CSV do người dùng chọn và lưu qua `SettingsRepository` |

## 7. Kịch bản Golden Path

Phần đã kiểm bằng test tự động (không phải thao tác tay trên ứng dụng):

| Bước | Kỳ vọng | Kết quả |
|---|---|---|
| Sync `pending_transactions_nghiem_thu.csv` | Nhập 5/6 dòng, 1 danh mục mới, dòng `abc` bị giữ lại, 4 dòng đã nhập bị xóa khỏi file | Đạt (`acceptance_flow_test`) |
| Kiểm tra tháng | Giao dịch 28/10 thuộc `2026-10`; còn lại thuộc `2026-11` | Đạt |
| Tổng tháng 11 | Chi 1.545.000 ₫ (65.000 + 1.250.000 + 180.000 + 50.000), thu 0 | Đạt |
| Visual Notes tháng 11 | Một mục "Mua bàn phím cơ…" đã bỏ dấu `*` | Đạt |
| Export | Hai Sheet `10-2026`, `11-2026`; không còn `Sheet1`; tiền là ô số; `=SUM(A1)` thành `'=SUM(A1)` | Đạt |

Phần cần thao tác trên ứng dụng thật — **Chưa chạy tay**, điền sau khi nối nút Sync/Export. Ngày 26/11/2026 app đã chạy được trên Windows 11 với dữ liệu mẫu (`SEED_MOCK=true`) và log không có exception, nhưng các bước dưới đây chưa được kiểm theo kịch bản:

| Bước | Kỳ vọng | Kết quả | Ảnh |
|---|---|---|---|
| Bấm Sync iCloud CSV, chọn file mẫu | SnackBar "Đã nhập 5/6 dòng · tạo 1 danh mục mới (Thú cưng) · 1 dòng lỗi được giữ lại trong file"; "Xem chi tiết" liệt kê dòng 6 | _chờ nối nút Sync_ | |
| Dashboard / Calendar / bảng Giao dịch | Tự cập nhật ngay, không khởi động lại (I5) | _chưa chạy tay_ (đã có widget test) | |
| Sửa một giao dịch ở bảng Giao dịch | Dashboard và Calendar đổi theo | _chưa chạy tay_ | |
| Đổi file CSV qua "Cấu hình file CSV" trên Dashboard | Đường dẫn mới được lưu, lần Sync sau đọc file mới | _chưa chạy tay_ (đã có widget test) | |
| Bấm Export Excel, mở bằng Microsoft Excel | Tab `10-2026`, `11-2026`; cột tiền `SUM` được; ô `=SUM(A1)` hiện dạng chữ | _chờ nối nút Export_ | |

## 8. Kiểm tra Git

Chạy lại ngày 26/11/2026 trên nhánh `feat/dashboard-va-bieu-do` (toàn bộ lịch sử từ commit đầu tiên):

- Quét toàn bộ nội dung commit tìm `Co-Authored-By`, `Generated with`, `🤖`, `@claude`: **0 kết quả**.
- Tiêu đề commit không khớp `type(scope): mô tả` (trừ commit merge): **không có**.
- Không có file `build/`, `.dart_tool/`, `.env`, `*.sqlite`, `*.db`, `*.xlsx` trong commit; `.gitignore` đã loại các file cục bộ của công cụ (`.claude/`, `graphify-out/`, …).

## 9. Tồn đọng và rủi ro

1. **PR #11 và #12 chờ review chéo.** Hai PR này (số dư lũy kế, màn Dashboard) do Dev làm thay phần code của PO. Cần một người khác đọc code và chạy thử; gộp #11 trước #12. PR #9 của Tester đã được Dev duyệt (26/11), chờ Tester gộp.
2. **Chưa gắn nút vào giao diện.** `lib/app.dart` cần truyền `onSyncCsv` / `onExportExcel` vào `DesktopShell` và bọc `SyncFeedbackListener` / `ExportFeedbackListener`. `DesktopShell` đã có trên `develop`. Việc này nên làm sau khi #12 vào `develop`, vì cả hai cùng sửa `lib/app.dart`.
3. ~~Dashboard và Calendar chưa có~~: đã có (Calendar ở PR #8, Dashboard ở PR #12). I5 và Visual Notes đã kiểm được ở cả giao diện bằng widget test.
4. **README** mục 3, 4, 5 đã cập nhật. Mục 6 (nhật ký kiểm thử, hạn chế) còn trống, phần của Tester và PO.
5. **Chưa kiểm trên Microsoft Excel thật.** Test đọc lại file bằng thư viện `excel`; cần mở bằng Excel để xác nhận `SUM` và ô công thức.
6. **Ghi chú công thức** (`=SUM(...)`) được lưu nguyên trong DB và chỉ được vô hiệu khi xuất Excel. Nếu sau này có chức năng xuất CSV, cần áp dụng cùng cách xử lý.
7. **Ghi chú nhiều dòng giữ nguyên `\r\n`.** Parser CSV giữ nguyên ký tự xuống dòng trong ô có ngoặc kép, nên file từ iPhone dùng CRLF sẽ đưa `\r` vào ghi chú. Cần quyết định có chuẩn hóa về `\n` khi sync hay không. PR #9 của Tester từng đỏ trên Windows cũng vì lý do tương tự (fixture bị checkout thành CRLF); đã sửa bằng `.gitattributes` (`test/fixtures/*.csv -text`), fixture giữ LF trên mọi máy. Máy đã checkout fixture từ trước phải xóa `test/fixtures/*.csv` rồi `git checkout -- test/fixtures/`.
