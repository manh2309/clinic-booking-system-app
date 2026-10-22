import 'package:flutter/material.dart';

import '../core/clinic_time.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'common.dart';
import 'records_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.repository,
    required this.onChanged,
    required this.onAppointments,
  });
  final ClinicRepository repository;
  final VoidCallback onChanged, onAppointments;
  @override
  Widget build(BuildContext context) => PageList<Notice>(
    load: repository.notices,
    empty: 'Chưa có thông báo.',
    item: (notice, refresh) => NoticeCard(
      key: ValueKey(notice.id),
      notice: notice,
      repository: repository,
      onChanged: () {
        refresh();
        onChanged();
      },
      onAppointments: onAppointments,
    ),
  );
}

class NoticeCard extends StatefulWidget {
  const NoticeCard({
    super.key,
    required this.notice,
    required this.repository,
    required this.onChanged,
    required this.onAppointments,
  });
  final Notice notice;
  final ClinicRepository repository;
  final VoidCallback onChanged, onAppointments;
  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  bool _saving = false;
  Future<void> _read() async {
    if (_saving || widget.notice.read) return;
    setState(() => _saving = true);
    try {
      await widget.repository.readNotice(widget.notice.id);
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.title, style: Theme.of(context).textTheme.titleMedium),
            if (!n.read) const Text('Chưa đọc'),
            if (n.createdAt != null) Text(appointmentTime(n.createdAt!)),
            const SizedBox(height: 8),
            Text(n.message),
            Wrap(
              spacing: 8,
              children: [
                if (!n.read)
                  TextButton(
                    onPressed: _saving ? null : _read,
                    child: Text(_saving ? 'Đang lưu...' : 'Đánh dấu đã đọc'),
                  ),
                if (n.appointmentId != null)
                  TextButton(
                    onPressed: () {
                      if (n.type == 'APPOINTMENT_COMPLETED') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordDetailPage(
                              repository: widget.repository,
                              appointmentId: n.appointmentId!,
                            ),
                          ),
                        );
                      } else {
                        widget.onAppointments();
                      }
                    },
                    child: Text(
                      n.type == 'APPOINTMENT_COMPLETED'
                          ? 'Xem kết quả'
                          : 'Danh sách lịch hẹn',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
