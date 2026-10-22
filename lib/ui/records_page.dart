import 'package:flutter/material.dart';

import '../core/clinic_time.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'common.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.repository});
  final ClinicRepository repository;
  @override
  Widget build(BuildContext context) => PageList<MedicalRecord>(
    load: repository.records,
    empty: 'Chưa có kết quả khám. Kết quả xuất hiện khi bác sĩ hoàn thành ca khám.',
    item: (record, refresh) => RecordCard(record: record),
  );
}

class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({
    super.key,
    required this.repository,
    required this.appointmentId,
  });
  final ClinicRepository repository;
  final int appointmentId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Kết quả lịch #$appointmentId')),
    body: DetailView<MedicalRecord>(
      load: () => repository.record(appointmentId),
      builder: (record) => ListView(
        padding: const EdgeInsets.all(16),
        children: [RecordCard(record: record)],
      ),
    ),
  );
}

class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record});
  final MedicalRecord record;
  Widget _section(BuildContext context, String title, String content) =>
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SelectableText(content),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch #${record.appointmentId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Bác sĩ ${record.doctor}'),
          Text(appointmentTime(record.start)),
          _section(context, 'Chẩn đoán', record.diagnosis),
          if (record.notes?.isNotEmpty == true)
            _section(context, 'Ghi nhận khi khám', record.notes!),
          if (record.advice?.isNotEmpty == true)
            _section(context, 'Hướng dẫn điều trị', record.advice!),
        ],
      ),
    ),
  );
}
