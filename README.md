# ClinicCare — app bệnh nhân Android

Source Flutter nằm trong `DATN_GTVT/mobile`, tách khỏi Angular ở `FE/src`. Dùng chung BE Spring Boot hiện tại, không tạo DB hay backend thứ hai.

## Phạm vi đã nối

- Đăng nhập/đăng ký PATIENT; từ chối tài khoản DOCTOR/ADMIN trên app.
- Tìm bác sĩ, lọc chuyên khoa, phân trang; chọn ngày và slot trống, đặt lịch.
- Theo dõi đủ 6 trạng thái; lọc trước phân trang; hủy lịch tương lai còn cho phép.
- Xem kết quả khám của mình, mở chi tiết bằng **appointmentId**.
- Xem thông báo, đánh dấu đọc và số chưa đọc thật.
- Xem/cập nhật hồ sơ, kể cả tài khoản cũ chưa có patient_profiles.

Không có thanh toán, tự ghi kết quả, tự xác nhận lịch, push/email hoặc nhắc lịch tự động. Thông báo làm mới khi chuyển tab, kéo tải lại hoặc đánh dấu đọc; không realtime.

## Chạy trên máy này

Đã chuẩn bị Flutter SDK tại `mobile/.tools/flutter` (Git ignore). Source dùng Flutter 3.47.7 / Dart 3.13.5; SDK không đi cùng commit. Android SDK và JDK vẫn là công cụ cài trên máy.

Mở Android Studio > Device Manager và chạy emulator trước. Dùng `flutter devices` (hoặc `./.tools/flutter/bin/flutter.bat devices`) để lấy ID thực, thay ID ví dụ bên dưới.

Từ thư mục `DATN_GTVT/mobile`:

```powershell
.\tool\dev.ps1 -Action analyze
.\tool\dev.ps1 -Action test
.\tool\dev.ps1 -Action build -JdkPath 'D:/Android Studio/jbr'
.\tool\dev.ps1 -Action run -DeviceId emulator-5554
```

Hoặc nếu `flutter` đã có trong PATH:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9000/api/v1
```

Nếu PowerShell của máy chặn script, dùng các lệnh Flutter trực tiếp; không cần sửa execution policy toàn hệ thống. Lần build đầu Gradle/Android có thể tải thêm SDK/NDK. Nếu báo thiếu license hoặc command-line tools, mở Android Studio > SDK Manager để kiểm tra/cài theo yêu cầu; script không tự chấp nhận license.

## Kết nối BE

- **Android emulator:** mặc định `http://10.0.2.2:9000/api/v1`, ánh xạ tới cổng 9000 trên máy chạy emulator.
- **Điện thoại thật:** cùng mạng với máy chạy BE, truyền IP LAN của máy, ví dụ:

```powershell
.\tool\dev.ps1 -Action run -ApiBaseUrl 'http://192.168.1.10:9000/api/v1' -DeviceId '<device-id>'
```

Thay địa chỉ ví dụ bằng IP thật. `localhost` trên điện thoại là chính điện thoại, không phải laptop. Kiểm tra BE đang chạy và firewall cho phép mạng phát triển. Chưa có địa chỉ deploy thật nên không ghi địa chỉ LAN cố định vào source.

HTTP chỉ bật trong Android **debug manifest**. Bản release yêu cầu `API_BASE_URL` là HTTPS. Đây là source/bản debug phục vụ phát triển; signing release chưa cấu hình để phát hành cửa hàng.

## Phiên đăng nhập và giờ khám

- Token chỉ giữ trong bộ nhớ, không ghi vào file/shared preferences/log. Đóng hẳn app cần đăng nhập lại; chưa có tính năng ghi nhớ đăng nhập. Muốn bổ sung cần tích hợp kho lưu trữ bảo mật trước.
- 401 ở yêu cầu có xác thực đưa về đăng nhập và xóa toàn bộ stack màn riêng. Phản hồi chậm của phiên cũ không đăng xuất phiên mới.
- BE trả LocalDateTime theo `Asia/Ho_Chi_Minh`. `core/clinic_time.dart` chuyển thành UTC+07 rõ ràng, không dựa vào múi giờ điện thoại; ngày sinh giữ dưới dạng ngày, không chuyển UTC.
- Không tự retry POST/PATCH khi lỗi mạng để tránh gửi booking hai lần; người dùng xem lại danh sách rồi thử lại.

## Cấu trúc để đọc code

```text
lib/core/       HTTP, lỗi, quy đổi giờ phòng khám
lib/data/       DTO và endpoint patient
lib/session/    đăng nhập/đăng xuất/hết phiên
lib/ui/         các màn và trạng thái loading/error/empty
lib/app.dart    root và reset navigation khi đổi phiên
lib/main.dart   cấu hình API từ dart-define
```

Hợp đồng kết quả/thông báo nằm ở `docs/CLINICAL_FLOW_API.md` trong repo BE. Các endpoint app dùng được viết trong `lib/data/clinic_repository.dart` để đối chiếu.

## Kiểm chứng và giới hạn

- Flutter analyze và bộ unit/widget tests: xem kết quả lượt triển khai trong `MOBILE_IMPLEMENTATION_REPORT.md`.
- Bộ unit/widget có test transport giả và test HTTP UTF-8 loopback. Đã chạy thêm script HTTP qua BE Spring Boot thật với H2 tạm; chưa nghiệm thu trên emulator/điện thoại hoặc MySQL project.
- Sau khi có BE và tài khoản test: đăng nhập → tìm bác sĩ → chọn slot tương lai → đặt → theo dõi/hủy; dùng lịch đã hoàn thành trên web để kiểm tra kết quả; thử thông báo và cập nhật hồ sơ.

Tài liệu công cụ chính thức: [cài Flutter](https://docs.flutter.dev/install/manual), [build Android](https://docs.flutter.dev/deployment/android).
