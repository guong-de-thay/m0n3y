# AGENTS.md — Quy tắc cho mọi AI Agent làm việc trong dự án `m0n3y`

Áp dụng cho mọi agent (Codex, Cursor, Copilot, Gemini, Claude, v.v.).
Nội dung đồng bộ với `CLAUDE.md`: sửa một file thì sửa cả file kia.

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

Dữ liệu có sẵn để dựng UI (không cần tự viết lại):
- Provider: `lib/data/providers/data_providers.dart` (`transactionRepositoryProvider`,
  `categoriesProvider`, `settingsRepositoryProvider`).
- Repository: `lib/data/repositories/transaction_repository.dart`
  (`watchFiltered`, `watchDailyCashflow`, `watchMonthTotals`, `watchAllTimeTotals`,
  `watchCategoryBreakdown`, `watchVisualNotes`, `add/update/delete`).
- Model: `lib/data/models/transaction_models.dart`.
- Hằng số: `lib/core/constants/default_categories.dart`; tiện ích ngày:
  `lib/core/utils/year_month.dart`.

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
- Không commit bí mật, `.env`, file DB/Excel sinh ra khi chạy thử.

## 4. Lệnh kiểm tra (chạy trước mỗi PR)

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
# Sau khi sửa bảng Drift:
dart run build_runner build
```

Chạy với dữ liệu mẫu: `flutter run -d windows --dart-define=SEED_MOCK=true`.

Mọi PR phải qua cả 3 lệnh đầu. Không sửa test cho khớp code sai; nếu test đỏ
thì sửa nguyên nhân.

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
  không "Generated with…", không `@<tên agent>`, không icon 🤖. Áp dụng cho mọi
  agent, kể cả khi công cụ của agent tự chèn mặc định — phải xóa trước khi commit.
  Người commit chịu 100% trách nhiệm. Kiểm tra: `git log --format=%B -n 5`.
- Không commit: `build/`, `.dart_tool/`, `.env`, `*.sqlite`, `*.db`, `*.xlsx` sinh ra khi chạy thử.
- Mở PR vào `develop` theo `.github/pull_request_template.md`, cần ≥ 1 người review khác.

## 6. Cách làm việc với agent

- Nhận việc nhỏ, có biên giới rõ (một file/module + test), không "viết cả app".
- Chỉ sửa trong thư mục của vai trò đang giao việc (mục 7). Cần sửa ngoài phạm vi
  thì dừng lại và báo người dùng, không tự sửa.
- Gặp lỗi: đọc log, ghi phán đoán nguyên nhân rồi mới sửa.
- Tự đọc lại các hàm lõi (sync, export, tính tổng) để kiểm tra I1–I5.
- Không thêm package mới hoặc đổi phiên bản trong `pubspec.yaml` nếu chưa được yêu cầu.
- Không sửa file `*.g.dart` bằng tay; sinh lại bằng `build_runner`.

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
- Template Flutter mới dùng `package:material_ui/material_ui.dart`; giữ nguyên
  kiểu import hiện có trong dự án.
- Build Windows cần Visual Studio (workload "Desktop development with C++") và
  bật Developer Mode (symlink) trong Windows Settings.
