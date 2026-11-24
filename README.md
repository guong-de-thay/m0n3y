<div align="center">

# 💰 `m0n3y` — Quản Lý Tài Chính Cá Nhân (Windows Desktop)

**Dự án Thực chiến Phát triển Sản phẩm với AI Agents (48h Product Sprint)**  
*Hệ thống quản lý thu chi Offline-first trên Windows Desktop kết hợp đồng bộ nhanh từ iPhone qua iCloud Drive*

<p>
  <img src="https://img.shields.io/badge/Platform-Windows%20Desktop-0078D6?logo=windows&logoColor=white" alt="Windows Desktop">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/State-Riverpod-2B6CB0" alt="Riverpod">
  <img src="https://img.shields.io/badge/Database-SQLite%20(Drift)-003B57?logo=sqlite&logoColor=white" alt="SQLite Drift">
  <img src="https://img.shields.io/badge/Sprint-48%20Hours-orange" alt="48h Sprint">
</p>

</div>

---

## 1. Giới thiệu & Bối cảnh Dự án

Repository này được thiết lập bởi **Hà Tiến Triệu ([@trieuwu](https://github.com/trieuwu))** với vai trò **Khách hàng (Project Sponsor) & Người hướng dẫn (Tech Mentor)**.

Đây là bài tập thực chiến kéo dài **2 ngày (48 giờ)** dành cho đội ngũ 3 thành viên nhằm rèn luyện đồng thời hai năng lực cốt lõi:
1. **Làm chủ quy trình điều phối AI Agents** (Claude Code, Antigravity, Cursor...) để xây dựng phần mềm có kỷ luật kiến trúc, không phụ thuộc mù quáng vào AI.
2. **Trải nghiệm quy trình phát triển sản phẩm thực tế với khách hàng**: từ đọc hiểu đặc tả, tự tổ chức đội ngũ theo mô hình **PO – Dev – Tester**, quản lý nhánh Git trực tiếp trên repository gốc, thiết kế luồng hệ thống, đảm bảo bảo mật/toàn vẹn dữ liệu cho đến bàn giao nghiệm thu.

### Tài liệu Dự án (Bắt buộc đọc kỹ trước khi code)

| Tài liệu | Mục đích |
| :--- | :--- |
| [**`REQUIREMENTS.md`**](REQUIREMENTS.md) | **Đề bài & Quy chế làm việc**: Quy định về vai trò (PO, Dev, Tester), quy trình Git & nhánh trên repo gốc, kỷ luật dùng AI Agents, yêu cầu tự định hướng MVP, vẽ sơ đồ luồng xử lý, tiêu chuẩn bảo mật và tiêu chí nghiệm thu. |
| [**`IMPLEMENTATION_PLAN.md`**](IMPLEMENTATION_PLAN.md) | **Đặc tả kỹ thuật & Hướng dẫn triển khai**: Yêu cầu nghiệp vụ của khách hàng, Tech Stack bắt buộc, lược đồ SQLite (Drift), cấu trúc thư mục và gợi ý chia việc trong 2 ngày. |
| [**`.github/pull_request_template.md`**](.github/pull_request_template.md) | Mẫu Pull Request bắt buộc phải điền đầy đủ mỗi khi tạo PR gộp code. |

---

## 2. Đội ngũ Phát triển & Phân công Vai trò

> **Hướng dẫn cho nhóm**: Trong Pull Request đầu tiên (`docs/cap-nhat-thong-tin-nhom`), 3 thành viên tự thảo luận để nhận 3 vai trò điều phối (**PO**, **Dev**, **Tester**) và điền đầy đủ thông tin vào bảng dưới đây.
>
> ⚠️ **QUY TẮC BẮT BUỘC ("100% Hands-on Coding")**: Việc chia role `PO` – `Dev` – `Tester` là để phân rõ trách nhiệm đầu mối (ai chốt nghiệp vụ, ai gác cổng kiến trúc, ai gác cổng chất lượng), **TUYỆT ĐỐI KHÔNG CÓ NGHĨA LÀ PO HAY TESTER CHỈ NGỒI VIẾT TÀI LIỆU / CHỜ TEST**. Cả 3 thành viên đều là **Core Developers**, mỗi người bắt buộc phải trực tiếp cầm 1 trong 3 nhánh code chính (~33% khối lượng code ứng dụng) và dùng AI Agents đẩy tốc độ phát triển lên tối đa! Khi chấm điểm sẽ kiểm tra `git log` đóng góp code thực tế của cả 3 người.

| Vai trò (Role) | Họ và Tên | GitHub | Nhánh làm việc chính | Phân hệ kỹ thuật phụ trách |
| :--- | :--- | :--- | :--- | :--- |
| **Project Sponsor / Mentor** | Hà Tiến Triệu | [@trieuwu](https://github.com/trieuwu) | `main` | Thiết lập bài toán, review kiến trúc & nghiệm thu sản phẩm |
| **PO (Product Owner)** | Nguyễn Tú Anh | [@nguyentuanh-fw](https://github.com/nguyentuanh-fw) | `feat/dashboard-va-bieu-do` | Quản lý phạm vi MVP, luồng nghiệp vụ, tài liệu hóa & phân hệ Dashboard, biểu đồ, theme (`lib/features/dashboard/`, `lib/core/theme/`, `lib/core/utils/`) |
| **Dev (Lead Developer)** | Phùng Hải Đăng | [@TemuBroCode](https://github.com/TemuBroCode) | `feat/dong-bo-csv-va-excel` | Kiến trúc cốt lõi, Database/Core Services, review tích hợp & phân hệ Database, đồng bộ CSV iCloud, xuất Excel (`lib/data/`, `lib/features/icloud_sync/`, `lib/features/excel_export/`) |
| **Tester (QA / QC Lead)** | Đàm Thuận Khải | [@tkai-better](https://github.com/tkai-better) | `feat/giao-dich-va-lich` | Thiết kế Test Cases, kiểm thử biên/bảo mật, CI/Test tự động & phân hệ khung ứng dụng, Giao dịch, Lịch chi tiêu (`lib/core/widgets/`, `lib/features/transactions/`, `lib/features/calendar_view/`) |

---

## 3. Định hướng MVP & Trạng thái Tính năng

> **Hướng dẫn cho nhóm**: Cập nhật trạng thái thực tế của từng hạng mục trong quá trình phát triển theo 3 nhãn:
> - **`ĐÃ CÓ`**: Đã chạy ổn định và có kiểm thử trên nhánh `develop` / `main`.
> - **`SẼ LÀM`**: Nằm trong phạm vi cam kết của MVP 2 ngày và đang triển khai.
> - **`HƯỚNG`**: Định hướng mở rộng sau MVP (Post-MVP Phase 2), đã chuẩn bị sẵn nền móng trong thiết kế.

| Hạng mục / Tính năng | Mô tả & Bất biến kỹ thuật | Trạng thái |
| :--- | :--- | :---: |
| **Tầng Cơ sở dữ liệu SQLite (Drift ORM)** | Lưu trữ `categories`, `transactions`, `sync_batches`. Tiền tệ bắt buộc lưu kiểu `INTEGER` (VNĐ) để không sai số dấu phẩy động. | `ĐÃ CÓ` |
| **Đồng bộ CSV từ iCloud Drive (`CsvSyncService`)** | Đọc `pending_transactions.csv` chuẩn ngày `dd/MM/yyyy`, hỗ trợ lùi ngày (`transaction_date`), tự tạo danh mục mới, xóa trắng file an toàn sau khi commit DB. Phần logic đã xong và có test; nút bấm trên giao diện chờ gắn vào khung ứng dụng. | `ĐÃ CÓ` |
| **Màn hình Tổng quan (`Dashboard`)** | 3 thẻ KPI (Tổng số dư, Thu tháng, Chi tháng), biểu đồ dòng tiền & cơ cấu danh mục (`fl_chart`), bảng **Visual Notes** (chi tiêu lớn + ghi chú gắn dấu `*`). | `SẼ LÀM` |
| **Màn hình Lịch chi tiêu (`Calendar View`)** | Bố cục 2 panel màn hình ngang: Lưới lịch tháng bên trái hiển thị `+Thu / -Chi` từng ngày + Panel chi tiết giao dịch của ngày đang chọn bên phải. | `SẼ LÀM` |
| **Màn hình Quản lý Giao dịch (`Transactions`)** | Bảng dữ liệu Desktop, bộ lọc đa chiều (khoảng ngày, danh mục, loại thu/chi, từ khóa ghi chú) và hộp thoại Thêm / Sửa / Xóa giao dịch. | `SẼ LÀM` |
| **Xuất Báo cáo Excel (`ExcelExportService`)** | Xuất file `.xlsx` tự động tách từng Sheet theo tháng (`MM-YYYY`), có tổng kết Thu - Chi - Dư và chống lỗi CSV/Formula Injection. Phần logic đã xong và có test; nút bấm trên giao diện chờ gắn vào khung ứng dụng. | `ĐÃ CÓ` |
| **Bóc tách Ảnh Hóa đơn từ Điện thoại (OCR/Vision)** | Ném ảnh hóa đơn / màn hình chuyển khoản từ điện thoại lên $\rightarrow$ bóc tách số tiền, ngày giờ, tên quán $\rightarrow$ chuẩn hóa & đẩy vào Database. | `HƯỚNG` |

---

## 4. Kiến trúc & Các Luồng Hệ thống (Do nhóm tự thiết kế & bổ sung)

> **Yêu cầu**: Nhóm phát triển tự vẽ và cập nhật các sơ đồ `mermaid` cùng thuyết minh kiến trúc vào khu vực này theo đúng yêu cầu tại Mục 4 của file [`REQUIREMENTS.md`](REQUIREMENTS.md).

### 4.1. Sơ đồ Kiến trúc Tổng thể
`<!-- Nhóm vẽ sơ đồ Mermaid kiến trúc các tầng Presentation - Application/Providers - Domain - Data tại đây -->`

### 4.2. Luồng Hoạt động Người dùng (User Flow) & Luồng Xử lý Dữ liệu (Data Sequence Flow)
`<!-- Nhóm vẽ sơ đồ Mermaid luồng xử lý đồng bộ CSV, xử lý lỗi/rollback và luồng xuất Excel tại đây -->`

### 4.3. Các Quyết định Kỹ thuật & Bảo mật (Technical Decisions & Security)
`<!-- Nhóm điền bảng các quyết định kỹ thuật, cách đảm bảo tính nguyên tử (Atomicity) khi đọc/xóa file CSV và các biện pháp bảo mật đã áp dụng -->`

| Quyết định kỹ thuật / Bảo mật | Lý do lựa chọn | Cách kiểm chứng |
| :--- | :--- | :--- |
| `<!-- Điền quyết định 1 -->` | `<!-- Vì sao? -->` | `<!-- Test / Lệnh kiểm tra -->` |
| `<!-- Điền quyết định 2 -->` | `<!-- Vì sao? -->` | `<!-- Test / Lệnh kiểm tra -->` |

---

## 5. Hướng dẫn Cài đặt & Chạy thử (Do nhóm hoàn thiện)

> **Yêu cầu**: Nhóm cập nhật chính xác từng câu lệnh để Khách hàng có thể clone repo về và chạy thử thành công chỉ trong vài bước.

```powershell
# 1. Cài đặt dependencies
flutter pub get

# 2. Sinh mã nguồn Drift Database (nếu cần)
dart run build_runner build --delete-conflicting-outputs

# 3. Kiểm tra tĩnh & Chạy bộ kiểm thử tự động
flutter analyze
flutter test

# 4. Khởi chạy ứng dụng trên Windows Desktop
flutter run -d windows
```

---

## 6. Nhật ký Kiểm thử & Hạn chế Hiện tại (Do Tester & PO hoàn thiện)

### 6.1. Kết quả Kiểm thử
`<!-- Tester cập nhật danh sách các bài test đã vượt qua, các kịch bản biên (edge cases) đã test -->`

### 6.2. Hạn chế & Hướng Cải tiến
`<!-- Nhóm thẳng thắn ghi nhận các điểm còn hạn chế của bản MVP sau 2 ngày và đề xuất hướng xử lý -->`

---

## 7. Nhận xét & Nghiệm thu của Khách hàng / Mentor

<!-- KHU VỰC NÀY DÀNH RIÊNG CHO HÀ TIẾN TRIỆU (@trieuwu) — ĐỘI NGŨ PHÁT TRIỂN KHÔNG CHỈNH SỬA MỤC NÀY -->

- **Đánh giá Quy trình Git & Quản lý nhánh**: *(Chờ nghiệm thu)*
- **Đánh giá Kỹ năng Điều phối AI Agents & Chất lượng Code**: *(Chờ nghiệm thu)*
- **Đánh giá Sản phẩm Demo (MVP) & Xử lý tình huống biên/bảo mật**: *(Chờ nghiệm thu)*
