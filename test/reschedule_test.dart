import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_booking_patient/core/api_client.dart';
import 'package:clinic_booking_patient/data/clinic_repository.dart';
import 'package:clinic_booking_patient/ui/reschedule_page.dart';
import 'fakes.dart';

Map<String, dynamic> proposal({String status = 'PENDING'}) => {
  'id': 3, 'status': status, 'reason': 'Bố trí giờ khác', 'proposedBy': 1,
  'targetStartAt': '2099-05-02T09:00:00', 'targetEndAt': '2099-05-02T09:30:00',
  'expiresAt': '2099-04-30T09:00:00', if (status == 'ACCEPTED') 'replacementAppointmentId': 15,
};
void main() {
  testWidgets('accept is confirmed once and refreshes history', (tester) async {
    int patches = 0; bool accepted = false;
    final pending = Completer<ResponsePacket>();
    final repo = ClinicRepository(ApiClient(baseUrl: 'http://test/api/v1', transport: FakeTransport((method, uri, headers, body) async {
      if (method == 'PATCH') { patches++; return pending.future; }
      return ok([proposal(status: accepted ? 'ACCEPTED' : 'PENDING')]);
    }))..setToken('token'));
    await tester.pumpWidget(MaterialApp(home: ReschedulePage(repository: repo, appointmentId: 7)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chấp nhận giờ mới')); await tester.pumpAndSettle();
    expect(patches, 0);
    await tester.tap(find.text('Xác nhận')); await tester.pumpAndSettle();
    expect(patches, 1);
    await tester.tap(find.text('Chấp nhận giờ mới')); await tester.pump(); expect(patches, 1);
    accepted = true; pending.complete(ok(proposal(status: 'ACCEPTED'))); await tester.pumpAndSettle();
    expect(find.textContaining('Đã tạo lịch mới #15'), findsOneWidget);
    expect(find.text('Chấp nhận giờ mới'), findsNothing);
  });
  testWidgets('expired proposal has no accept action', (tester) async {
    final repo = ClinicRepository(ApiClient(baseUrl: 'http://test/api/v1', transport: FakeTransport((method, uri, headers, body) async => ok([
      {...proposal(), 'expiresAt': '2020-01-01T09:00:00'},
    ])))..setToken('token'));
    await tester.pumpWidget(MaterialApp(home: ReschedulePage(repository: repo, appointmentId: 7)));
    await tester.pumpAndSettle();
    expect(find.text('Hết hạn'), findsOneWidget); expect(find.text('Chấp nhận giờ mới'), findsNothing);
  });
}
