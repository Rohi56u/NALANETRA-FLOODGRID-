import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _staff = TextEditingController(),
      _name = TextEditingController(),
      _code = TextEditingController();
  AppRole _role = AppRole.citizen;
  bool _register = false, _busy = false;
  int? _challenge;
  String? _error;
  @override
  void dispose() {
    for (final c in [_email, _password, _staff, _name, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = context.read<AppStore>();
      if (_challenge != null) {
        await store.verify(_challenge!, _code.text.trim());
      } else if (_register) {
        final data = await store.register({
          'fullName': _name.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
        });
        if (mounted) setState(() => _challenge = data['challengeId'] as int);
      } else {
        await store.signIn({
          'role': _role.name,
          'email': _email.text.trim(),
          'password': _password.text,
          'staffId': _staff.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: store.language,
                  child: Text(store.hindi ? 'English' : 'हिंदी'),
                ),
              ),
              Image.asset('assets/logo.png', height: 78),
              const SizedBox(height: 18),
              const Text(
                appTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  color: GovColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                store.t(
                  'Report. Review. Respond. Verify.',
                  'रिपोर्ट। समीक्षा। प्रतिक्रिया। सत्यापन।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GovColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _challenge != null
                              ? store.t('Verify email', 'ईमेल सत्यापित करें')
                              : _register
                              ? store.t(
                                  'Citizen registration',
                                  'नागरिक पंजीकरण',
                                )
                              : store.t(
                                  'Enter your workspace',
                                  'अपना कार्यक्षेत्र खोलें',
                                ),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_challenge == null && !_register)
                          DropdownButtonFormField<AppRole>(
                            initialValue: _role,
                            decoration: InputDecoration(
                              labelText: store.t('Role', 'भूमिका'),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: AppRole.citizen,
                                child: Text(store.t('Citizen', 'नागरिक')),
                              ),
                              const DropdownMenuItem(
                                value: AppRole.officer,
                                child: Text('MCG Officer'),
                              ),
                              const DropdownMenuItem(
                                value: AppRole.crew,
                                child: Text('Field Crew'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (r) => setState(() => _role = r!),
                          ),
                        if (_challenge == null) ...[
                          const SizedBox(height: 14),
                          if (_register) ...[
                            TextFormField(
                              controller: _name,
                              decoration: InputDecoration(
                                labelText: store.t('Full name', 'पूरा नाम'),
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: store.t('Email', 'ईमेल'),
                            ),
                            validator: (v) => v?.contains('@') == true
                                ? null
                                : store.t('Enter an email', 'ईमेल दर्ज करें'),
                          ),
                          const SizedBox(height: 14),
                          if (!_register && _role != AppRole.citizen) ...[
                            TextFormField(
                              controller: _staff,
                              decoration: const InputDecoration(
                                labelText: 'Issued staff ID',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: store.t('Password', 'पासवर्ड'),
                            ),
                            validator: (v) => _register && (v?.length ?? 0) < 12
                                ? 'Use at least 12 characters'
                                : _required(v),
                          ),
                        ] else ...[
                          Text(
                            store.t(
                              'Enter the verification code from email. In local development, the operator reads the private mail-outbox file.',
                              'ईमेल का सत्यापन कोड डालें। स्थानीय विकास में ऑपरेटर निजी mail-outbox फाइल से कोड पढ़ता है।',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Verification code',
                            ),
                            validator: _required,
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: GovColors.critical),
                            ),
                          ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Text(
                              _busy
                                  ? store.t('Please wait…', 'कृपया रुकें…')
                                  : _challenge != null
                                  ? store.t('Verify', 'सत्यापित करें')
                                  : _register
                                  ? store.t(
                                      'Create citizen account',
                                      'नागरिक खाता बनाएं',
                                    )
                                  : store.t('Sign in', 'साइन इन'),
                            ),
                          ),
                        ),
                        if (_challenge == null && _role == AppRole.citizen)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _register = !_register),
                            child: Text(
                              _register
                                  ? store.t(
                                      'Already registered? Sign in',
                                      'पहले से खाता है? साइन इन',
                                    )
                                  : store.t(
                                      'New citizen? Register',
                                      'नए नागरिक? पंजीकरण',
                                    ),
                            ),
                          ),
                        if (_role != AppRole.citizen)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Staff access uses an account issued by the municipal operator.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Smart India Hackathon team prototype',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value?.trim().isNotEmpty == true ? null : 'Required';
}
