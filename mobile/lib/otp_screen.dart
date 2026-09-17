import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'citizen_auth_service.dart';
import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  bool _error = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final store = context.read<AppStore>();
    final citizen = store.pendingCitizenChallenge != null;
    final staffChallenge = store.pendingStaffChallenge;
    final code = _codeCtrl.text.trim();
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        throw const CitizenAuthException(
          'Enter the six-digit OTP sent to your email.',
        );
      }
      if (citizen) {
        await store.verifyCitizen(emailCode: code);
        if (mounted)
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (staffChallenge != null) {
        await store.verifyStaff(portal: staffChallenge.portal, emailCode: code);
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            staffChallenge.portal == Portal.officer ? '/officer' : '/crew',
            (route) => false,
          );
        }
      } else {
        throw const CitizenAuthException(
          'Verification session expired. Start again.',
        );
      }
    } on CitizenAuthException catch (e) {
      if (mounted) {
        setState(() => _error = true);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final store = context.read<AppStore>();
    final staffChallenge = store.pendingStaffChallenge;
    try {
      if (store.pendingCitizenChallenge != null) {
        await store.resendCitizenCodes();
      } else if (staffChallenge != null) {
        await store.resendStaffCode(
          portal: staffChallenge.portal,
          staffId: store.pendingStaffId,
          email: store.pendingStaffEmail,
        );
      } else {
        throw const CitizenAuthException(
          'Verification session expired. Start again.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New six-digit email OTP sent.')),
        );
      }
    } on CitizenAuthException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final citizen = store.pendingCitizenChallenge != null;
    final staffChallenge = store.pendingStaffChallenge;
    final staff = staffChallenge != null;
    final dark = store.themeMode == AppThemeMode.dark;
    final ink = dark ? Colors.white : GovColors.navy;
    final portalLabel = staffChallenge?.portal == Portal.officer
        ? 'MCG Officer'
        : 'Field Crew';

    return Scaffold(
      backgroundColor: dark ? GovColors.bgDark : GovColors.bgLight,
      appBar: AppBar(
        title: Text(
          citizen
              ? 'Verify Citizen Account'
              : staff
              ? 'Verify $portalLabel Account'
              : 'Email Verification',
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              staff ? Icons.badge_outlined : Icons.verified_user_outlined,
              size: 52,
              color: GovColors.gold,
            ),
            const SizedBox(height: 18),
            Text(
              staff ? 'Confirm your work email' : 'Confirm your email',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the six-digit code sent to your email. Codes expire in 10 minutes.',
              style: TextStyle(
                color: dark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            _codeField(dark),
            if (_error)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Verification failed. Check the code and try again.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GovColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'VERIFY & CONTINUE',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _resend,
                child: const Text('Resend verification email'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codeField(bool dark) {
    return SixDigitOtpField(
      controller: _codeCtrl,
      label: 'Email verification code (6 digits)',
      dark: dark,
      active: true,
      enabled: !_busy,
    );
  }
}
