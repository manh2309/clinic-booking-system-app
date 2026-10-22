import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'session/session_controller.dart';
import 'ui/auth_pages.dart';
import 'ui/patient_shell.dart';

class ClinicBookingApp extends StatefulWidget {
  const ClinicBookingApp({super.key, required this.session});
  final SessionController session;
  @override
  State<ClinicBookingApp> createState() => _ClinicBookingAppState();
}

class _ClinicBookingAppState extends State<ClinicBookingApp> {
  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
    builder: (context, child) => MaterialApp(
      // Đổi phiên thì bỏ cả stack trang chi tiết, không giữ hồ sơ của tài khoản trước.
      key: ValueKey(widget.session.patient?.id),
      title: 'ClinicCare',
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff00838f)),
        inputDecorationTheme: const InputDecorationThemeData(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xffd8e3e7)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xff172f38),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xffe0e8eb)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          height: 72,
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color(0xfff7fafb),
      ),
      home: widget.session.patient == null
          ? LoginPage(session: widget.session)
          : PatientShell(session: widget.session),
    ),
  );
}
