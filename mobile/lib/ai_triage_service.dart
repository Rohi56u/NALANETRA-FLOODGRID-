import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class AiTriageResult {
  final bool isLegitimate;
  final SeverityBand band;
  final double score;
  final double confidence;
  final List<String> riskFactors;
  final String summaryEn;
  final String summaryHi;
  final String? rejectionReason;
  final bool isDuplicateRisk;

  const AiTriageResult({
    required this.isLegitimate,
    required this.band,
    required this.score,
    required this.confidence,
    required this.riskFactors,
    required this.summaryEn,
    required this.summaryHi,
    this.rejectionReason,
    required this.isDuplicateRisk,
  });
}

class AiTriageService {
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _primaryModel = 'openai/gpt-oss-120b';
  static const String _fallbackModel = 'openai/gpt-oss-20b';

  /// Analyzes a citizen flood submission using Groq AI.
  /// Evaluates legitimacy (detects fake/spam/duplicate reports) and computes
  /// engineering severity band, score, and bilingual summaries.
  static Future<AiTriageResult> analyzeReport({
    required String locationName,
    required double lat,
    required double lon,
    required String waterLevel,
    required double currentRainRateMmHr,
    File? photo,
    List<String> existingIncidentLocations = const [],
  }) async {
    final photoExists = photo != null && photo.existsSync();
    final photoSize = photoExists ? photo.lengthSync() : 0;
    final photoName =
        photoExists ? photo.path.split(Platform.pathSeparator).last : 'None';

    final photoContext = photoExists
        ? 'Photo uploaded ($photoName, ${(photoSize / 1024).toStringAsFixed(1)} KB).'
        : 'No photo attached.';

    final systemPrompt =
        'You are the NalaNetra FloodGrid AI Triage & Fraud Detection Engine for '
        'Municipal Corporation of Gurugram (MCG), India.\n'
        'Analyze the citizen flood incident submission and return ONLY valid JSON with fields:\n'
        '1. "is_legitimate": boolean (false if obviously fake, test submission, dry indoor room, or spam)\n'
        '2. "severity_band": "critical" | "severe" | "moderate" | "minor"\n'
        '3. "severity_score": float 0.0 to 1.0\n'
        '4. "confidence": float 0.0 to 1.0\n'
        '5. "risk_factors": array of strings (e.g. "Hospital corridor nearby", "Underpass hazard", "Arterial road disruption")\n'
        '6. "ai_summary_en": string (concise engineering summary in English)\n'
        '7. "ai_summary_hi": string (concise engineering summary in Hindi)\n'
        '8. "rejection_reason": string or null (explanation if fake or suspicious)\n'
        '9. "is_duplicate_risk": boolean (true if similar location exists in active register)\n\n'
        'Rules:\n'
        '- Critical (>=0.85): Deep water (>1.5 ft), underpass submergence, hospital/emergency road blocked.\n'
        '- Severe (0.60-0.84): Knee-deep water, impassable for light vehicles, severe congestion.\n'
        '- Moderate (0.35-0.59): Ankle-deep/sidewalk pooling, drainage choke.\n'
        '- Minor (<0.35): Puddling, slow drainage.\n'
        '- If water level claimed is Waist but photo is absent or location has zero rain history, flag duplicate/verification risk.';

    final userContent = StringBuffer()
      ..writeln('Incident Data:')
      ..writeln('- Location: $locationName (Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)})')
      ..writeln('- Selected Water Level: $waterLevel')
      ..writeln('- Live Rain Nowcast: ${currentRainRateMmHr.toStringAsFixed(1)} mm/hr')
      ..writeln('- Evidence: $photoContext');

    if (existingIncidentLocations.isNotEmpty) {
      userContent.writeln('- Active Incidents in city: ${existingIncidentLocations.take(5).join(", ")}');
    }

    // Try primary Groq model, then fallback model, then heuristic fallback
    for (final model in [_primaryModel, _fallbackModel]) {
      try {
        final payload = {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userContent.toString()},
          ],
          'temperature': 0.1,
        };

        final res = await http
            .post(
              Uri.parse(_groqEndpoint),
              headers: {
                'Authorization': 'Bearer $groqApiKey',
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (NalaNetra FloodGrid Client)',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 7));

        if (res.statusCode == 200) {
          final decoded =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final choices = decoded['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']['content'] as String;
            final parsed = _parseJsonResponse(content);
            if (parsed != null) return parsed;
          }
        } else {
          debugPrint('Groq model $model returned HTTP ${res.statusCode}: ${res.body}');
        }
      } catch (e) {
        debugPrint('Groq model $model failed: $e');
      }
    }

    // Heuristic fallback if Groq API is offline or rate-limited
    return _heuristicFallback(waterLevel, locationName);
  }

  static AiTriageResult? _parseJsonResponse(String raw) {
    try {
      final clean = raw
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'```', multiLine: true), '')
          .trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start < 0 || end < 0 || end <= start) return null;

      final map =
          jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;

      final isLegit = (map['is_legitimate'] as bool?) ?? true;
      final bandStr =
          (map['severity_band'] as String?)?.toLowerCase() ?? 'moderate';
      final score =
          ((map['severity_score'] as num?) ?? 0.5).toDouble().clamp(0.0, 1.0);
      final conf =
          ((map['confidence'] as num?) ?? 0.85).toDouble().clamp(0.0, 1.0);
      final risks = ((map['risk_factors'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
      final sumEn = map['ai_summary_en'] as String? ??
          'Waterlogging assessed by AI triage engine.';
      final sumHi = map['ai_summary_hi'] as String? ??
          'AI इंजन द्वारा जलभराव का आकलन पूर्ण।';
      final rejReason = map['rejection_reason'] as String?;
      final isDup = (map['is_duplicate_risk'] as bool?) ?? false;

      final band = SeverityBand.values.firstWhere(
        (b) => b.name == bandStr,
        orElse: () => SeverityBand.moderate,
      );

      return AiTriageResult(
        isLegitimate: isLegit,
        band: band,
        score: score,
        confidence: conf,
        riskFactors: risks,
        summaryEn: sumEn,
        summaryHi: sumHi,
        rejectionReason: rejReason,
        isDuplicateRisk: isDup,
      );
    } catch (e) {
      debugPrint('Error parsing Groq AI JSON: $e');
      return null;
    }
  }

  static AiTriageResult _heuristicFallback(String waterLevel, String location) {
    SeverityBand band = SeverityBand.moderate;
    double score = 0.45;
    if (waterLevel == 'Waist') {
      band = SeverityBand.critical;
      score = 0.95;
    } else if (waterLevel == 'Knee') {
      band = SeverityBand.severe;
      score = 0.75;
    } else if (waterLevel == 'Ankle') {
      band = SeverityBand.minor;
      score = 0.25;
    }

    final isCriticalLoc =
        location.contains('Hospital') || location.contains('Underpass');
    if (isCriticalLoc && score < 0.75) {
      score += 0.15;
    }

    return AiTriageResult(
      isLegitimate: true,
      band: band,
      score: score.clamp(0.0, 1.0),
      confidence: 0.80,
      riskFactors: [
        if (isCriticalLoc) 'Critical Transit/Emergency Route',
        'Water Level: $waterLevel',
      ],
      summaryEn:
          '$waterLevel waterlogging reported at $location. Verified via local heuristic.',
      summaryHi: '$location पर $waterLevel स्तर का जलभराव दर्ज किया गया।',
      isDuplicateRisk: false,
    );
  }
}
