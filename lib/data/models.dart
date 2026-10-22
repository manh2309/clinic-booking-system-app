import '../core/api_client.dart';
import '../core/clinic_time.dart';

int integer(dynamic value) {
  if (value is! int) {
    throw const ApiException('Dữ liệu máy chủ chưa đúng định dạng.');
  }
  return value;
}

String text(dynamic value) {
  if (value is! String) {
    throw const ApiException('Dữ liệu máy chủ chưa đúng định dạng.');
  }
  return value;
}

String? optionalText(dynamic value) => value == null ? null : text(value);

bool boolean(dynamic value) {
  if (value is! bool) {
    throw const ApiException('Dữ liệu máy chủ chưa đúng định dạng.');
  }
  return value;
}

class PageData<T> {
  const PageData(this.items, this.page, this.size, this.total, this.last);
  final List<T> items;
  final int page, size, total;
  final bool last;
  factory PageData.from(dynamic raw, T Function(Map<String, dynamic>) read) {
    final map = objectMap(raw);
    if (map['content'] is! List || map['last'] is! bool) {
      throw const ApiException('Không đọc được danh sách từ máy chủ.');
    }
    final page = integer(map['page']);
    final size = integer(map['size']);
    final total = integer(map['totalElements']);
    if (page < 0 || size <= 0 || total < 0) {
      throw const ApiException('Không đọc được thông tin phân trang.');
    }
    return PageData(
      (map['content'] as List).map((e) => read(objectMap(e))).toList(),
      page,
      size,
      total,
      map['last'] as bool,
    );
  }
}

class PatientAccount {
  const PatientAccount(this.id, this.username, this.email);
  final int id;
  final String username, email;
}

class Specialty {
  Specialty.from(Map<String, dynamic> m)
    : id = integer(m['id']),
      name = text(m['name']);
  final int id;
  final String name;
}

class Doctor {
  Doctor.from(Map<String, dynamic> m)
    : id = integer(m['id']),
      name = text(m['fullName']),
      specialty = optionalText(m['specialtyName']) ?? '',
      qualification = optionalText(m['qualification']) ?? '',
      description = optionalText(m['description']) ?? '';
  final int id;
  final String name, specialty, qualification, description;
}

class AvailableDay {
  AvailableDay.from(Map<String, dynamic> m)
    : date = text(m['date']),
      count = integer(m['availableSlots']) {
    final parsed = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed == null ||
        dateKey(parsed) != date ||
        count <= 0) {
      throw const ApiException('Không đọc được ngày khám còn chỗ.');
    }
  }
  final String date;
  final int count;
}

class Slot {
  Slot.from(Map<String, dynamic> m)
    : id = integer(m['id']),
      start = parseClinicTime(text(m['startAt'])),
      end = parseClinicTime(text(m['endAt']));
  final int id;
  final DateTime start, end;
}

const appointmentLabels = <String, String>{
  'PENDING': 'Chờ xác nhận',
  'CONFIRMED': 'Đã xác nhận',
  'COMPLETED': 'Hoàn thành',
  'CANCELED': 'Đã hủy',
  'EXPIRED': 'Hết hạn',
  'NO_SHOW': 'Vắng mặt',
};

class Appointment {
  Appointment.from(Map<String, dynamic> m)
    : id = integer(m['id']),
      status = text(m['status']),
      doctor = optionalText(m['doctorName']) ?? 'Bác sĩ',
      reason = optionalText(m['statusReason']),
      start = parseClinicTime(text(m['startAt'])),
      end = parseClinicTime(text(m['endAt']));
  final int id;
  final String status, doctor;
  final String? reason;
  final DateTime start, end;
  bool canCancelAt(DateTime instant) =>
      ['PENDING', 'CONFIRMED'].contains(status) &&
      start.isAfter(instant.toUtc());
}

class MedicalRecord {
  MedicalRecord.from(Map<String, dynamic> m)
    : appointmentId = integer(m['appointmentId']),
      doctor = text(m['doctorName']),
      diagnosis = text(m['diagnosis']),
      notes = optionalText(m['examinationNotes']),
      advice = optionalText(m['treatmentAdvice']),
      start = parseClinicTime(text(m['startAt']));
  final int appointmentId;
  final String doctor, diagnosis;
  final String? notes, advice;
  final DateTime start;
}

class Notice {
  Notice.from(Map<String, dynamic> m)
    : id = integer(m['id']),
      appointmentId = m['appointmentId'] == null
          ? null
          : integer(m['appointmentId']),
      type = text(m['type']),
      title = text(m['title']),
      message = text(m['message']),
      read = boolean(m['read']),
      createdAt = m['createdAt'] == null
          ? null
          : parseClinicTime(text(m['createdAt']));
  final int id;
  final int? appointmentId;
  final String type, title, message;
  final bool read;
  final DateTime? createdAt;
}

class PatientProfile {
  PatientProfile.from(Map<String, dynamic> m)
    : id = m['patientProfileId'] == null
          ? null
          : integer(m['patientProfileId']),
      name = optionalText(m['fullName']) ?? '',
      email = optionalText(m['email']) ?? '',
      phone = optionalText(m['phone']) ?? '',
      birth = optionalText(m['dateOfBirth']),
      gender = optionalText(m['gender']) ?? '',
      address = optionalText(m['address']) ?? '';
  final int? id;
  final String name, email, phone, gender, address;
  final String? birth;
}
