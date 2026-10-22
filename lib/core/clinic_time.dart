// BE trả giờ phòng khám không có offset; không diễn giải theo múi giờ điện thoại.
DateTime parseClinicTime(String value) {
  final withOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  return DateTime.parse(withOffset ? value : '$value+07:00').toUtc();
}

DateTime clinicWallTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 7));
DateTime clinicToday() {
  final now = clinicWallTime(DateTime.now());
  return DateTime(now.year, now.month, now.day);
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String clockLabel(DateTime instant) {
  final time = clinicWallTime(instant);
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String appointmentTime(DateTime instant) {
  final date = clinicWallTime(instant);
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${clockLabel(instant)}';
}
