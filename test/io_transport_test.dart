import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/core/api_client.dart';

class NativeHttp extends HttpOverrides {}

void main() {
  test('real HTTP sends Vietnamese JSON as UTF-8', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
      );
      final received = server.first.then((request) async {
        final content = jsonDecode(
          await request.cast<List<int>>().transform(utf8.decoder).join(),
        ) as Map;
        expect(content['fullName'], 'Nguyễn Tiến Mạnh');
        expect(request.headers.contentType?.charset, 'utf-8');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 1000,
            'data': {'fullName': content['fullName']},
          }),
        );
        await request.response.close();
      });
      try {
        final response = await client.request(
          '/auth/register',
          method: 'POST',
          authenticated: false,
          body: {'fullName': 'Nguyễn Tiến Mạnh'},
        );
        expect(response['fullName'], 'Nguyễn Tiến Mạnh');
        await received;
      } finally {
        client.close();
        await server.close(force: true);
      }
    }, NativeHttp());
  });
}
