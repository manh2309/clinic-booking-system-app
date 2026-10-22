## Cập nhật 20/10/2026 — gợi ý ngày khám

Booking gọi available-dates để tự mở ngày gần nhất có chỗ và hiện chip ngày/số slot; vẫn có lịch chọn tay. Có loading/error riêng cho discovery, không chặn chọn tay khi discovery lỗi. Request cũ không ghi đè ngày mới, chọn ngày lại xóa slot cũ. Số chỗ cập nhật sau tải slot; POST booking vẫn kiểm tra server.

Flutter analyze sạch, 28 test pass, APK debug mới build pass. HTTP Dart client chạy với BE riêng 19092 và MySQL test riêng 13316: profile/auth, mẫu tuần, ngày còn chỗ, book/confirm/cancel, ngày biến mất khi kín và trở lại sau cancel, notice/read và medical record 404. Không tác động DB thật; server và container test đã dừng. Log: build/available-days-tests.log, available-days-apk.log, available-days-http-smoke.log. Chưa chạy lại UI emulator hoặc đọc kết quả khám dương tính qua HTTP trong lượt này. Source tại D:/of/DATN_GTVT/mobile, ngoài FE web.

# App bệnh nhân — lượt đầu, 19/10/2026

## Đã làm

Source ở `DATN_GTVT/mobile`, Android package `vn.cliniccare.clinic_booking_patient`; Flutter 3.47.7, Dart 3.13.5, Material 3 và bản địa hóa tiếng Việt. SDK tải trong `.tools/flutter` đã Git ignore; Gradle 9.3.1 dùng distribution chính thức trực tiếp, ghim SHA-256. Không sửa framework/source Angular để chứa code Dart.

Màn chính nối API BE hiện có: đăng nhập/đăng ký PATIENT, tìm bác sĩ/lọc chuyên khoa, chọn ngày/slot, đặt lịch, lịch hẹn/lọc sáu trạng thái/hủy, hồ sơ, kết quả khám và thông báo. Các danh sách phân trang theo BE, lỗi khác danh sách rỗng, thao tác ghi chặn gửi lặp và không tự retry.

Token chỉ trong bộ nhớ. 401 của phiên hiện tại xóa token và navigator stack; phản hồi phiên cũ không làm thoát phiên mới. API chỉ nhận role PATIENT/ROLE_PATIENT, không suy từ email/tên hoặc gửi role giả. Ngày giờ LocalDateTime của phòng khám được diễn giải UTC+07, ngày sinh giữ dạng ngày. POST JSON mã hóa UTF-8 rõ ràng, có regression test HTTP thật với tên tiếng Việt.

## Bằng chứng kiểm tra

| Kiểm tra | Kết quả |
|---|---|
| flutter analyze | No issues found |
| flutter test | 24 test pass |
| flutter build apk --debug | Pass, APK tại build/app/outputs/flutter-apk/app-debug.apk |
| Dart client qua HTTP tới BE Spring Boot thật | Pass trên BE 127.0.0.1:19091 + H2 in-memory riêng |
| Angular tests sau khi thêm mobile và sửa web | 60 test ChromeHeadless pass |
| Angular build development | Pass |

24 test app gồm contract endpoint/body/filter, không giữ token role khác, chống retry booking, 401/phiên cũ, giờ Việt Nam, quyền hủy theo trạng thái/giờ, form đăng nhập, xóa stack khi logout, đổi ngày và phản hồi slot cũ, lỗi tải không biến thành rỗng, profile thiếu dữ liệu, đánh dấu đọc khi lỗi, render kết quả 390px/768px và UTF-8 qua server loopback.

HTTP smoke đã chạy bằng chính `IoApiTransport`/`ClinicRepository`: tạo dữ liệu test qua API admin, đăng ký/login patient, profile tiếng Việt và cập nhật, chuyên khoa/bác sĩ, ca/slot, đặt → doctor xác nhận → patient hủy, slot được mở lại, thông báo/đánh dấu đọc/số chưa đọc, danh sách kết quả rỗng và chi tiết chưa có trả 404. BE được ép datasource `jdbc:h2:mem:clinic_mobile_smoke`, không dùng MySQL project; đã dừng sau kiểm tra. Không tạo endpoint fixture trong BE và không ghi mật khẩu/token thật vào source/log.

Lượt này chỉ xác minh response đọc kết quả rỗng/404 qua HTTP app; kết quả dương tính có test UI/contract app và bộ test BE của đợt 5, chưa nghiệm thu dương tính trên thiết bị.

## Giới hạn còn lại

- Chưa cài/chạy APK trên emulator hoặc điện thoại thật; chưa có kiểm tra thao tác toàn màn hình/native network trên thiết bị. APK hiện build với API mặc định dành cho emulator: `http://10.0.2.2:9000/api/v1`.
- Điện thoại thật cần build/run với IP LAN của laptop theo README; chưa có host triển khai HTTPS.
- Chưa ghi nhớ đăng nhập; chưa lưu token lâu dài. Không có push/email, nhắc lịch tự động hoặc thay đổi mật khẩu.
- Bản debug không phải bản phát hành cửa hàng. Signing release chưa cấu hình; release không chấp nhận API HTTP.
- Không commit/push. Không xem test app/H2 là bằng chứng đã nghiệm thu với dữ liệu MySQL đang dùng.

## Web bổ sung cùng lượt

- Hồ sơ doctor đọc `/doctors/me`, hiển thị tên/chuyên khoa/bằng cấp/giới thiệu/trạng thái thật; không còn quảng bá chỉnh chứng chỉ/đổi mật khẩu chưa có. Giữ chuyên môn do admin quản lý, không tự mở quyền sửa.
- Menu ở màn hình hẹp cho admin/doctor/patient dùng lại đúng danh sách route của layout, không dẫn sang role khác. Sidebar desktop giữ nguyên.
- 4 test bổ sung cho profile/error/retry/render 390/1440px và menu theo workspace; tổng web hiện 60 test pass.

Hướng dẫn chạy: README.md. Script hỗ trợ: tool/dev.ps1. Smoke có ghi dữ liệu: tool/http_smoke.dart, chỉ chạy với backend/DB test cô lập và cờ cho phép rõ ràng; không đưa nó vào quy trình test tự động trên DB project.

## Chỉnh input và giao diện sau khi chạy emulator
- Username đăng nhập/đăng ký tắt handwriting; username không tự sửa, gợi ý hay viết hoa. Không lọc ký tự hoặc sửa controller trong lúc gõ để giữ con trỏ/composing.
- Input bo góc, nền trắng; button cao tối thiểu 48; card trắng có border; header và bottom navigation đồng nhất.
- Danh sách rỗng có icon/làm mới, không hiện Trang 1 · Tổng 0; chỉ hiện chuyển trang khi có nhiều trang.
- Có test kiểm tra cấu hình username và giữ vị trí con trỏ khi chỉnh giữa chuỗi. Widget test không xác nhận hành vi Gboard trên emulator; cần Stop/Run và thử bàn phím thật lại.
