import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/core/clinic_time.dart';
import 'package:clinic_booking_patient/data/models.dart';

void main() {
  test('09:00 at clinic always represents 02:00 UTC', () {
    final instant = parseClinicTime('2030-10-15T09:00:00');
    expect(instant, DateTime.utc(2030, 10, 15, 2));
    expect(clockLabel(instant), '09:00');
    expect(appointmentTime(instant), '15/10/2030 09:00');
  });
  test('offset timestamps do not get the clinic offset applied twice', () {
    expect(clockLabel(parseClinicTime('2030-10-15T02:00:00Z')), '09:00');
    expect(clockLabel(parseClinicTime('2030-10-15T09:00:00+07:00')), '09:00');
  });
  test('cancel is blocked from the start time and for terminal states', () {
    final raw = {
      'id': 1,
      'status': 'CONFIRMED',
      'doctorName': 'Doctor',
      'startAt': '2030-10-15T09:00:00',
      'endAt': '2030-10-15T09:30:00',
    };
    final appointment = Appointment.from(raw);
    expect(appointment.canCancelAt(DateTime.utc(2030, 10, 15, 1, 59)), isTrue);
    expect(appointment.canCancelAt(DateTime.utc(2030, 10, 15, 2)), isFalse);
    for (final status in ['CANCELED', 'COMPLETED', 'EXPIRED', 'NO_SHOW']) {
      expect(
        Appointment.from({...raw, 'status': status})
            .canCancelAt(DateTime.utc(2030, 10, 15, 1)),
        isFalse,
      );
    }
  });
}
