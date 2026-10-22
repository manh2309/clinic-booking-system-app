import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/app.dart';
import 'package:clinic_booking_patient/core/api_client.dart';
import 'package:clinic_booking_patient/data/clinic_repository.dart';
import 'package:clinic_booking_patient/session/session_controller.dart';

import 'fakes.dart';

void main() {
  testWidgets('login validates empty fields without contacting server', (
    tester,
  ) async {
    final transport = FakeTransport((m, u, h, b) async => ok(null));
    final session = SessionController(
      ClinicRepository(ApiClient(baseUrl: 'http://test', transport: transport)),
    );
    await tester.pumpWidget(ClinicBookingApp(session: session));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Nhập từ 1 đến 50 ký tự.'), findsOneWidget);
    expect(transport.calls, 0);
  });
  testWidgets('username uses normal keyboard and preserves editing selection', (
    tester,
  ) async {
    final session = SessionController(
      ClinicRepository(
        ApiClient(
          baseUrl: 'http://test',
          transport: FakeTransport((m, u, h, b) async => ok(null)),
        ),
      ),
    );
    await tester.pumpWidget(ClinicBookingApp(session: session));
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('login-username')),
    );
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login-username')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.stylusHandwritingEnabled, isFalse);
    expect(editable.autocorrect, isFalse);
    await tester.enterText(find.byKey(const Key('login-username')), 'test3');
    field.controller!.value = const TextEditingValue(
      text: 'teXst3',
      selection: TextSelection.collapsed(offset: 3),
    );
    await tester.pump();
    expect(field.controller!.text, 'teXst3');
    expect(field.controller!.selection.baseOffset, 3);
  });
  testWidgets('login disables repeated submit while waiting', (tester) async {
    final response = Completer<ResponsePacket>();
    final transport = FakeTransport((m, u, h, b) => response.future);
    final session = SessionController(
      ClinicRepository(ApiClient(baseUrl: 'http://test', transport: transport)),
    );
    await tester.pumpWidget(ClinicBookingApp(session: session));
    await tester.enterText(find.byKey(const Key('login-username')), 'patient');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-submit')));
    expect(transport.calls, 1);
    response.complete(failed(401, 1104));
    await tester.pumpAndSettle();
    expect(
      find.text('Tên đăng nhập hoặc mật khẩu không đúng.'),
      findsOneWidget,
    );
  });
  testWidgets('logout clears a pushed protected page from the navigator', (
    tester,
  ) async {
    final transport = FakeTransport((m, u, h, b) async {
      if (u.path.endsWith('/auth/login')) return ok(patientLogin());
      if (u.path.endsWith('/unread-count')) return ok(0);
      if (u.path.endsWith('/specialties')) return ok([]);
      return ok(pageOf([]));
    });
    final session = SessionController(
      ClinicRepository(ApiClient(baseUrl: 'http://test', transport: transport)),
    );
    await session.login('patient', 'password');
    await tester.pumpWidget(ClinicBookingApp(session: session));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(NavigationBar));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Private old page')),
      ),
    );
    await tester.pumpAndSettle();
    session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Private old page'), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}
