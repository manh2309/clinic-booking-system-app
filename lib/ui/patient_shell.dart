import 'package:flutter/material.dart';

import '../session/session_controller.dart';
import 'doctors_page.dart';
import 'appointments_page.dart';
import 'records_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key, required this.session});
  final SessionController session;
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _tab = 0, _countRequest = 0;
  int? _unread;
  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final request = ++_countRequest;
    try {
      final count = await widget.session.repository.unread();
      if (mounted && request == _countRequest) setState(() => _unread = count);
    } catch (_) {
      if (mounted && request == _countRequest) setState(() => _unread = null);
    }
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.session.repository;
    final body = switch (_tab) {
      0 => DoctorsPage(repository: repository, onBooked: () => _select(1)),
      1 => AppointmentsPage(repository: repository, onChanged: _loadUnread),
      2 => RecordsPage(repository: repository),
      3 => NotificationsPage(
        repository: repository,
        onChanged: _loadUnread,
        onAppointments: () => _select(1),
      ),
      _ => ProfilePage(repository: repository),
    };
    const titles = [
      'Tìm bác sĩ',
      'Lịch hẹn của tôi',
      'Kết quả khám',
      'Thông báo',
      'Hồ sơ cá nhân',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            onPressed: widget.session.logout,
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Bác sĩ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note),
            label: 'Lịch hẹn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined),
            label: 'Kết quả',
          ),
          NavigationDestination(
            icon: Tooltip(
              message: _unread == null
                  ? 'Chưa tải được số chưa đọc'
                  : '$_unread thông báo chưa đọc',
              child: Badge(
                label: Text('${_unread ?? ''}'),
                isLabelVisible: _unread != null && _unread! > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            label: 'Thông báo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
