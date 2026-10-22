import 'package:flutter/material.dart';

import '../core/clinic_time.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'common.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({
    super.key,
    required this.repository,
    required this.onBooked,
  });
  final ClinicRepository repository;
  final VoidCallback onBooked;
  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final _search = TextEditingController();
  late Future<List<Specialty>> _specialties;
  String _query = '';
  int? _specialty;
  @override
  void initState() {
    super.initState();
    _specialties = widget.repository.specialties();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Tìm tên bác sĩ hoặc học vị',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _query = _search.text.trim()),
              tooltip: 'Tìm bác sĩ',
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FutureBuilder<List<Specialty>>(
          future: _specialties,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Row(
                children: [
                  const Expanded(
                    child: Text('Chưa tải được bộ lọc chuyên khoa.'),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _specialties = widget.repository.specialties(),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return DropdownButton<int>(
              isExpanded: true,
              value: _specialty,
              hint: const Text('Tất cả chuyên khoa'),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Tất cả chuyên khoa'),
                ),
                ...snapshot.data!.map(
                  (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                ),
              ],
              onChanged: (value) => setState(() => _specialty = value),
            );
          },
        ),
      ),
      Expanded(
        child: PageList<Doctor>(
          key: ValueKey('$_query:$_specialty'),
          load: (page) => widget.repository.doctors(
            page,
            keyword: _query,
            specialtyId: _specialty,
          ),
          empty: 'Chưa có bác sĩ phù hợp.',
          item: (doctor, refresh) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(doctor.specialty),
                  if (doctor.qualification.isNotEmpty)
                    Text(doctor.qualification),
                  if (doctor.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        doctor.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final booked = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingPage(
                              repository: widget.repository,
                              doctor: doctor,
                            ),
                          ),
                        );
                        if (booked == true) widget.onBooked();
                      },
                      child: const Text('Chọn lịch khám'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.repository,
    required this.doctor,
  });
  final ClinicRepository repository;
  final Doctor doctor;
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime _day = clinicToday();
  Slot? _selected;
  List<Slot> _slots = [];
  bool _loading = true, _saving = false;
  Object? _error;
  int _request = 0;
  int _dateRequest = 0, _selectionVersion = 0;
  List<AvailableDay> _dates = [];
  bool _datesLoading = false;
  Object? _datesError;
  @override
  void initState() {
    super.initState();
    _load();
    _loadDates(autoSelect: true);
  }

  Future<void> _loadDates({bool autoSelect = false}) async {
    final request = ++_dateRequest, selection = _selectionVersion;
    setState(() {
      _datesLoading = true;
      _datesError = null;
    });
    try {
      final days = await widget.repository.availableDays(
        widget.doctor.id,
        dateKey(clinicToday()),
      );
      if (!mounted || request != _dateRequest) return;
      setState(() => _dates = days);
      if (autoSelect &&
          selection == _selectionVersion &&
          !_saving &&
          days.isNotEmpty) {
        final first = DateTime.parse(days.first.date);
        setState(() => _day = DateTime(first.year, first.month, first.day));
        await _load();
      }
    } catch (e) {
      if (mounted && request == _dateRequest) setState(() => _datesError = e);
    } finally {
      if (mounted && request == _dateRequest) {
        setState(() => _datesLoading = false);
      }
    }
  }

  Future<void> _chooseDay(String date) async {
    if (_saving) return;
    final parsed = DateTime.parse(date);
    setState(() => _day = DateTime(parsed.year, parsed.month, parsed.day));
    await _load();
  }

  Future<void> _load() async {
    ++_selectionVersion;
    final request = ++_request;
    setState(() {
      _selected = null;
      _slots = [];
      _loading = true;
      _error = null;
    });
    try {
      final slots = await widget.repository.slots(
        widget.doctor.id,
        dateKey(_day),
      );
      if (mounted && request == _request) {
        setState(() {
          _slots = slots;
          _dates = _dates
              .where((d) => d.date != dateKey(_day) || slots.isNotEmpty)
              .map(
                (d) => d.date == dateKey(_day)
                    ? AvailableDay.from({
                        'date': d.date,
                        'availableSlots': slots.length,
                      })
                    : d,
              )
              .toList();
        });
      }
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    final slot = _selected;
    if (_saving ||
        _loading ||
        slot == null ||
        !_slots.any((s) => s.id == slot.id)) {
      return;
    }
    if (!slot.start.isAfter(DateTime.now().toUtc())) {
      await _load();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.book(slot.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        await Future.wait([_load(), _loadDates()]);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt lịch khám')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.doctor.name, style: Theme.of(context).textTheme.titleLarge),
        Text(widget.doctor.specialty),
        const SizedBox(height: 16),
        const Text('Ngày còn chỗ trong 30 ngày tới'),
        if (_datesLoading) const LinearProgressIndicator(),
        if (_datesError != null)
          Text(
            'Không tải được ngày còn chỗ. Bạn vẫn có thể chọn ngày bên dưới.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!_datesLoading && _datesError == null && _dates.isEmpty)
          const Text('Chưa có ngày còn chỗ trong khoảng này.'),
        if (_dates.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView.separated(
              key: const ValueKey('available-days-strip'),
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = _dates[index];
                return Center(
                  child: ChoiceChip(
                    key: ValueKey('available-day-${day.date}'),
                    label: Text(
                      '${day.date.substring(8, 10)}/${day.date.substring(5, 7)} · ${day.count} chỗ',
                    ),
                    selected: dateKey(_day) == day.date,
                    onSelected: _saving ? null : (_) => _chooseDay(day.date),
                  ),
                );
              },
            ),
          ),
        TextButton(
          onPressed: _saving || _datesLoading ? null : () => _loadDates(),
          child: const Text('Tải lại ngày khám'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month),
          onPressed: _saving
              ? null
              : () async {
                  final day = await showDatePicker(
                    context: context,
                    initialDate: _day.isBefore(clinicToday())
                        ? clinicToday()
                        : _day,
                    firstDate: clinicToday(),
                    lastDate: clinicToday().add(const Duration(days: 365)),
                  );
                  if (day != null && mounted) {
                    setState(() => _day = day);
                    await _load();
                  }
                },
          label: Text('Ngày khám: ${dateKey(_day)}'),
        ),
        const SizedBox(height: 16),
        const Text('Giờ khám theo múi giờ Việt Nam. Mỗi lượt khám 30 phút.'),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          ErrorPanel(_error!, onRetry: _load)
        else if (_slots.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chưa có khung giờ trống trong ngày này. Hãy chọn ngày khác.',
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slots
                .map(
                  (slot) => ChoiceChip(
                    label: Text(
                      '${clockLabel(slot.start)}–${clockLabel(slot.end)}',
                    ),
                    selected: _selected?.id == slot.id,
                    onSelected: _saving
                        ? null
                        : (selected) => setState(
                            () => _selected = selected ? slot : null,
                          ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _selected == null || _loading || _saving ? null : _book,
          child: Text(_saving ? 'Đang đặt lịch...' : 'Xác nhận đặt lịch'),
        ),
      ],
    ),
  );
}
