import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/core/api_client.dart';
import 'package:clinic_booking_patient/core/clinic_time.dart';
import 'package:clinic_booking_patient/data/clinic_repository.dart';
import 'package:clinic_booking_patient/data/models.dart';
import 'package:clinic_booking_patient/ui/doctors_page.dart';
import 'package:clinic_booking_patient/ui/appointments_page.dart';
import 'package:clinic_booking_patient/ui/notifications_page.dart';
import 'package:clinic_booking_patient/ui/profile_page.dart';
import 'package:clinic_booking_patient/ui/records_page.dart';

import 'fakes.dart';

ClinicRepository repository(FakeTransport transport) => ClinicRepository(
  ApiClient(baseUrl: 'http://test/api/v1', transport: transport)
    ..setToken('test-token'),
);
Doctor doctor() => Doctor.from({
  'id': 1,
  'fullName': 'Bác sĩ kiểm thử',
  'specialtyName': 'Tim mạch',
});
Map<String, dynamic> slot(int id, DateTime day) => {
  'id': id,
  'startAt': '${dateKey(day)}T09:00:00',
  'endAt': '${dateKey(day)}T09:30:00',
};

void main() {
  testWidgets('thirty available days keep booking times visible on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = clinicToday();
    final repo = repository(
      FakeTransport((method, uri, headers, body) async {
        if (uri.path.endsWith('/available-dates')) {
          return ok(
            List.generate(
              30,
              (index) => {
                'date': dateKey(today.add(Duration(days: index))),
                'availableSlots': 1,
              },
            ),
          );
        }
        return ok([slot(1, DateTime.parse(uri.queryParameters['date']!))]);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookingPage(repository: repo, doctor: doctor()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('09:00–09:30').hitTestable(), findsOneWidget);
    expect(find.text('Xác nhận đặt lịch').hitTestable(), findsOneWidget);
    final next = today.add(const Duration(days: 10));
    final target = find.byKey(ValueKey('available-day-${dateKey(next)}'));
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('available-days-strip')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Ngày khám: ${dateKey(next)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('booking automatically opens the next day with availability', (
    tester,
  ) async {
    final tomorrow = clinicToday().add(const Duration(days: 1));
    final repo = repository(
      FakeTransport((method, uri, headers, body) async {
        if (uri.path.endsWith('/available-dates')) {
          return ok([
            {'date': dateKey(tomorrow), 'availableSlots': 1},
          ]);
        }
        return ok(
          uri.queryParameters['date'] == dateKey(tomorrow)
              ? [slot(1, tomorrow)]
              : [],
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookingPage(repository: repo, doctor: doctor()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ngày khám: ${dateKey(tomorrow)}'), findsOneWidget);
    expect(find.text('09:00–09:30'), findsOneWidget);
  });
  testWidgets('late available dates do not override a manual date selection', (
    tester,
  ) async {
    final dates = Completer<ResponsePacket>();
    final chosen = clinicToday().add(const Duration(days: 2));
    final repo = repository(
      FakeTransport((method, uri, headers, body) {
        if (uri.path.endsWith('/available-dates')) return dates.future;
        return Future.value(
          ok(
            uri.queryParameters['date'] == dateKey(chosen)
                ? [slot(1, chosen)]
                : [],
          ),
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookingPage(repository: repo, doctor: doctor()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(chosen);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    dates.complete(
      ok([
        {
          'date': dateKey(clinicToday().add(const Duration(days: 1))),
          'availableSlots': 1,
        },
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ngày khám: ${dateKey(chosen)}'), findsOneWidget);
    expect(find.text('09:00–09:30'), findsOneWidget);
  });
  test('invalid available date counts and normalized dates are rejected', () {
    expect(
      () => AvailableDay.from({'date': '2030-01-01', 'availableSlots': 0}),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => AvailableDay.from({'date': '2030-02-31', 'availableSlots': 1}),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets(
    'changing booking day clears selection and ignores a late old response',
    (tester) async {
      final old = Completer<ResponsePacket>();
      final next = Completer<ResponsePacket>();
      var requests = 0;
      final repo = repository(
        FakeTransport((m, u, h, b) {
          if (u.path.endsWith('/available-dates')) return Future.value(ok([]));
          requests++;
          return requests == 1 ? old.future : next.future;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPage(repository: repo, doctor: doctor()),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final pickerContext = tester.element(find.byType(DatePickerDialog));
      final tomorrow = clinicToday().add(const Duration(days: 1));
      Navigator.of(pickerContext).pop(tomorrow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      next.complete(ok([slot(2, tomorrow)]));
      await tester.pumpAndSettle();
      expect(find.text('09:00–09:30'), findsOneWidget);
      old.complete(
        ok([
          {
            'id': 1,
            'startAt': '${dateKey(clinicToday())}T10:00:00',
            'endAt': '${dateKey(clinicToday())}T10:30:00',
          },
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('10:00–10:30'), findsNothing);
      expect(find.text('09:00–09:30'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận đặt lịch'),
      );
      expect(button.onPressed, isNull);
    },
  );
  testWidgets('failed slot loading is not shown as no free slots', (
    tester,
  ) async {
    final repo = repository(
      FakeTransport((m, u, h, b) async => failed(500, 9999)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookingPage(repository: repo, doctor: doctor()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Chưa có khung giờ trống'), findsNothing);
  });
  testWidgets('cancelled appointments cannot expose a cancellation button', (
    tester,
  ) async {
    final a = Appointment.from({
      'id': 1,
      'status': 'CANCELED',
      'doctorName': 'Doctor',
      'startAt': '2030-01-01T09:00:00',
      'endAt': '2030-01-01T09:30:00',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentCard(
            appointment: a,
            repository: repository(
              FakeTransport((m, u, h, b) async => ok(null)),
            ),
            onChanged: () {},
          ),
        ),
      ),
    );
    expect(find.text('Hủy lịch hẹn'), findsNothing);
  });
  testWidgets('an old patient with no profile can save optional null values', (
    tester,
  ) async {
    Map? submitted;
    final repo = repository(
      FakeTransport((method, uri, headers, body) async {
        if (method == 'PUT') {
          submitted = body as Map;
          return ok(null);
        }
        return ok({
          'patientProfileId': null,
          'fullName': null,
          'email': 'patient@test.com',
          'phone': '0962964504',
          'dateOfBirth': null,
          'gender': null,
          'address': null,
        });
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilePage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    final name = find.byType(TextFormField).first;
    await tester.enterText(name, 'Patient Name');
    await tester.ensureVisible(find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();
    expect(submitted?['dateOfBirth'], isNull);
    expect(submitted?['gender'], isNull);
    expect(submitted?['fullName'], 'Patient Name');
  });
  testWidgets('failed read marking does not pretend a notice was read', (
    tester,
  ) async {
    final n = Notice.from({
      'id': 1,
      'appointmentId': 2,
      'type': 'APPOINTMENT_BOOKED',
      'title': 'Thông báo',
      'message': 'Lịch hẹn',
      'read': false,
      'createdAt': null,
    });
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticeCard(
            notice: n,
            repository: repository(
              FakeTransport((m, u, h, b) async => failed(500, 9999)),
            ),
            onChanged: () => changed++,
            onAppointments: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();
    expect(changed, 0);
    expect(find.text('Chưa đọc'), findsOneWidget);
  });
  for (final width in [390.0, 768.0]) {
    testWidgets('long result renders without overflow at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = MedicalRecord.from({
        'appointmentId': 1,
        'doctorName': 'Bác sĩ kiểm thử',
        'diagnosis': ('Kết quả kiểm thử ' * 100),
        'examinationNotes': 'Ghi nhận',
        'treatmentAdvice': 'Hướng dẫn',
        'startAt': '2030-01-01T09:00:00',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [RecordCard(record: record)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
