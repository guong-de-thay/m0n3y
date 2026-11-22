## 1. Mục tiêu của Pull Request

<!-- PR này giải quyết task nào? Liên kết tới phân hệ hoặc yêu cầu nào trong IMPLEMENTATION_PLAN.md / REQUIREMENTS.md? -->

- **Người thực hiện**: <!-- Họ tên & Vai trò (PO / Dev / Tester) -->
- **Phân hệ (`scope`)**: <!-- db | sync | excel | dashboard | calendar | transactions | core | docs -->

## 2. Tóm tắt Thay đổi Chính

- 
- 

## 3. Kiểm chứng & Kết quả Thực nghiệm (Verification)

<!-- Nếu là PR giao diện: Đính kèm ảnh chụp màn hình (Screenshot). -->
<!-- Nếu là PR logic / Database / Sync CSV / Excel: Dán kết quả chạy `flutter test` hoặc mô tả kịch bản dữ liệu đã test. -->

```text
# Dán kết quả chạy `flutter analyze` và `flutter test` tại đây
```

## 4. Checklist Kỷ luật Kỹ thuật & Bảo mật (Bắt buộc kiểm tra trước khi Merge)

- [ ] **Kỷ luật Git & AI**: Đã kiểm tra `git log`, **TUYỆT ĐỐI KHÔNG** có dòng `Co-Authored-By` của AI, không có icon 🤖, và commit message đúng chuẩn Conventional Commits tiếng Việt.
- [ ] **Không có file rác**: Không commit thư mục `build/`, `.dart_tool/`, `.env`, hoặc file database `.sqlite` / `.db` cá nhân.
- [ ] **Chất lượng Code**: `flutter analyze` không báo lỗi (0 errors) và `flutter test` đều vượt qua (all tests passed).
- [ ] **Toàn vẹn Dữ liệu & Bảo mật**:
  - [ ] Số tiền luôn được xử lý bằng kiểu số nguyên (`int`), không dùng `double`/`float`.
  - [ ] Mọi thống kê, lịch và Sheet Excel đều dựa trên `transaction_date` (hỗ trợ lùi ngày), không dùng `created_at`.
  - [ ] Đã xử lý ngoại lệ (`try/catch`) an toàn khi đọc/ghi file và chống lỗi Formula Injection khi xuất Excel.
- [ ] **Review chéo**: Đã có ít nhất 1 thành viên khác trong nhóm (`PO` / `Dev` / `Tester`) đọc code và chạy kiểm tra thử.
