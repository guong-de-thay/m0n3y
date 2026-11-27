# CLAUDE.md — Quy tắc cho AI Agent khi làm việc trong dự án `m0n3y`

Ứng dụng quản lý thu chi cá nhân, Flutter Windows Desktop, offline-first.
Đặc tả đầy đủ: `IMPLEMENTATION_PLAN.md`. Quy chế nhóm: `REQUIREMENTS.md`.

## 1. Kiến trúc & phân tầng (một chiều)

```
SQLite (Drift) → DAO → Repository → Riverpod (StreamProvider / AsyncNotifier) → Widget
```

- `lib/data/` — Drift tables, DAO, repository. **Chỉ nơi này được đụng DB.**
- `lib/features/<tên>/{domain,providers,presentation,services}/` — theo feature.
- `lib/core/` — dùng chung: constants, theme, utils, widgets.
- `presentation` chỉ gọi `providers`; `providers` gọi `repositories/services`.
- **Tuyệt đối không** viết SQL / gọi DAO / `AppDatabase` trực tiếp trong Widget.
- Không dùng `setState` cho dữ liệu toàn cục; dùng Riverpod. Danh sách/tổng hợp
  phải đi qua `Stream` của Drift (`watch`) để UI tự cập nhật (I5).
- Mọi truy vấn dùng Drift type-safe API, **không nối chuỗi SQL**.
- Không hard-code đường dẫn của một máy cụ thể (ví dụ `C:\Users\...`).

## 2. Bất biến dữ liệu (không được vi phạm)

| # | Bất biến |
|---|---|
| I1 | Tiền là `int` (VNĐ) ở DB, Model và mọi phép cộng/trừ. Cấm `double`/`float`. |
| I2 | Chỉ xóa dòng trong `pending_transactions.csv` **sau khi** `COMMIT` DB thành công. Dòng lỗi phải được giữ lại. |
| I3 | Mọi báo cáo (Dashboard, Calendar, tên Sheet Excel `MM-YYYY`) tính theo `transaction_date`, **không** theo `created_at` / `DateTime.now()`. |
| I4 | Danh mục khớp qua `normalized_name = name.trim().toLowerCase()` + `type`; không tạo trùng. |
| I5 | UI tự cập nhật sau sync / thêm / sửa / xóa, không cần khởi động lại. |

Quy ước khác:
- Ngày hiển thị, đọc CSV, xuất Excel: `dd/MM/yyyy` (parse fallback `yyyy-MM-dd`).
- `year_month` (`YYYY-MM`) do `TransactionsDao` tự tính; **không** tự điền ở nơi khác.
- Hiển thị tiền: `1.250.000 ₫`.

## 3. Bảo mật

- Chuỗi `Note`/`Category` khi ghi Excel/CSV bắt đầu bằng `= + - @ \t \r` → thêm `'` ở đầu.
- Giới hạn kích thước file CSV trước khi đọc; bắt lỗi file bị khóa / sai UTF-8 và
  báo bằng tiếng Việt thân thiện, không để app crash.

