import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/core/api_client.dart';
import 'package:clinic_booking_patient/data/clinic_repository.dart';
import 'package:clinic_booking_patient/data/models.dart';

import 'fakes.dart';

void main() {
  test('login rejects other roles without keeping a token', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      transport: FakeTransport(
        (method, uri, headers, body) async => ok(patientLogin(role: 'DOCTOR')),
      ),
    );
    await expectLater(
      ClinicRepository(client).login('doctor', 'password'),
      throwsA(isA<ApiException>()),
    );
    expect(client.hasToken, isFalse);
  });
  test(
    'calls the patient endpoint with pagination, filter and token',
    () async {
      final transport = FakeTransport((method, uri, headers, body) async {
        expect(uri.path, '/api/v1/appointments/me');
        expect(uri.queryParameters, {
          'page': '2',
          'size': '10',
          'status': 'EXPIRED',
        });
        expect(headers['Authorization'], 'Bearer test-token');
        return ok(pageOf([], page: 2, total: 25));
      });
      final client = ApiClient(
        baseUrl: 'http://test/api/v1/',
        transport: transport,
      )..setToken('test-token');
      final result = await ClinicRepository(client)
          .appointments(2, status: 'EXPIRED');
      expect(result.total, 25);
      expect(result.page, 2);
    },
  );
  test(
    'booking body contains only the chosen slot and is not retried',
    () async {
      final transport = FakeTransport((method, uri, headers, body) async {
        expect(method, 'POST');
        expect(uri.path, '/api/v1/appointments');
        expect(body, {'slotId': 7});
        return failed(409, 3007);
      });
      final client = ApiClient(
        baseUrl: 'http://test/api/v1',
        transport: transport,
      )..setToken('test-token');
      await expectLater(
        ClinicRepository(client).book(7),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 3007)),
      );
      expect(transport.calls, 1);
    },
  );
  test(
    'loads a result by appointment id rather than medical record id',
    () async {
      final transport = FakeTransport((method, uri, headers, body) async {
        expect(uri.path, '/api/v1/patient/me/medical-records/7');
        return ok({
          'appointmentId': 7,
          'doctorName': 'Doctor',
          'diagnosis': 'Result',
          'startAt': '2030-01-01T09:00:00',
        });
      });
      final client = ApiClient(
        baseUrl: 'http://test/api/v1',
        transport: transport,
      )..setToken('test-token');
      expect((await ClinicRepository(client).record(7)).appointmentId, 7);
    },
  );
  test('read marking uses the owned endpoint', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      transport: FakeTransport((method, uri, headers, body) async {
        expect(method, 'PATCH');
        expect(uri.path, '/api/v1/notifications/me/8/read');
        return ok(null);
      }),
    )..setToken('test-token');
    await ClinicRepository(client).readNotice(8);
  });
  test('profile preserves optional nulls in the update contract', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      transport: FakeTransport((method, uri, headers, body) async {
        expect(method, 'PUT');
        expect(uri.path, '/api/v1/patient/me/profile/update');
        expect((body as Map)['gender'], isNull);
        expect(body['dateOfBirth'], isNull);
        return ok(null);
      }),
    )..setToken('test-token');
    await ClinicRepository(client).saveProfile({
      'fullName': 'Patient Name',
      'email': 'patient@test.com',
      'gender': null,
      'dateOfBirth': null,
    });
  });
  test('401 clears the current session once', () async {
    var expired = 0;
    final client = ApiClient(
      baseUrl: 'http://test',
      transport: FakeTransport((m, u, h, b) async => failed(401, 1002)),
    )..setToken('test-token');
    client.onUnauthorized = () => expired++;
    await expectLater(
      client.request('/patient/me/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, 1);
    expect(client.hasToken, isFalse);
  });
  test('a late 401 cannot invalidate a newer login', () async {
    final response = Completer<ResponsePacket>();
    var expired = 0;
    final client = ApiClient(
      baseUrl: 'http://test',
      transport: FakeTransport((m, u, h, b) => response.future),
    )..setToken('old-token');
    client.onUnauthorized = () => expired++;
    final request = client.request('/notifications/me');
    final assertion = expectLater(request, throwsA(isA<ApiException>()));
    client.setToken('new-token');
    response.complete(failed(401, 1002));
    await assertion;
    expect(expired, 0);
    expect(client.hasToken, isTrue);
  });
  test('invalid response data is not converted to an empty page', () {
    expect(
      () => PageData<Doctor>.from({'content': []}, Doctor.from),
      throwsA(isA<ApiException>()),
    );
  });
  test('rejects base URLs containing credentials or query strings', () {
    expect(
      () => ApiClient(baseUrl: 'http://name:password@test/api'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ApiClient(baseUrl: 'http://test/api?token=secret'),
      throwsA(isA<ApiException>()),
    );
  });
}
