import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/clinic_time.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'common.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.repository});
  final ClinicRepository repository;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<PatientProfile> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.profile();
  }

  void _load() => setState(() => _future = widget.repository.profile());
  @override
  Widget build(BuildContext context) => FutureBuilder<PatientProfile>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: ErrorPanel(snapshot.error!, onRetry: _load));
      }
      return _ProfileForm(
        key: ValueKey(snapshot.data),
        profile: snapshot.data!,
        repository: widget.repository,
        onSaved: _load,
      );
    },
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    super.key,
    required this.profile,
    required this.repository,
    required this.onSaved,
  });
  final PatientProfile profile;
  final ClinicRepository repository;
  final VoidCallback onSaved;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _name, _email, _phone, _address;
  String _gender = '';
  DateTime? _birth;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _email = TextEditingController(text: p.email);
    _phone = TextEditingController(text: p.phone);
    _address = TextEditingController(text: p.address);
    _gender = p.gender;
    _birth = p.birth == null ? null : DateTime.tryParse(p.birth!);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveProfile({
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'dateOfBirth': _birth == null ? null : dateKey(_birth!),
        'gender': _gender.isEmpty ? null : _gender,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ.')));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.profile.id == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Hãy bổ sung họ tên và kiểm tra thông tin liên hệ để hoàn thiện hồ sơ.',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
              validator: (v) => requiredText(v, min: 4, max: 100),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: emailError,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: phoneError,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              onPressed: _saving
                  ? null
                  : () async {
                      final day = await showDatePicker(
                        context: context,
                        initialDate: _birth ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: clinicToday(),
                      );
                      if (day != null && mounted) setState(() => _birth = day);
                    },
              label: Text(
                _birth == null ? 'Chọn ngày sinh (tùy chọn)' : dateKey(_birth!),
              ),
            ),
            if (_birth != null)
              TextButton(
                onPressed: _saving ? null : () => setState(() => _birth = null),
                child: const Text('Bỏ ngày sinh'),
              ),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Giới tính'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Chưa cung cấp')),
                DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _gender = v ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ (tùy chọn)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Đang lưu...' : 'Lưu hồ sơ'),
            ),
          ],
        ),
      ),
    ],
  );
}