## 4. Lệnh kiểm tra (chạy trước mỗi PR)

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
# Sau khi sửa bảng Drift:
dart run build_runner build
```

Chạy với dữ liệu mẫu: `flutter run -d windows --dart-define=SEED_MOCK=true`.

## 5. Git & quy tắc commit (bắt buộc)

- Làm việc trên repo gốc; **không push thẳng `main`**, không `git push --force`
  lên `main`/`develop`. Nhánh tính năng tách từ `develop`: `feat/…`, `fix/…`,
  `docs/…`, `test/…`.
- Conventional Commits, mô tả tiếng Việt có dấu ≤ 72 ký tự:
  `feat(sync): tự động tạo danh mục mới khi đồng bộ CSV`.
  `type`: feat, fix, refactor, test, docs, style, chore.
  `scope`: db, sync, excel, dashboard, calendar, transactions, core.
- Mỗi commit một thay đổi logic; commit ngay khi test xanh.
- **TUYỆT ĐỐI KHÔNG** thêm dấu vết AI vào commit/PR/code: không `Co-Authored-By`,
  không "Generated with…", không `@claude`, không icon 🤖. Người commit chịu 100%
  trách nhiệm. Kiểm tra: `git log --format=%B -n 5`.
- Không commit: `build/`, `.dart_tool/`, `.env`, `*.sqlite`, `*.db`, `*.xlsx` sinh ra khi chạy thử.
- **File cục bộ không thuộc dự án thì cho vào `.gitignore`, không commit.** Gồm:
  file sinh ra để tối ưu cho máy/công cụ của riêng một người (cache, đồ thị
  `graphify-out/`, cấu hình/bộ nhớ của AI agent như `.claude/`, `.agents/`, ghi chú
  bàn giao `HANDOFF.md`…). Tiêu chí: người clone repo không cần nó để build,
  chạy, test hay hiểu dự án. Khi tạo/phát hiện file như vậy (thấy trong
  `git status` ở dạng `??`), thêm vào `.gitignore` trong cùng phiên, rồi mới commit.
- Mở PR vào `develop` theo `.github/pull_request_template.md`, cần ≥ 1 người review khác.

## 6. Cách giao việc cho AI

- Giao việc nhỏ, có biên giới rõ (một file/module + test), không "viết cả app".
- Gặp lỗi: tự đọc log, ghi phán đoán nguyên nhân trước rồi mới nhờ AI sửa.
- Tự đọc lại bằng mắt các hàm lõi (sync, export, tính tổng) để kiểm tra I1–I5.
- **Chưa rõ thì hỏi lại người dùng, không tự đoán.** Áp dụng khi chưa chắc về
  hướng làm, phạm vi việc, nghiệp vụ, phần nào thuộc ai (mục 7), hoặc khi spec
  (`IMPLEMENTATION_PLAN.md`, `REQUIREMENTS.md`) không nói / nói mâu thuẫn. Dừng và
  hỏi ngắn gọn trước khi code; nếu được, kèm 2–3 phương án và nêu phương án đề xuất.
  Việc tự kiểm chứng được bằng code, `git log` hoặc tài liệu thì tự tra, không hỏi.

## 7. Phân công thư mục (tránh conflict)

| Vai trò | Thư mục |
|---|---|
| Dev | `lib/data/**`, `lib/features/icloud_sync/**`, `lib/features/excel_export/**` |
| Tester | `lib/core/widgets/**`, `lib/features/transactions/**`, `lib/features/calendar_view/**` |
| PO | `lib/core/theme/**`, `lib/core/utils/**`, `lib/features/dashboard/**` |

Muốn đổi schema (`app_database.dart`) hoặc interface DAO/Repository: báo Dev,
sửa trong một PR riêng và chạy lại `build_runner`.

## 8. Ghi chú môi trường

- `window_manager` được ghim `^0.5.x`. Bản 0.7 phụ thuộc `nativeapi` cần trình
  biên dịch C++ ngay cả khi `flutter test`/`analyze`, và đổi API.
- Build Windows cần Visual Studio (workload "Desktop development with C++") và
  bật Developer Mode (symlink) trong Windows Settings.

## 9. Trạng thái hiện tại (cập nhật cuối mỗi phiên làm việc)

Đây là bản chụp tiến độ để phiên mới không phải khám phá lại repo. Nếu mâu thuẫn
với code/`git log`, tin code và `git log`, rồi sửa mục này.

Cập nhật ngày 26/11/2026.

- Nhánh đang làm: `feat/dashboard-va-bieu-do` (PR #12), tách từ
  `feat/so-du-luy-ke` (PR #11). Dev làm thay phần code Dashboard/Theme/Utils của PO.
- **Đã có trên `develop`** (đã gộp PR #1–#8 và #10; 99 test):
  - `lib/data/`: schema Drift, `CategoriesDao`, `TransactionsDao`,
    `TransactionRepository`, `SettingsRepository`, `SyncRepository`
    (ghi lô CSV trong một transaction), `mock_data.dart`, `data_providers.dart`.
  - `lib/features/icloud_sync/`, `lib/features/excel_export/`: service,
    controller, `SyncFeedbackListener`, `ExportFeedbackListener`.
  - `lib/core/widgets/`: `DesktopShell`, `TopActionBar` (Tester, PR #8).
  - `lib/features/transactions/`, `lib/features/calendar_view/` (Tester, PR #8 và
    PR #10: bắt lỗi xóa, tự đảo khoảng ngày lọc).
  - CI GitHub Actions (PR #7): format, analyze, test trên Ubuntu cho mọi PR.
  - Tài liệu: README mục 3 và 4 (3 sơ đồ mermaid, PR #6),
    `docs/BAO_CAO_NGHIEM_THU.md` (PR #5), `docs/ban-do-du-an.html` (PR #2, #4).
- **PR đang mở:**
  - #11 `feat/so-du-luy-ke`: `watchTotalsUntil` (số dư lũy kế đến hết một tháng).
    Phải gộp trước #12.
  - #12 `feat/dashboard-va-bieu-do`: `core/theme` (`AppTheme`, `AppColors`),
    `core/utils/formatters.dart`, màn Dashboard (bộ chọn tháng, 3 KPI, biểu đồ cột,
    PieChart, Visual Notes), `icloud_sync/presentation/csv_path_dialog.dart`,
    cập nhật tài liệu; 119 test.
  - #9 (Tester) `test/csv-edge-cases`: Dev đã Approve (26/11), chờ Tester gộp. Tester đã
    thêm `.gitattributes` (`test/fixtures/*.csv -text`) để fixture giữ LF khi checkout
    trên Windows; bản checkout mới chạy 102 test xanh. Sau khi #9 vào `develop`, ai đã
    checkout fixture từ trước (như `pending_transactions_nghiem_thu.csv`, đang CRLF)
    phải xóa `test/fixtures/*.csv` rồi `git checkout -- test/fixtures/`, nếu không Git
    báo file đã sửa.
- **Chưa có:** nút Sync/Xuất Excel chưa nối. `lib/app.dart` chưa truyền
  `onSyncCsv`/`onExportExcel` vào `DesktopShell` và chưa bọc
  `SyncFeedbackListener`/`ExportFeedbackListener`, nên bấm nút chỉ hiện "Sắp có".
  `main` mới có tài liệu.
- **Việc tiếp theo:** (1) review rồi gộp #11, #12; Tester gộp #9; (2) Dev: PR gắn Sync/Export
  vào `DesktopShell` (sau khi #12 vào `develop`, vì cùng sửa `lib/app.dart`);
  (3) Tester: chuyển `transaction_formatters.dart` sang `core/utils/formatters.dart`;
  (4) chạy tay Golden Path (kể cả mở xlsx bằng Excel thật), điền mục 7 báo cáo
  nghiệm thu và README mục 6; (5) cân nhắc chuẩn hóa `\r\n` thành `\n` trong ghi chú
  khi sync CSV; (6) PR `develop` → `main`, gắn tag `v1.0.0-mvp`.
- Đồng bộ local với remote sau mỗi PR đã gộp: `git fetch --prune`,
  `git fetch origin develop:develop`, rồi `git branch -d <nhánh đã gộp>`.
- Chạy `flutter` trên máy này: `D:\flutter\bin` chưa nằm trong PATH của shell,
  thêm vào PATH trước khi chạy lệnh mục 4. Máy đã bật Developer Mode và cài
  workload C++ của Visual Studio, nên `flutter run -d windows` chạy được.
- Xem giao diện khi không mở được app (mục 10): viết một test tạm. Test này nạp font
  Roboto và MaterialIcons bằng `FontLoader` từ
  `<flutter>/bin/cache/artifacts/material_fonts`, chụp `RepaintBoundary.toImage()`
  ra PNG rồi mở ảnh xem. Đóng DB ở `tearDown`, không đóng trong `runAsync`, vì
  đóng trong `runAsync` làm test treo. Xóa test tạm, không commit.
- Quy trình kết phiên: chạy mục 4, commit theo mục 5, rồi cập nhật mục này.
- Tiếp tục đúng mạch: `claude -c`; chọn phiên cũ: `claude -r`.

## 10. Kiểm tra kết quả cần render

Với bất kỳ thứ gì chỉ đánh giá đúng khi nhìn kết quả đã render
(giao diện, đồ thị, sơ đồ, tài liệu, slide, email HTML, v.v.):

- Không kết luận "xong" hay "trông ổn" chỉ dựa trên việc đọc code.
- Hãy render ra và xem kết quả thực tế bằng công cụ sẵn có
  (trình duyệt/MCP chụp màn hình, hoặc chuyển sang ảnh rồi đọc ảnh đó).
- So với yêu cầu ban đầu, tự sửa nếu lệch, rồi xem lại sau khi sửa.
- Nếu không có cách nào để xem kết quả render, nói rõ là chưa kiểm tra bằng mắt
  được và nêu điều gì cần người dùng xem giúp. Không đoán.
- Chỉ áp dụng khi thay đổi ảnh hưởng đến hiển thị. Bỏ qua với thay đổi logic,
  backend hoặc cấu hình thuần túy, để tiết kiệm token.
