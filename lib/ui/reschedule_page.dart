import 'package:flutter/material.dart';

import '../core/clinic_time.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'common.dart';

class ReschedulePage extends StatefulWidget {
  const ReschedulePage({
    super.key,
    required this.repository,
    required this.appointmentId,
  });
  final ClinicRepository repository;
  final int appointmentId;
  @override
  State<ReschedulePage> createState() => _ReschedulePageState();
}

class _ReschedulePageState extends State<ReschedulePage> {
  List<RescheduleProposal> _items = [];
  bool _loading = true, _saving = false;
  String? _error, _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.reschedules(widget.appointmentId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không tải được đề xuất. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(RescheduleProposal item, String action) async {
    if (_saving) return;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'accept' ? 'Đồng ý đổi giờ khám?' : 'Từ chối đề xuất?',
        ),
        content: Text(
          action == 'accept'
              ? 'Giờ mới: ${appointmentTime(item.start)}. Lịch cũ còn hiệu lực chỉ bị hủy khi đặt lịch mới thành công. Lịch mới cần bác sĩ xác nhận.'
              : 'Từ chối không hủy lịch cũ còn hiệu lực. Lịch đã hủy do bác sĩ nghỉ vẫn giữ trạng thái đã hủy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted || _saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.repository.respondReschedule(
        widget.appointmentId,
        item.id,
        action,
      );
      if (mounted) {
        setState(
          () => _message = action == 'accept'
              ? 'Đã tạo lịch mới #${result.replacementId}, chờ bác sĩ xác nhận. Xem trong danh sách lịch hẹn.'
              : 'Đã từ chối đề xuất.',
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text('Đổi giờ · Lịch #${widget.appointmentId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Giờ đề xuất chưa được giữ chỗ. Khi đồng ý, hệ thống kiểm tra lại chỗ trống. Nếu lịch cũ đã hủy, đây là lời mời đặt lại.',
          ),
          TextButton(
            onPressed: _saving || _loading ? null : _load,
            child: const Text('Tải lại đề xuất'),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_message != null)
            Text(_message!, style: Theme.of(context).textTheme.titleMedium),
          if (!_loading && _error == null && _items.isEmpty)
            const Text('Chưa có đề xuất đổi giờ.'),
          if (!_loading && _error == null)
            ..._items.map(
              (p) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${appointmentTime(p.start)}–${clockLabel(p.end)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(rescheduleLabels[p.effectiveStatus] ?? p.status),
                      const SizedBox(height: 8),
                      Text(p.reason),
                      Text('Hạn phản hồi: ${appointmentTime(p.expiresAt)}'),
                      Text('Người đề xuất #${p.proposedBy}'),
                      if (p.respondedAt != null)
                        Text('Xử lý lúc ${appointmentTime(p.respondedAt!)}'),
                      if (p.replacementId != null)
                        Text('Lịch mới #${p.replacementId}'),
                      if (p.effectiveStatus == 'PENDING')
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _respond(p, 'accept'),
                              child: const Text('Chấp nhận giờ mới'),
                            ),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => _respond(p, 'decline'),
                              child: const Text('Từ chối đề xuất'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
