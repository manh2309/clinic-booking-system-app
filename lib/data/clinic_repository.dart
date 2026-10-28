import '../core/api_client.dart';
import 'models.dart';

class ClinicRepository {
  ClinicRepository(this.client);
  final ApiClient client;
  Future<PatientAccount> login(String username, String password) async {
    final data = objectMap(
      await client.request(
        '/auth/login',
        method: 'POST',
        authenticated: false,
        body: {'username': username.trim(), 'password': password},
      ),
    );
    final account = objectMap(data['account']);
    if (!['PATIENT', 'ROLE_PATIENT'].contains(account['roleName']) ||
        account['isActive'] == false) {
      throw const ApiException(
        'Ứng dụng này dành cho bệnh nhân. Bác sĩ và quản trị viên sử dụng cổng web.',
      );
    }
    final token = text(data['accessToken']);
    if (token.isEmpty) {
      throw const ApiException('Không tạo được phiên đăng nhập.');
    }
    final patient = PatientAccount(
      integer(account['id']),
      text(account['username']),
      text(account['email']),
    );
    client.setToken(token);
    return patient;
  }

  Future<void> register(Map<String, dynamic> body) async {
    await client.request(
      '/auth/register',
      method: 'POST',
      body: body,
      authenticated: false,
    );
  }

  Future<List<Specialty>> specialties() async {
    final data = await client.request('/specialties');
    if (data is! List) throw const ApiException('Không đọc được chuyên khoa.');
    return data.map((e) => Specialty.from(objectMap(e))).toList();
  }

  Future<PageData<Doctor>> doctors(
    int page, {
    String keyword = '',
    int? specialtyId,
  }) async => PageData.from(
    await client.request(
      '/doctors',
      query: {
        'page': '$page',
        'size': '10',
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (specialtyId != null) 'specialtyId': '$specialtyId',
      },
    ),
    Doctor.from,
  );
  Future<List<AvailableDay>> availableDays(int doctorId, String from) async {
    final data = await client.request(
      '/doctors/$doctorId/available-dates',
      query: {'from': from, 'days': '30'},
    );
    if (data is! List) {
      throw const ApiException('Không đọc được ngày khám còn chỗ.');
    }
    return data.map((e) => AvailableDay.from(objectMap(e))).toList();
  }

  Future<List<Slot>> slots(int doctorId, String date) async {
    final data = await client.request(
      '/doctors/$doctorId/available-slots',
      query: {'date': date},
    );
    if (data is! List) {
      throw const ApiException('Không đọc được khung giờ khám.');
    }
    return data.map((e) => Slot.from(objectMap(e))).toList();
  }

  Future<void> book(int slotId) async {
    await client.request(
      '/appointments',
      method: 'POST',
      body: {'slotId': slotId},
    );
  }

  Future<PageData<Appointment>> appointments(
    int page, {
    String status = '',
  }) async => PageData.from(
    await client.request(
      '/appointments/me',
      query: {
        'page': '$page',
        'size': '10',
        if (status.isNotEmpty) 'status': status,
      },
    ),
    Appointment.from,
  );
  Future<void> cancel(int id) async {
    await client.request(
      '/appointments/$id/cancel',
      method: 'PATCH',
      body: <String, dynamic>{},
    );
  }

  Future<PageData<MedicalRecord>> records(int page) async => PageData.from(
    await client.request(
      '/patient/me/medical-records',
      query: {'page': '$page', 'size': '10'},
    ),
    MedicalRecord.from,
  );
  Future<MedicalRecord> record(int appointmentId) async => MedicalRecord.from(
    objectMap(
      await client.request('/patient/me/medical-records/$appointmentId'),
    ),
  );
  Future<PageData<Notice>> notices(int page) async => PageData.from(
    await client.request(
      '/notifications/me',
      query: {'page': '$page', 'size': '10'},
    ),
    Notice.from,
  );
  Future<int> unread() async =>
      integer(await client.request('/notifications/me/unread-count'));
  Future<void> readNotice(int id) async {
    await client.request(
      '/notifications/me/$id/read',
      method: 'PATCH',
      body: <String, dynamic>{},
    );
  }

  Future<PatientProfile> profile() async => PatientProfile.from(
    objectMap(await client.request('/patient/me/profile')),
  );
  Future<void> saveProfile(Map<String, dynamic> body) async {
    await client.request(
      '/patient/me/profile/update',
      method: 'PUT',
      body: body,
    );
  }

  Future<List<RescheduleProposal>> reschedules(int appointmentId) async {
    final data = await client.request(
      '/appointments/$appointmentId/reschedules',
    );
    if (data is! List) {
      throw const ApiException('Không đọc được đề xuất đổi giờ.');
    }
    return data.map((e) => RescheduleProposal.from(objectMap(e))).toList();
  }

  Future<RescheduleProposal> respondReschedule(
    int appointmentId,
    int proposalId,
    String action,
  ) async {
    if (action != 'accept' && action != 'decline') {
      throw const ApiException('Thao tác không hợp lệ.');
    }
    return RescheduleProposal.from(
      objectMap(
        await client.request(
          '/appointments/$appointmentId/reschedules/$proposalId/$action',
          method: 'PATCH',
          body: <String, dynamic>{},
        ),
      ),
    );
  }
}
