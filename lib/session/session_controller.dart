import 'package:flutter/foundation.dart';

import '../data/clinic_repository.dart';
import '../data/models.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.repository) {
    repository.client.onUnauthorized = _expire;
  }
  final ClinicRepository repository;
  PatientAccount? patient;
  String? notice;
  Future<void> login(String username, String password) async {
    patient = await repository.login(username, password);
    notice = null;
    notifyListeners();
  }

  void logout() {
    repository.client.clearToken();
    patient = null;
    notice = null;
    notifyListeners();
  }

  void _expire() {
    patient = null;
    notice = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    notifyListeners();
  }

  @override
  void dispose() {
    repository.client.onUnauthorized = null;
    repository.client.close();
    super.dispose();
  }
}
