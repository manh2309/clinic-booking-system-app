import 'dart:convert';

import 'package:clinic_booking_patient/core/api_client.dart';

typedef Handler = Future<ResponsePacket> Function(
  String method,
  Uri uri,
  Map<String, String> headers,
  Object? body,
);

class FakeTransport implements ApiTransport {
  FakeTransport(this.handle);
  final Handler handle;
  int calls = 0;
  @override
  Future<ResponsePacket> send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) {
    calls++;
    return handle(method, uri, headers, body);
  }

  @override
  void close() {}
}

ResponsePacket ok(dynamic data) => ResponsePacket(
  200,
  jsonEncode({'code': 1000, 'message': 'Success', 'data': data}),
);
ResponsePacket failed(int status, int code) => ResponsePacket(
  status,
  jsonEncode({'code': code, 'message': 'error', 'data': null}),
);
Map<String, dynamic> pageOf(
  List<dynamic> content, {
  int page = 0,
  int total = 0,
  bool last = true,
}) => {
  'content': content,
  'page': page,
  'size': 10,
  'totalElements': total,
  'totalPages': 1,
  'last': last,
};
Map<String, dynamic> patientLogin({String role = 'PATIENT'}) => {
  'accessToken': 'test-token',
  'account': {
    'id': 1,
    'username': 'patient',
    'email': 'patient@test.com',
    'roleName': role,
    'isActive': true,
  },
};
