import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final int? code;
  @override
  String toString() => message;
}

class ResponsePacket {
  const ResponsePacket(this.status, this.body);
  final int status;
  final String body;
}

abstract interface class ApiTransport {
  Future<ResponsePacket> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  );
  void close();
}

class IoApiTransport implements ApiTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);
  @override
  Future<ResponsePacket> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final request = await _client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 12));
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    return ResponsePacket(response.statusCode, text);
  }

  @override
  void close() => _client.close(force: true);
}

class ApiClient {
  ApiClient({required String baseUrl, ApiTransport? transport})
    : base = Uri.parse(baseUrl.replaceFirst(RegExp(r'/+$'), '')),
      _transport = transport ?? IoApiTransport() {
    if (!base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw const ApiException('Địa chỉ máy chủ không hợp lệ.');
    }
  }
  final Uri base;
  final ApiTransport _transport;
  String? _token;
  int _session = 0;
  void Function()? onUnauthorized;
  bool get hasToken => _token != null;
  void setToken(String value) {
    _session++;
    _token = value;
  }

  void clearToken() {
    _session++;
    _token = null;
  }

  void close() => _transport.close();

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final session = _session;
    if (authenticated && _token == null) {
      throw const ApiException('Vui lòng đăng nhập lại.', status: 401);
    }
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    try {
      final response = await _transport.send(method, uri, {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        if (authenticated && _token != null) 'Authorization': 'Bearer $_token',
      }, body);
      // Phản hồi của phiên cũ không được làm thoát tài khoản vừa đăng nhập.
      if (authenticated && session != _session) {
        throw const ApiException('Phiên đăng nhập đã thay đổi.');
      }
      if (authenticated && response.status == 401) {
        clearToken();
        onUnauthorized?.call();
        throw const ApiException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          status: 401,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['code'] is! num) {
        throw const ApiException('Không đọc được phản hồi từ máy chủ.');
      }
      final code = (decoded['code'] as num).toInt();
      if (response.status < 200 || response.status >= 300 || code != 1000) {
        throw ApiException(
          _message(code, response.status),
          status: response.status,
          code: code,
        );
      }
      return decoded['data'];
    } on TimeoutException {
      throw const ApiException(
        'Kết nối quá thời gian. Hãy kiểm tra mạng và thử lại.',
      );
    } on SocketException {
      throw const ApiException(
        'Không kết nối được máy chủ. Hãy kiểm tra mạng.',
      );
    } on HttpException {
      throw const ApiException('Kết nối bị gián đoạn. Vui lòng thử lại.');
    } on FormatException {
      throw const ApiException('Không đọc được phản hồi từ máy chủ.');
    }
  }

  String _message(int code, int status) => switch (code) {
    1102 => 'Tên đăng nhập đã được sử dụng.',
    1103 => 'Email đã được sử dụng.',
    1104 => 'Tên đăng nhập hoặc mật khẩu không đúng.',
    1105 => 'Tài khoản đang bị khóa. Vui lòng liên hệ quản trị viên.',
    2001 || 2007 => 'Bác sĩ hiện không tiếp nhận đặt khám.',
    3007 => 'Khung giờ vừa được đặt hoặc không còn khả dụng. Hãy chọn lại.',
    3008 => 'Lịch hẹn không còn cho phép thao tác này. Hãy tải lại danh sách.',
    3009 => 'Bạn đã có lịch khám trùng thời gian.',
    5001 => 'Lịch hẹn này chưa có kết quả được lưu.',
    1001 => 'Thông tin chưa hợp lệ. Hãy kiểm tra các ô đã nhập.',
    _ when status == 401 => 'Tên đăng nhập hoặc mật khẩu không đúng.',
    _ when status == 403 => 'Bạn không có quyền thực hiện thao tác này.',
    _ when status == 404 => 'Không tìm thấy dữ liệu này.',
    _ when status == 409 => 'Dữ liệu vừa thay đổi. Hãy tải lại và thử lại.',
    _ => 'Chưa thực hiện được yêu cầu. Vui lòng thử lại.',
  };
}

Map<String, dynamic> objectMap(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const ApiException('Dữ liệu máy chủ chưa đúng định dạng.');
  }
  return value;
}

String errorText(Object error) =>
    error is ApiException ? error.message : 'Có lỗi xảy ra. Vui lòng thử lại.';
