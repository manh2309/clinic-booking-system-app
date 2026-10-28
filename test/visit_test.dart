import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/core/api_client.dart';
import 'package:clinic_booking_patient/data/clinic_repository.dart';
import 'package:clinic_booking_patient/data/models.dart';
import 'package:clinic_booking_patient/ui/appointments_page.dart';

import 'fakes.dart';

Appointment appointment(String? visitStatus) => Appointment.from({
  'id': 8,
  'status': 'CONFIRMED',
  'doctorName': 'Bác sĩ thử nghiệm',
  'startAt': '2099-10-25T09:00:00',
  'endAt': '2099-10-25T09:30:00',
  if (visitStatus != null)
    'visit': {
      'id': 1,
      'status': visitStatus,
      'checkedInAt': '2099-10-25T08:45:00',
      if (visitStatus == 'IN_PROGRESS') 'startedAt': '2099-10-25T09:00:00',
    },
});
void main() {
  test('checked-in and active visits cannot be canceled by patient', () {
    final now = DateTime.utc(2099, 10, 25, 1);
    expect(appointment(null).canCancelAt(now), isTrue);
    expect(appointment('WAITING').canCancelAt(now), isFalse);
    expect(appointment('IN_PROGRESS').canCancelAt(now), isFalse);
    expect(appointment('CANCELED').canCancelAt(now), isTrue);
  });
  for (final status in ['WAITING', 'IN_PROGRESS', 'CANCELED']) {
    testWidgets('visit $status displays on a phone without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = ClinicRepository(
        ApiClient(
          baseUrl: 'http://test/api/v1',
          transport: FakeTransport(
            (method, uri, headers, body) async => ok(null),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppointmentCard(
                appointment: appointment(status),
                repository: repo,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(visitLabels[status]!), findsOneWidget);
      if (status != 'CANCELED') expect(find.text('Hủy lịch hẹn'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
