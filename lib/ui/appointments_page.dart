import 'package:flutter/material.dart';

import '../core/clinic_time.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'common.dart';
import 'records_page.dart';
import 'reschedule_page.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final ClinicRepository repository;
  final VoidCallback onChanged;
  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  String _status = '';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButton<String>(
          isExpanded: true,
          value: _status,
          items: [
            const DropdownMenuItem(value: '', child: Text('Tất cả trạng thái')),
            ...appointmentLabels.entries.map(
              (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
            ),
          ],
          onChanged: (status) => setState(() => _status = status ?? ''),
        ),
      ),
      Expanded(
        child: PageList<Appointment>(
          key: ValueKey(_status),
          load: (page) => widget.repository.appointments(page, status: _status),
          empty: 'Chưa có lịch hẹn phù hợp.',
          item: (appointment, refresh) => AppointmentCard(
            key: ValueKey(appointment.id),
            appointment: appointment,
            repository: widget.repository,
            onChanged: () {
              refresh();
              widget.onChanged();
            },
          ),
        ),
      ),
    ],
  );
}

class AppointmentCard extends StatefulWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.repository,
    required this.onChanged,
  });
  final Appointment appointment;
  final ClinicRepository repository;
  final VoidCallback onChanged;
  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _saving = false;
  Future<void> _cancel() async {
    if (_saving || !widget.appointment.canCancelAt(DateTime.now())) return;
    final appointment = widget.appointment;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch hẹn?'),
        content: Text(
          'Bạn muốn hủy lịch #${widget.appointment.id} với ${widget.appointment.doctor}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lịch'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.cancel(appointment.id);
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch #${a.id} · ${appointmentLabels[a.status] ?? 'Chưa xác định'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(a.doctor, style: Theme.of(context).textTheme.titleMedium),
            Text('${appointmentTime(a.start)}–${clockLabel(a.end)}'),
            if (a.visit != null) ...[
              const SizedBox(height: 8),
              Text(
                visitLabels[a.visit!.status] ?? a.visit!.status,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text('Tiếp nhận lúc ${appointmentTime(a.visit!.checkedInAt)}'),
              if (a.visit!.startedAt != null)
                Text(
                  'Bắt đầu khám lúc ${appointmentTime(a.visit!.startedAt!)}',
                ),
            ],
            if (a.reason?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(a.reason!),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReschedulePage(
                                repository: widget.repository,
                                appointmentId: a.id,
                              ),
                            ),
                          );
                          if (mounted) widget.onChanged();
                        },
                  child: const Text('Đề xuất đổi giờ / Lịch sử'),
                ),
                if (a.canCancelAt(DateTime.now()))
                  TextButton(
                    onPressed: _saving ? null : _cancel,
                    child: Text(_saving ? 'Đang hủy...' : 'Hủy lịch hẹn'),
                  ),
                if (a.status == 'COMPLETED')
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordDetailPage(
                          repository: widget.repository,
                          appointmentId: a.id,
                        ),
                      ),
                    ),
                    child: const Text('Xem kết quả khám'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
