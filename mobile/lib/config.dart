import 'package:flutter/material.dart';

const appTitle = 'NalaNetra FloodGrid';
const backendBaseUrl = String.fromEnvironment(
  'NALANETRA_BACKEND_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

class GovColors {
  static const navy = Color(0xFF002366);
  static const navyDeep = Color(0xFF00153D);
  static const gold = Color(0xFFC5A059);
  static const orange = Color(0xFFF96816);
  static const critical = Color(0xFFE63946);
  static const ok = Color(0xFF2A9D8F);
  static const background = Color(0xFFF8F9FC);
}

enum AppRole { citizen, officer, crew }

Color bandColor(String band) => switch (band) {
  'CRITICAL' => GovColors.critical,
  'HIGH' => GovColors.orange,
  'MODERATE' => GovColors.gold,
  _ => GovColors.ok,
};
