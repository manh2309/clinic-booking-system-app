import 'package:flutter/material.dart';

import '../data/clinic_repository.dart';
import '../session/session_controller.dart';
import 'common.dart';
import '../core/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});
  final SessionController session;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController();
  bool _saving = false, _hidden = true;
  String? _error;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.login(_username.text, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ClinicCare')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_hospital_outlined, size: 56),
                const SizedBox(height: 20),
                Text(
                  'Đăng nhập bệnh nhân',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Đặt lịch khám và theo dõi kết quả của bạn.'),
                const SizedBox(height: 24),
                if (_error != null || widget.session.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error ?? widget.session.notice!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextFormField(
                  key: const Key('login-username'),
                  controller: _username,
                  enabled: !_saving,
                  // Tên tài khoản dùng bàn phím thường, tránh chế độ viết tay của Android.
                  stylusHandwritingEnabled: false,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                  validator: (v) => requiredText(v, max: 50),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('login-password'),
                  controller: _password,
                  enabled: !_saving,
                  obscureText: _hidden,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      icon: Icon(
                        _hidden ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (v) => requiredText(v, max: 64),
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('login-submit'),
                  onPressed: _saving ? null : _login,
                  child: Text(_saving ? 'Đang đăng nhập...' : 'Đăng nhập'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final username = await Navigator.of(context)
                              .push<String>(
                                MaterialPageRoute(
                                  builder: (_) => RegisterPage(
                                    repository: widget.session.repository,
                                  ),
                                ),
                              );
                          if (mounted && context.mounted && username != null) {
                            _username.text = username;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đăng ký thành công. Hãy đăng nhập.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Chưa có tài khoản? Đăng ký'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.repository});
  final ClinicRepository repository;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [
      _username,
      _name,
      _email,
      _phone,
      _password,
      _confirmation,
    ]) {
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
      await widget.repository.register({
        'username': _username.text.trim(),
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
      });
      if (mounted) Navigator.pop(context, _username.text.trim());
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String? Function(String?) validator, {
    bool password = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      obscureText: password,
      keyboardType: keyboard,
      stylusHandwritingEnabled: false,
      autocorrect: controller != _username && !password,
      enableSuggestions: controller != _username && !password,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng ký bệnh nhân')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!),
                ),
              _field(
                _username,
                'Tên đăng nhập',
                (v) => requiredText(v, min: 4, max: 50),
              ),
              _field(
                _name,
                'Họ và tên',
                (v) => requiredText(v, min: 4, max: 100),
              ),
              _field(
                _email,
                'Email',
                emailError,
                keyboard: TextInputType.emailAddress,
              ),
              _field(
                _phone,
                'Số điện thoại (tùy chọn)',
                phoneError,
                keyboard: TextInputType.phone,
              ),
              _field(
                _password,
                'Mật khẩu',
                (v) =>
                    v == null ||
                        v.trim().isEmpty ||
                        v.length < 8 ||
                        v.length > 64
                    ? 'Mật khẩu gồm 8–64 ký tự.'
                    : null,
                password: true,
              ),
              _field(
                _confirmation,
                'Nhập lại mật khẩu',
                (v) =>
                    v != _password.text ? 'Mật khẩu nhập lại chưa khớp.' : null,
                password: true,
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang đăng ký...' : 'Tạo tài khoản'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
