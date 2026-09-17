import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'citizen_auth_service.dart';
import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  Portal _role = Portal.citizen;
  bool _isSignUp = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _otpRequired = false;
  String? _passwordError;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passwordCtrl,
      _idCtrl,
      _otpCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _clearOtpState() {
    _otpCtrl.clear();
    _otpRequired = false;
  }

  void _toggleMode() {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _isSignUp = !_isSignUp;
      _clearOtpState();
    });
  }

  void _selectRole(Portal role) {
    if (_role == role) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _role = role;
      _isSignUp = true;
      _nameCtrl.clear();
      _idCtrl.clear();
      _clearOtpState();
    });
  }

  Future<void> _resendCitizenEmailCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _message('Enter your email address first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await context.read<AppStore>().resendCitizenCodesByEmail(email);
      if (mounted) {
        setState(() => _otpRequired = true);
        _message(
          'A new six-digit OTP was sent to your email. Enter it in the OTP box below.',
        );
      }
    } on CitizenAuthException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendStaffEmailCode(AppStore store) async {
    final email = _emailCtrl.text.trim();
    final staffId = _idCtrl.text.trim();
    if (email.isEmpty || staffId.isEmpty) {
      _message('Enter the issued ID and official email first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await store.resendStaffCode(
        portal: _role,
        staffId: staffId,
        email: email,
      );
      if (mounted) {
        setState(() => _otpRequired = true);
        _message(
          'A new six-digit OTP was sent to your email. Enter it in the OTP box below.',
        );
      }
    } on CitizenAuthException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateBeforeSubmit(bool en) {
    if (_isSignUp && _passwordCtrl.text.length < 8) {
      return en
          ? 'Password must be at least 8 characters.'
          : 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए।';
    }
    if (_passwordCtrl.text.isEmpty) {
      return en ? 'Enter your password.' : 'अपना पासवर्ड भरें।';
    }
    return null;
  }

  String _safeAuthMessage(String raw, bool en) {
    final normalized = raw.toLowerCase();
    final isPasswordValidation =
        normalized.contains('too_small') && normalized.contains('password') ||
        normalized.contains('expected string to have >=8 characters') ||
        normalized.contains('password must be at least 8');
    if (isPasswordValidation) {
      return en
          ? 'Password must be at least 8 characters.'
          : 'पासवर्ड कम से कम 8 अक्षरों का होना चाहिए।';
    }
    if (raw.trimLeft().startsWith('[') || raw.length > 220) {
      return en
          ? 'Please check the entered details and try again.'
          : 'कृपया भरी गई जानकारी जांचकर फिर प्रयास करें।';
    }
    return raw;
  }

  Future<void> _verifyInlineOtp(AppStore store) async {
    final code = _otpCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const CitizenAuthException(
        'Enter the six-digit OTP sent to your email.',
      );
    }

    if (_role == Portal.citizen) {
      await store.verifyCitizen(emailCode: code);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else {
      await store.verifyStaff(portal: _role, emailCode: code);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          _role == Portal.officer ? '/officer' : '/crew',
          (route) => false,
        );
      }
    }
  }

  Future<void> _submit() async {
    final store = context.read<AppStore>();
    final en = store.lang == AppLang.en;
    final pendingForRole = _role == Portal.citizen
        ? store.pendingCitizenChallenge != null
        : store.pendingStaffChallenge != null;

    if (!(_otpRequired || pendingForRole)) {
      final validationMessage = _validateBeforeSubmit(en);
      if (validationMessage != null) {
        setState(() {
          _passwordError =
              validationMessage.toLowerCase().contains('password') ||
                  validationMessage.contains('पासवर्ड')
              ? validationMessage
              : null;
        });
        _message(validationMessage);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      // Once a code has been sent, the same form button verifies the code typed
      // in the visible OTP box instead of navigating to a second hidden flow.
      if (_otpRequired || pendingForRole) {
        await _verifyInlineOtp(store);
        return;
      }

      if (_role == Portal.citizen) {
        if (_isSignUp) {
          await store.registerCitizen(
            fullName: _nameCtrl.text,
            email: _emailCtrl.text,
            phone: _phoneCtrl.text,
            password: _passwordCtrl.text,
          );
          if (mounted) {
            setState(() => _otpRequired = true);
            _message(
              'Account created. Enter the six-digit OTP sent to your email in the box below.',
            );
          }
        } else {
          await store.loginCitizen(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          }
        }
      } else {
        if (_isSignUp) {
          await store.registerStaff(
            portal: _role,
            staffId: _idCtrl.text,
            fullName: _nameCtrl.text,
            phone: _phoneCtrl.text,
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
          if (mounted) {
            setState(() => _otpRequired = true);
            _message(
              'Account created. Enter the six-digit OTP sent to your email in the box below.',
            );
          }
        } else {
          await store.loginStaff(
            portal: _role,
            staffId: _idCtrl.text,
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              _role == Portal.officer ? '/officer' : '/crew',
              (route) => false,
            );
          }
        }
      }
    } on CitizenAuthException catch (e) {
      // Existing but unverified users can recover from the same screen: a new
      // code is requested and the inline OTP box becomes the next step.
      final message = e.message.toLowerCase();
      final verificationRequired =
          !_isSignUp &&
          (message.contains('verify your email before logging in') ||
              message.contains('verify your staff email before logging in'));
      if (verificationRequired) {
        try {
          if (_role == Portal.citizen) {
            await store.resendCitizenCodesByEmail(_emailCtrl.text);
          } else {
            await store.resendStaffCode(
              portal: _role,
              staffId: _idCtrl.text,
              email: _emailCtrl.text,
            );
          }
          if (mounted) {
            setState(() => _otpRequired = true);
            _message(
              'Your account needs email verification. Enter the new six-digit OTP below.',
            );
          }
        } on CitizenAuthException catch (resendError) {
          _message(resendError.message);
        }
      } else {
        _message(_safeAuthMessage(e.message, en));
      }
    } catch (_) {
      _message(
        en
            ? 'Unable to complete this request. Please try again.'
            : 'अनुरोध पूरा नहीं हो सका। फिर प्रयास करें।',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final en = store.lang == AppLang.en;
    final isDark = store.themeMode == AppThemeMode.dark;
    final ink = isDark ? Colors.white : GovColors.navy;
    final pendingForRole = _role == Portal.citizen
        ? store.pendingCitizenChallenge != null
        : store.pendingStaffChallenge != null;
    final otpStepActive = _otpRequired || pendingForRole;
    final primaryLabel = otpStepActive
        ? (en
              ? 'Verify OTP & open portal'
              : 'ओटीपी सत्यापित करें और पोर्टल खोलें')
        : _role == Portal.citizen
        ? (_isSignUp
              ? (en ? 'Create account & verify' : 'खाता बनाएं और सत्यापित करें')
              : (en ? 'Login securely' : 'सुरक्षित लॉगिन'))
        : (_isSignUp
              ? (en
                    ? 'Create account & verify email'
                    : 'खाता बनाएं और ईमेल सत्यापित करें')
              : (en ? 'Login securely' : 'सुरक्षित लॉगिन'));

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 40,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.shield, color: ink, size: 32),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'भारत सरकार',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: ink,
                              ),
                            ),
                            Text(
                              'Government of India',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        store.setLang(en ? AppLang.hi : AppLang.en),
                    child: Text(
                      en ? 'EN | हिंदी' : 'हिंदी | EN',
                      style: TextStyle(color: ink, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  children: [
                    const _LogoHero(),
                    const SizedBox(height: 20),
                    Text(
                      en ? 'Namaste! Welcome' : 'नमस्ते! आपका स्वागत है',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      en
                          ? 'Secure access to NalaNetra FloodGrid'
                          : 'नालानेत्र फ्लडग्रिड में सुरक्षित प्रवेश',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in [
                          (Portal.citizen, en ? 'Citizen' : 'नागरिक'),
                          (
                            Portal.officer,
                            en ? 'MCG Officer' : 'एमसीजी अधिकारी',
                          ),
                          (Portal.crew, en ? 'Field Crew' : 'फील्ड क्रू'),
                        ])
                          SizedBox(
                            width: 106,
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  item.$2,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _role == item.$1
                                        ? GovColors.navy
                                        : ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              selected: _role == item.$1,
                              selectedColor: GovColors.gold,
                              onSelected: (selected) {
                                if (selected) _selectRole(item.$1);
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? GovColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .08),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_role == Portal.citizen) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _isSignUp
                                        ? (en
                                              ? 'Create Citizen Account'
                                              : 'नागरिक खाता बनाएं')
                                        : (en
                                              ? 'Citizen Login'
                                              : 'नागरिक लॉगिन'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: _toggleMode,
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _isSignUp
                                        ? (en ? 'Login' : 'लॉगिन')
                                        : (en ? 'Sign up' : 'साइन अप'),
                                  ),
                                ),
                              ],
                            ),
                            if (_isSignUp) ...[
                              _input(
                                _nameCtrl,
                                en ? 'Full name' : 'पूरा नाम',
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                              _input(
                                _phoneCtrl,
                                en
                                    ? '10-digit Indian mobile'
                                    : '10 अंकों का मोबाइल नंबर',
                                Icons.phone_outlined,
                                keyboard: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _input(
                              _emailCtrl,
                              en ? 'Email address' : 'ईमेल पता',
                              Icons.email_outlined,
                              keyboard: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _passwordInput(ink, en),
                            const SizedBox(height: 12),
                            _otpInput(ink, en, isDark, active: otpStepActive),
                            const SizedBox(height: 12),
                            Text(
                              en
                                  ? (otpStepActive
                                        ? 'Enter the six-digit code sent to your email, then tap Verify OTP & open portal.'
                                        : (_isSignUp
                                              ? 'Enter the email OTP in the box above after you receive it. Your mobile is validated securely; no SMS OTP is required.'
                                              : 'Use the email and password from your verified account. If verification is pending, a fresh email OTP will be requested here.'))
                                  : (otpStepActive
                                        ? 'ईमेल पर आया छह अंकों का कोड ऊपर भरें, फिर पोर्टल खोलने के लिए सत्यापित करें।'
                                        : 'ईमेल ओटीपी ऊपर दिए बॉक्स में भरें। मोबाइल की सुरक्षित जांच होगी; एसएमएस ओटीपी आवश्यक नहीं है।'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            if (!_isSignUp)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _resendCitizenEmailCode,
                                  child: Text(
                                    en
                                        ? 'Resend email verification code'
                                        : 'ईमेल सत्यापन कोड फिर भेजें',
                                  ),
                                ),
                              ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _isSignUp
                                        ? (_role == Portal.officer
                                              ? (en
                                                    ? 'Create MCG Officer Account'
                                                    : 'एमसीजी अधिकारी खाता बनाएं')
                                              : (en
                                                    ? 'Create Crew Account'
                                                    : 'क्रू खाता बनाएं'))
                                        : (_role == Portal.officer
                                              ? (en
                                                    ? 'MCG Officer Login'
                                                    : 'एमसीजी अधिकारी लॉगिन')
                                              : (en
                                                    ? 'Field Crew Login'
                                                    : 'फील्ड क्रू लॉगिन')),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: _toggleMode,
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _isSignUp
                                        ? (en ? 'Login' : 'लॉगिन')
                                        : (en ? 'Sign up' : 'साइन अप'),
                                  ),
                                ),
                              ],
                            ),
                            if (_isSignUp) ...[
                              _input(
                                _nameCtrl,
                                en ? 'Full name' : 'पूरा नाम',
                                Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _input(
                              _idCtrl,
                              _role == Portal.officer
                                  ? (en
                                        ? '15-character MCG Officer ID'
                                        : '15 अक्षरों की एमसीजी अधिकारी आईडी')
                                  : (en
                                        ? '15-character Crew ID'
                                        : '15 अक्षरों की क्रू आईडी'),
                              Icons.badge_outlined,
                            ),
                            if (_isSignUp) ...[
                              const SizedBox(height: 12),
                              _input(
                                _phoneCtrl,
                                en
                                    ? '10-digit Indian mobile'
                                    : '10 अंकों का मोबाइल नंबर',
                                Icons.phone_outlined,
                                keyboard: TextInputType.phone,
                              ),
                            ],
                            const SizedBox(height: 12),
                            _input(
                              _emailCtrl,
                              en
                                  ? 'Official email address'
                                  : 'आधिकारिक ईमेल पता',
                              Icons.email_outlined,
                              keyboard: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _passwordInput(ink, en),
                            const SizedBox(height: 12),
                            _otpInput(
                              ink,
                              en,
                              isDark,
                              staff: true,
                              active: otpStepActive,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              en
                                  ? (otpStepActive
                                        ? 'Enter the six-digit email OTP in the box above, then verify to open only this staff portal.'
                                        : 'All fields are required. The 15-character issued ID, mobile, email, password, and email OTP are checked before portal access.')
                                  : 'सभी विवरण आवश्यक हैं। पोर्टल प्रवेश से पहले 15 अक्षरों की आईडी, मोबाइल, ईमेल, पासवर्ड और ईमेल ओटीपी की जांच होगी।',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            if (!_isSignUp)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _resendStaffEmailCode(store),
                                  child: Text(
                                    en
                                        ? 'Resend email verification code'
                                        : 'ईमेल सत्यापन कोड फिर भेजें',
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 22),
                          GovButton(
                            label: primaryLabel,
                            isLoading: _isLoading,
                            onPressed: _submit,
                            color: GovColors.navy,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_role == Portal.citizen)
                      GestureDetector(
                        onTap: () {
                          store.setUserName('Guest User');
                          store.setPortal(Portal.citizen);
                          Navigator.pushNamed(context, '/report');
                        },
                        child: const Text(
                          'Emergency Report — continue without login',
                          style: TextStyle(
                            color: GovColors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: GovColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Text(
                'Team FloodBusters • SIH 2026',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          icon: Icon(icon, size: 20, color: GovColors.navy),
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _otpInput(
    Color ink,
    bool en,
    bool isDark, {
    bool staff = false,
    bool active = false,
  }) {
    return SixDigitOtpField(
      controller: _otpCtrl,
      label: staff
          ? (en ? 'Staff email OTP (6 digits)' : 'स्टाफ ईमेल ओटीपी (6 अंक)')
          : (en ? 'Email OTP (6 digits)' : 'ईमेल ओटीपी (6 अंक)'),
      dark: isDark,
      active: active,
      enabled: !_isLoading,
    );
  }

  Widget _passwordInput(Color ink, bool en) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        onChanged: (_) {
          if (_passwordError != null) setState(() => _passwordError = null);
        },
        decoration: InputDecoration(
          icon: const Icon(Icons.lock_outline, color: GovColors.navy),
          hintText: en
              ? 'Password (8+ chars, letter + number)'
              : 'पासवर्ड (8+ अक्षर, अक्षर + अंक)',
          border: InputBorder.none,
          errorText: _passwordError,
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  const _LogoHero();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GovColors.navy.withValues(alpha: .06),
        ),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.shield, color: GovColors.navy, size: 70),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'NALANETRA',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          color: GovColors.navy,
          letterSpacing: 2,
        ),
      ),
      const Text(
        'FLOODGRID MUNICIPAL RESPONSE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: GovColors.gold,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}
