import 'dart:io';

import 'package:clinic_booking_patient/core/api_client.dart';
import 'package:clinic_booking_patient/core/clinic_time.dart';
import 'package:clinic_booking_patient/data/clinic_repository.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

// Chỉ chạy khi đã bật cờ cho DB test riêng; script tạo tài khoản và booking giả.
Future<void> main() async {
  if (Platform.environment['CLINIC_ALLOW_SMOKE_WRITES'] !=
      'isolated-test-database') {
    stderr.writeln(
      'Từ chối ghi dữ liệu: chỉ dùng script với BE/DB test cô lập.',
    );
    exitCode = 2;
    return;
  }
  final base =
      Platform.environment['CLINIC_SMOKE_BASE_URL'] ??
      'http://127.0.0.1:19091/api/v1';
  final adminName = Platform.environment['CLINIC_SMOKE_ADMIN'];
  final adminPassword = Platform.environment['CLINIC_SMOKE_PASSWORD'];
  if (adminName == null || adminPassword == null) {
    stderr.writeln('Thiếu tài khoản admin test trong biến môi trường.');
    exitCode = 2;
    return;
  }
  final admin = ApiClient(baseUrl: base),
      doctorClient = ApiClient(baseUrl: base),
      patientClient = ApiClient(baseUrl: base);
  try {
    final auth = objectMap(
      await admin.request(
        '/auth/login',
        method: 'POST',
        authenticated: false,
        body: {'username': adminName, 'password': adminPassword},
      ),
    );
    admin.setToken(auth['accessToken'] as String);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final specialty = objectMap(
      await admin.request(
        '/admin/specialties',
        method: 'POST',
        body: {
          'name': 'Mobile smoke $suffix',
          'description': 'Dữ liệu kiểm thử cô lập',
        },
      ),
    );
    final doctorName = 'smoke_doc_$suffix';
    const password = 'LocalSmoke_12345';
    final doctor = objectMap(
      await admin.request(
        '/admin/doctors',
        method: 'POST',
        body: {
          'username': doctorName,
          'password': password,
          'email': '$doctorName@test.invalid',
          'phone': '0962964504',
          'fullName': 'Bác sĩ kiểm thử mobile',
          'specialtyId': specialty['id'],
        },
      ),
    );
    final doctorAuth = objectMap(
      await doctorClient.request(
        '/auth/login',
        method: 'POST',
        authenticated: false,
        body: {'username': doctorName, 'password': password},
      ),
    );
    doctorClient.setToken(doctorAuth['accessToken'] as String);
    final wall = clinicWallTime(DateTime.now());
    final start = DateTime.utc(wall.year, wall.month, wall.day + 1, 9);
    await admin.request(
      '/admin/doctors/${doctor['id']}/weekly-schedules',
      method: 'POST',
      body: {
        'dayOfWeek': start.weekday,
        'startTime': '09:00:00',
        'endTime': '09:30:00',
        'effectiveFrom': dateKey(start),
        'effectiveTo': dateKey(start),
      },
    );
    final repo = ClinicRepository(patientClient);
    final username = 'smoke_patient_$suffix';
    await repo.register({
      'username': username,
      'password': password,
      'fullName': 'Bệnh nhân kiểm thử mobile',
      'email': '$username@test.invalid',
      'phone': '0962964504',
    });
    await repo.login(username, password);
    final profile = await repo.profile();
    check(profile.name == 'Bệnh nhân kiểm thử mobile', 'Profile name');
    await repo.saveProfile({
      'fullName': 'Patient Mobile Updated',
      'email': profile.email,
      'phone': profile.phone,
      'gender': null,
      'dateOfBirth': null,
      'address': 'Test only',
    });
    check(
      (await repo.profile()).name == 'Patient Mobile Updated',
      'Profile update',
    );
    final specialties = await repo.specialties();
    check(specialties.any((s) => s.id == specialty['id']), 'Specialties');
    final doctors = await repo.doctors(0, specialtyId: specialty['id'] as int);
    check(doctors.items.any((d) => d.id == doctor['id']), 'Doctor search');
    final slots = await repo.slots(doctor['id'] as int, dateKey(start));
    check(slots.isNotEmpty, 'Slots');
    check(
      (await repo.availableDays(
        doctor['id'] as int,
        dateKey(start),
      )).any((d) => d.date == dateKey(start) && d.count == 1),
      'Available date before booking',
    );
    await repo.book(slots.first.id);
    check(
      (await repo.availableDays(doctor['id'] as int, dateKey(start))).isEmpty,
      'Fully booked date hidden',
    );
    final pending = await repo.appointments(0, status: 'PENDING');
    check(pending.total == 1, 'Booking pending');
    final appointment = pending.items.single;
    check(
      (await repo.slots(doctor['id'] as int, dateKey(start))).isEmpty,
      'Booked slot hidden',
    );
    await doctorClient.request(
      '/doctors/me/appointments/${appointment.id}/status',
      method: 'PATCH',
      body: {'status': 'CONFIRMED'},
    );
    check(
      (await repo.appointments(0, status: 'CONFIRMED')).total == 1,
      'Confirmation',
    );
    final notices = await repo.notices(0);
    check(notices.total == 2, 'Booking and confirmation notifications');
    await repo.readNotice(notices.items.first.id);
    check(await repo.unread() == 1, 'Unread count');
    await repo.cancel(appointment.id);
    check(
      (await repo.appointments(0, status: 'CANCELED')).total == 1,
      'Cancellation',
    );
    check(
      (await repo.slots(doctor['id'] as int, dateKey(start))).isNotEmpty,
      'Slot released',
    );
    check(
      (await repo.availableDays(
        doctor['id'] as int,
        dateKey(start),
      )).any((d) => d.date == dateKey(start)),
      'Canceled date available again',
    );
    check((await repo.records(0)).total == 0, 'No fabricated medical record');
    try {
      await repo.record(appointment.id);
      throw StateError('Missing record must fail');
    } on ApiException catch (e) {
      check(e.status == 404, 'Record 404');
    }
    stdout.writeln(
      'PASS: real HTTP register/login, profile, specialties/doctors, slots, book/confirm/cancel, records 404 and notifications.',
    );
  } finally {
    admin.close();
    doctorClient.close();
    patientClient.close();
  }
}
