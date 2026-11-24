# Báo cáo nghiệm thu — phân hệ Dữ liệu & Đồng bộ (Dev)

- **Phạm vi:** `lib/data/**`, `lib/features/icloud_sync/**`, `lib/features/excel_export/**` (PR #3 từ nhánh `feat/dong-bo-csv-va-excel`, đã gộp vào `develop` ở commit 587624e).
- **Ngày lập:** 24/11/2026.
- **Cách đọc:** mỗi mục có trạng thái và bằng chứng. `Đạt` = có test tự động hoặc kết quả lệnh ở mục 2. `Chờ tích hợp` = phụ thuộc phân hệ của PO/Tester chưa nằm trong `develop`. `Chưa chạy tay` = chưa kiểm bằng thao tác trên ứng dụng thật.

> Báo cáo này chỉ khẳng định những gì đã chạy được. Các bước cần giao diện (nút Sync/Export, Dashboard, Calendar) được ghi rõ là chưa kiểm ở mục 7 và 9.

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

Chạy lại ngày 24/11/2026 trên `develop` sau khi gộp PR #3 (nhánh `docs/bao-cao-nghiem-thu` đã gộp `origin/develop`):

| Lệnh | Kết quả |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | Không có file cần định dạng lại |
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!` — **77 test** |

Phân bổ test:

| File | Số test | Nội dung chính |
|---|---:|---|
| `test/csv_sync_test.dart` | 29 | Đồng bộ CSV, I1, I2, I4, đáng chú ý, ngày/loại, lỗi file |
| `test/database_test.dart` | 25 | Seed, I1, I3, I4, I5, bộ lọc, Dashboard/Calendar, chuỗi nhiều tháng |
| `test/sync_feedback_test.dart` | 10 | Thông điệp tiếng Việt và widget phản hồi Sync/Export |
| `test/excel_export_test.dart` | 8 | Sheet `MM-YYYY`, kiểu số, tóm tắt, Formula Injection |
| `test/controllers_test.dart` | 4 | `SyncController`, `ExportController` |
| `test/acceptance_flow_test.dart` | 1 | Sync → Export với CSV mẫu nghiệm thu |

## 3. Đối chiếu tiêu chí nghiệm thu (REQUIREMENTS mục 6)

| Nhóm (trọng số) | Tiêu chí | Trạng thái | Bằng chứng / ghi chú |
|---|---|---|---|
| 1. Sản phẩm chạy thực tế (35%) | Sync bộ dữ liệu có lùi ngày, danh mục mới, ghi chú `*`, 1 dòng sai số tiền: không crash, không mất dữ liệu | **Đạt (logic)** | `acceptance_flow_test.dart`; `csv_sync_test.dart` group "I2" |
| | Export ra `.xlsx` tách Sheet `MM-YYYY` | **Đạt (logic)** | `acceptance_flow_test.dart`; `excel_export_test.dart` |
| | Bấm nút **Sync iCloud CSV** / **Export Excel** trên giao diện | **Chờ tích hợp** | `DesktopShell` (nhánh Tester) nhận `onSyncCsv`/`onExportExcel`; `lib/app.dart` chưa truyền vào (xem mục 9) |
| | Đủ 3 màn hình Dashboard, Calendar, Transactions | **Chờ tích hợp** | Transactions đã có ở nhánh Tester; Dashboard và Calendar chưa có |
| 2. Kiến trúc, bảo mật, kiểm thử (25%) | Phân tầng đúng, Riverpod + Drift stream | **Đạt (phân hệ Dev)** | Mục 5 |
| | Đủ I1–I5 và biện pháp bảo mật | **Đạt (phân hệ Dev)** | Mục 5 và 6 |
| | `flutter analyze` 0 lỗi, `flutter test` pass | **Đạt** | Mục 2 |
| 3. Git và điều phối AI (20%) | Conventional Commits tiếng Việt; không `Co-Authored-By` AI; không file rác | **Đạt** | Mục 8 |
| | Có `CLAUDE.md` / `AGENTS.md` | **Đạt** | Hai file ở thư mục gốc |
| | Dùng PR template; review chéo | **Đạt** | PR #3 theo template, được PO duyệt (Approved) rồi gộp bằng merge commit |
| 4. Tài liệu (20%) | README đầy đủ, ≥ 3 sơ đồ mermaid | **Chưa** | README mục 4.1 và 4.2 còn trống; đang làm ở PR riêng (mục 9, số 4) |

## 4. Bốn quy tắc nghiệp vụ (IMPLEMENTATION_PLAN mục 3)

| # | Quy tắc | Trạng thái | Bằng chứng |
|---|---|---|---|
| 1 | Ngày `dd/MM/yyyy`, fallback `yyyy-MM-dd` | Đạt | `csv_sync_test`: "ngày dự phòng yyyy-MM-dd", "ngày không tồn tại / sai định dạng / năm vô lý bị từ chối"; Sheet Excel hiển thị `dd/MM/yyyy` (`excel_export_test`) |
| 2 | Backdate: lưu đúng `transaction_date` | Đạt | `csv_sync_test`: "file mẫu của đặc tả: lùi ngày…"; `acceptance_flow_test` (giao dịch 28/10 vào `2026-10`) |
| 3 | Tự tạo danh mục khi sync | Đạt | `csv_sync_test` group "I4 - danh mục"; `acceptance_flow_test` (`newCategories == ['Thú cưng']`) |
| 4 | Visual Notes: tự động + gắn dấu | Đạt (dữ liệu) | `csv_sync_test` group "Đáng chú ý"; `database_test`: "Visual Notes…"; `acceptance_flow_test`. Phần hiển thị thuộc Dashboard của PO — **Chờ tích hợp** |

## 5. Bất biến dữ liệu I1–I5

| # | Bất biến | Trạng thái | Bằng chứng |
|---|---|---|---|
| I1 | Tiền là `int` | Đạt | `database_test` group "I1 - tiền tệ là int"; `csv_sync_test` group "I1 - số tiền" (từ chối số thập phân, âm, 0, chữ); Excel ghi `IntCellValue`; không có `double`/`RealColumn` trong `lib/data`, `icloud_sync`, `excel_export` (đã quét bằng `Select-String`, kết quả 0) |
| I2 | Chỉ xóa CSV sau COMMIT; giữ dòng lỗi | Đạt | `csv_sync_test` group "I2": "DB lỗi → rollback, file CSV giữ nguyên từng byte", "dòng lỗi được giữ nguyên…", "dòng iPhone thêm vào giữa lúc sync không bị mất". Code: `SyncRepository.importRows` chạy trong một `db.transaction` (`sync_repository.dart:25`), file được dọn sau đó bằng ghi file tạm rồi đổi tên (`csv_sync_service.dart:293`) |
| I3 | Báo cáo theo `transaction_date` | Đạt | `database_test` group "I3"; `acceptance_flow_test`. `DateTime.now()` trong phân hệ Dev chỉ dùng để đặt tên file xuất (`export_controller.dart:57`), không dùng để gom nhóm |
| I4 | Danh mục khớp qua `normalized_name` + `type` | Đạt | `database_test` group "I4"; `csv_sync_test` group "I4 - danh mục" (viết hoa/thường, khoảng trắng, cùng tên khác loại) |
| I5 | UI tự cập nhật | **Một phần** | Tầng dữ liệu: `database_test` group "I5" và test stream của `watchMonthlySeries` — stream phát lại khi thêm giao dịch. Phía giao diện (Dashboard, Calendar, bảng) — **Chờ tích hợp** |

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

Phần cần thao tác trên ứng dụng thật — **Chưa chạy tay**, điền sau khi tích hợp:

| Bước | Kỳ vọng | Kết quả | Ảnh |
|---|---|---|---|
| Bấm Sync iCloud CSV, chọn file mẫu | SnackBar "Đã nhập 5/6 dòng · tạo 1 danh mục mới (Thú cưng) · 1 dòng lỗi được giữ lại trong file"; "Xem chi tiết" liệt kê dòng 6 | _chưa chạy_ | |
| Dashboard / Calendar / bảng Giao dịch | Tự cập nhật ngay, không khởi động lại (I5) | _chờ tích hợp_ | |
| Sửa một giao dịch ở bảng Giao dịch | Dashboard và Calendar đổi theo | _chờ tích hợp_ | |
| Bấm Export Excel, mở bằng Microsoft Excel | Tab `10-2026`, `11-2026`; cột tiền `SUM` được; ô `=SUM(A1)` hiện dạng chữ | _chưa chạy_ | |

## 8. Kiểm tra Git

Chạy trên `develop` sau khi gộp PR #3 (587624e):

- Quét toàn bộ nội dung commit tìm `Co-Authored-By`, `Generated with`, `🤖`, `@claude`: **0 kết quả**.
- Tiêu đề commit không khớp `type(scope): mô tả` (trừ commit merge): **không có**.
- Không có file `build/`, `.dart_tool/`, `.env`, `*.sqlite`, `*.db`, `*.xlsx` trong commit; `.gitignore` đã loại các file cục bộ của công cụ (`.claude/`, `graphify-out/`, …).

## 9. Tồn đọng và rủi ro

1. **Review chéo PR #3 đã xong.** PO đã duyệt và PR đã gộp. Tester chưa đọc phần này, nên nếu có thể nên nhờ thêm một lượt chạy thử trên máy khác.
2. **Chưa gắn nút vào giao diện.** `lib/app.dart` cần truyền `onSyncCsv` / `onExportExcel` vào `DesktopShell` và bọc `SyncFeedbackListener` / `ExportFeedbackListener`. Việc này làm sau khi PR Transactions của Tester vào `develop` (nhánh `feat/giao-dich-va-lich` chưa có PR và đang tụt so với `develop`); `top_action_bar.dart` thuộc thư mục của Tester.
3. **Dashboard và Calendar chưa có**, nên I5 và quy tắc Visual Notes mới kiểm được ở tầng dữ liệu.
4. **README** mục 3 (trạng thái tính năng) và mục 4 (3 sơ đồ mermaid, bảng quyết định kỹ thuật) chưa cập nhật. Dev đang làm ở một PR riêng.
5. **Chưa kiểm trên Microsoft Excel thật.** Test đọc lại file bằng thư viện `excel`; cần mở bằng Excel để xác nhận `SUM` và ô công thức.
6. **Ghi chú công thức** (`=SUM(...)`) được lưu nguyên trong DB và chỉ được vô hiệu khi xuất Excel. Nếu sau này có chức năng xuất CSV, cần áp dụng cùng cách xử lý.
