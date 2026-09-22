import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

import 'config.dart';

/// NalaNetra OTP delivery service.
///
/// Channel priority:
///  1. Fast2SMS REST API (works after one Rs 100 recharge on the account —
///     the user's key is valid; the API route unlocks automatically)
///  2. CallMeBot WhatsApp free API (needs activation key from WhatsApp bot)
///  3. Demo (on-screen OTP) — always works, never breaks a demo
class SmsService {
  // Secrets are injected at build time and are intentionally absent from source.
  static const String fast2smsKey = String.fromEnvironment('FAST2SMS_API_KEY');
  static const bool fast2smsEnabled =
      String.fromEnvironment('FAST2SMS_ENABLED', defaultValue: 'false') ==
      'true';

  // Optional WhatsApp fallback values are also build-time only.
  static const String apiKey = String.fromEnvironment('CALLMEBOT_API_KEY');
  static const String ownPhone = String.fromEnvironment('CALLMEBOT_PHONE');

  static bool get callMeBotConfigured =>
      apiKey.isNotEmpty && ownPhone.isNotEmpty;

  /// Returns [otp, channel] — channel is one of "sms", "whatsapp", "demo".
  static Future<(String, String)> sendOtp(String phone) async {
    final otp = otpGen();

    if (fast2smsEnabled) {
      try {
        final plain = phone.replaceAll('+', '').replaceAll(RegExp(r'^91'), '');
        final r = await http
            .post(
              Uri.parse('https://www.fast2sms.com/dev/bulkV2'),
              headers: {'authorization': fast2smsKey},
              body: {
                'sender_id': 'FLDGRD',
                'message':
                    'Your NalaNetra FloodGrid OTP is $otp. Valid 10 minutes. -Govt Flood Alert',
                'route': 'v3',
                'numbers': '91$plain',
              },
            )
            .timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.body.contains('"return":true')) {
          return (otp, 'sms');
        }
      } catch (_) {
        // fall through to next channel
      }
    }

    if (callMeBotConfigured) {
      try {
        final text = Uri.encodeComponent(
          '*NalaNetra FloodGrid*\\nYour OTP is: *$otp*\\nValid 10 minutes.',
        );
        final url =
            'https://api.callmebot.com/whatsapp.php?phone=${Uri.encodeComponent(ownPhone)}&text=$text&apikey=$apiKey';
        final r = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 25));
        if (r.statusCode == 200 && r.body.contains('Message queued')) {
          return (otp, 'whatsapp');
        }
      } catch (_) {
        // fall through to demo
      }
    }

    return (otp, 'demo');
  }

  static String otpGen() {
    final r = (100000 + DateTime.now().millisecondsSinceEpoch % 900000)
        .toString();
    return r;
  }

  // ---------------------------------------------------------------------------
  // Flood photo severity analysis — Gemini vision
  // ---------------------------------------------------------------------------
  static const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  static Future<FloodAnalysis> analyzeFloodPhoto(File photo, double lat) async {
    final model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: _geminiKey,
    );
    final bytes = await photo.readAsBytes();
    final prompt =
        "You are a municipal flood assessment AI for Gurugram, India. Analyze "
        "this photo and return ONLY JSON: {\"band\":\"critical|severe|moderate|minor\","
        "\"score\":0.0-1.0,\"summary\":\"one short sentence in mixed Hindi-English about water depth and urgency\"}. "
        "critical = deep water (>1ft), vehicle-threatening; severe = knee-deep, traffic blocked; "
        "moderate = ankle-deep pooling; minor = slight puddling. Base it on visible water extent, depth cues and risk."
        "Use band and score consistently: critical >= 0.8, severe >= 0.55, moderate >= 0.3, else minor.";
    final response = await model.generateContent([
      Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)]),
    ]);
    final text = response.text ?? '';
    final jsonStr = text
        .replaceAll(RegExp(r'^```json\s*'), '')
        .replaceAll(RegExp(r'```'), '')
        .trim();
    final start = jsonStr.indexOf('{');
    final end = jsonStr.lastIndexOf('}');
    String bandStr = 'moderate';
    double score = 0.5;
    String summary = 'Water level assessed by AI';
    try {
      final map = jsonDecode(
        jsonStr.substring(
          start < 0 ? 0 : start,
          end < 0 ? jsonStr.length : end + 1,
        ),
      ) as Map;
      bandStr = (map['band']?.toString().toLowerCase() ?? 'moderate');
      if (!['critical', 'severe', 'moderate', 'minor'].contains(bandStr))
        bandStr = 'moderate';
      score = (map['score'] ?? 0.5).toDouble();
      summary = map['summary']?.toString() ?? summary;
    } catch (_) {}
    return FloodAnalysis(
      band: SeverityBand.values.firstWhere(
        (b) => b.name == bandStr,
        orElse: () => SeverityBand.moderate,
      ),
      score: score,
      summary: summary,
    );
  }
}

class FloodAnalysis {
  final SeverityBand band;
  final double score;
  final String summary;
  const FloodAnalysis({
    required this.band,
    required this.score,
    required this.summary,
  });
}
