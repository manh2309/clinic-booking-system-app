import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'data/clinic_repository.dart';
import 'session/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:9000/api/v1',
  );
  try {
    final client = ApiClient(baseUrl: base);
    if (kReleaseMode && client.base.scheme != 'https') {
      client.close();
      throw const ApiException('Bản phát hành cần cấu hình kết nối HTTPS.');
    }
    runApp(
      ClinicBookingApp(session: SessionController(ClinicRepository(client))),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Cấu hình kết nối chưa hợp lệ. Vui lòng liên hệ người quản lý ứng dụng.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
