import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// NalaNetra FloodGrid — Government design tokens (Navy / Gold / White)
// ---------------------------------------------------------------------------

const String appTitle = 'NalaNetra FloodGrid';

class GovColors {
  // Mockup-exact primary colors
  static const Color navy = Color(0xFF002366); // Official Indian Navy Blue
  static const Color navyDeep = Color(0xFF00153D); // Darker shade for gradients
  static const Color gold = Color(0xFFC5A059); // Premium Gold
  static const Color orange = Color(0xFFF96816); // Vibrant GOI Orange
  static const Color white = Colors.white;

  // Semantic status colors (High Fidelity)
  static const Color critical = Color(0xFFE63946);
  static const Color severe = Color(0xFFF4A261);
  static const Color moderate = Color(0xFFE9C46A);
  static const Color ok = Color(0xFF2A9D8F);

  // Card and surface colors
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1A2235);
  static const Color bgLight = Color(0xFFF8F9FC);
  static const Color bgDark = Color(0xFF0D121F);

  // Missing semantic colors restored for legacy screens
  static const Color warning = Color(0xFFE9C46A);
  static const Color onSite = Color(0xFF457B9D);
  static const Color info = Color(0xFF1D3557);
}

class GovFonts {
  static const String family = 'Poppins';
}

// ---------------------------------------------------------------------------
// Portals
// ---------------------------------------------------------------------------

enum Portal { citizen, officer, crew, admin }

class PortalMeta {
  final Portal portal;
  final String labelEn;
  final String labelHi;
  final IconData icon;
  const PortalMeta(this.portal, this.labelEn, this.labelHi, this.icon);
}

const List<PortalMeta> portals = [
  PortalMeta(Portal.citizen, 'Citizen', 'नागरिक', Icons.person_outline),
  PortalMeta(
    Portal.officer,
    'MCG Officer',
    'MCG अधिकारी',
    Icons.account_balance,
  ),
  PortalMeta(Portal.crew, 'Field Crew', 'फील्ड क्रू', Icons.engineering),
  PortalMeta(
    Portal.admin,
    'Super Admin',
    'सुपर एडमिन',
    Icons.admin_panel_settings,
  ),
];

// ---------------------------------------------------------------------------
// Language + Theme
// ---------------------------------------------------------------------------

enum AppLang { en, hi }

enum AppThemeMode { light, dark }

enum JobStatus { pending, inProgress, completed, verified }

// Central theme helper: pick the right text color based on current theme so
// dark mode ALWAYS renders light text on dark surfaces (bug fix #2).
class ThemeText {
  /// Default text color for the current theme: dark ink on light theme,
  /// near-white on dark theme. Never navy-on-dark (invisible).
  static Color colorOf(BuildContext context, {Color? accent}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (accent != null) return accent;
    return dark ? const Color(0xFFF0F2F8) : const Color(0xFF1F2B4E);
  }

  static Color secondaryOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFB9C2DA) : const Color(0xFF6B7490);
  }

  static Color cardOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF1F2B4E) : Colors.white;
  }

  static Color surfaceOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF131A33) : const Color(0xFFF5F6FA);
  }

  static Color dividerOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF3A4466) : const Color(0xFFE4E7F0);
  }
}

// ---------------------------------------------------------------------------
// Severity bands
// ---------------------------------------------------------------------------

enum SeverityBand { critical, severe, moderate, minor }

class SeverityMeta {
  final SeverityBand band;
  final String label;
  final Color color;
  const SeverityMeta(this.band, this.label, this.color);
}

const List<SeverityMeta> severityMetas = [
  SeverityMeta(SeverityBand.critical, 'Critical', GovColors.critical),
  SeverityMeta(SeverityBand.severe, 'Severe', GovColors.severe),
  SeverityMeta(SeverityBand.moderate, 'Moderate', GovColors.moderate),
  SeverityMeta(SeverityBand.minor, 'Minor', GovColors.ok),
];

SeverityMeta severityOf(SeverityBand band) =>
    severityMetas.firstWhere((m) => m.band == band);

// ---------------------------------------------------------------------------
// Incident lifecycle (state machine)
// ---------------------------------------------------------------------------

class IncidentLifecycle {
  final String key;
  final String labelEn;
  final String labelHi;
  final Color color;
  const IncidentLifecycle._(this.key, this.labelEn, this.labelHi, this.color);

  static const submitted = IncidentLifecycle._(
    'submitted',
    'SUBMITTED',
    'जमा किया गया',
    Color(0xFF6B7490),
  );
  static const merged = IncidentLifecycle._(
    'merged',
    'MERGED',
    'विलय किया गया',
    Color(0xFF1565C0),
  );
  static const dispatched = IncidentLifecycle._(
    'dispatched',
    'DISPATCHED',
    'भेजा गया',
    Color(0xFF6A1B9A),
  );
  static const onSite = IncidentLifecycle._(
    'on_site',
    'CREW ON SITE',
    'क्रू साइट पर',
    Color(0xFFE8611A),
  );
  static const workProgress = IncidentLifecycle._(
    'work_progress',
    'WORK IN PROGRESS',
    'काम प्रगति पर',
    Color(0xFFC9A227),
  );
  static const verified = IncidentLifecycle._(
    'verified',
    'VERIFIED & CLOSED',
    'सत्यापित और बंद',
    Color(0xFF2E7D32),
  );

  static const List<IncidentLifecycle> all = [
    submitted,
    merged,
    dispatched,
    onSite,
    workProgress,
    verified,
  ];

  String get label => labelEn;
}

// ---------------------------------------------------------------------------
// Crew job
// ---------------------------------------------------------------------------

class CrewJob {
  String incidentId;
  String location;
  double lat;
  double lon;
  int priority;
  int severity;
  int reporters;
  String crewName;
  String wing;
  String beforePhotoPath;
  String afterPhotoPath;
  // Optional supplied evidence preview shown in Verify while real crew proof
  // is pending. This is never treated as after-proof or verification evidence.
  String? pendingPreviewPath;
  bool afterProofUploaded;
  DateTime? afterUploadedAt;
  IncidentLifecycle status;
  DateTime dispatchedAt;
  CrewJob({
    required this.incidentId,
    required this.location,
    required this.lat,
    required this.lon,
    required this.priority,
    required this.severity,
    required this.reporters,
    required this.crewName,
    required this.wing,
    required this.afterPhotoPath,
    required this.beforePhotoPath,
    this.pendingPreviewPath,
    this.afterProofUploaded = false,
    this.afterUploadedAt,
    required this.status,
    required this.dispatchedAt,
  });

  bool get hasAfterProof =>
      afterProofUploaded && afterPhotoPath.trim().isNotEmpty;

  bool get isDone => status == IncidentLifecycle.verified;

  String get locationName => location;
  String get severityLabel => 'Severity $severity';
  String get statusLabel => status.label;
  void setStatus(IncidentLifecycle s) => status = s;
}

// ---------------------------------------------------------------------------
// Gurugram locations — FULL selectable list (bug fix: user could only pick
// Sector 14). Now ~150 entries: all 122 sectors + key areas, roads, malls,
// hospitals, metro stations. Searchable in report flow and live map.
// ---------------------------------------------------------------------------

class GurugramLocation {
  final String name;
  final String category;
  final double lat;
  final double lon;
  final double criticality; // 0-1 (hospital/school/senior-citizen density)
  const GurugramLocation(
    this.name,
    this.category,
    this.lat,
    this.lon,
    this.criticality,
  );
}

const List<GurugramLocation> gurugramLocations = [
  // ---- Old Gurugram
  GurugramLocation(
    'Old Gurugram — Railway Road',
    'Old Gurugram',
    28.4637,
    77.0197,
    0.8,
  ),
  GurugramLocation(
    'Old Gurugram — Sadar Bazar',
    'Old Gurugram',
    28.4620,
    77.0160,
    0.9,
  ),
  GurugramLocation(
    'Old Gurugram — Subhash Chowk',
    'Old Gurugram',
    28.4600,
    77.0130,
    0.8,
  ),
  GurugramLocation(
    'Old Gurugram — Bus Stand',
    'Old Gurugram',
    28.4626,
    77.0121,
    0.8,
  ),
  GurugramLocation(
    'Old Gurugram — Gurugram Railway Station',
    'Old Gurugram',
    28.4754,
    77.0142,
    0.9,
  ),
  GurugramLocation(
    'Old Gurugram — Krishna Chowk',
    'Old Gurugram',
    28.4645,
    77.0213,
    0.7,
  ),
  GurugramLocation(
    'Old Gurugram — Huda Market',
    'Old Gurugram',
    28.4670,
    77.0230,
    0.7,
  ),

  // ---- Sectors 1-9 (Old City)
  GurugramLocation('Sector 1 — Market', 'Sector 1-9', 28.4530, 77.0240, 0.5),
  GurugramLocation('Sector 2', 'Sector 1-9', 28.4490, 77.0130, 0.4),
  GurugramLocation('Sector 3', 'Sector 1-9', 28.4560, 77.0080, 0.4),
  GurugramLocation('Sector 4', 'Sector 1-9', 28.4430, 77.0050, 0.4),
  GurugramLocation('Sector 5', 'Sector 1-9', 28.4400, 76.9990, 0.4),
  GurugramLocation('Sector 6', 'Sector 1-9', 28.4380, 76.9930, 0.4),
  GurugramLocation('Sector 7', 'Sector 1-9', 28.4450, 76.9870, 0.4),
  GurugramLocation('Sector 8', 'Sector 1-9', 28.4510, 76.9830, 0.4),
  GurugramLocation('Sector 9', 'Sector 1-9', 28.4580, 76.9820, 0.4),

  // ---- Sectors 10-20 (Central Gurugram — highest waterlogging risk)
  GurugramLocation('Sector 10 — Market', 'Sector 10-20', 28.4520, 77.0300, 0.6),
  GurugramLocation('Sector 11', 'Sector 10-20', 28.4480, 77.0350, 0.5),
  GurugramLocation('Sector 12', 'Sector 10-20', 28.4460, 77.0420, 0.5),
  GurugramLocation(
    'Sector 14 — Sheetla Mata Road',
    'Sector 10-20',
    28.4586,
    77.0294,
    0.9,
  ),
  GurugramLocation(
    'Sector 14 — Railway Road Market',
    'Sector 10-20',
    28.4600,
    77.0280,
    0.9,
  ),
  GurugramLocation(
    'Sector 14 — HUDA Shopping Complex',
    'Sector 10-20',
    28.4570,
    77.0310,
    0.7,
  ),
  GurugramLocation(
    'Sector 15 — Bus Stand & Market',
    'Sector 10-20',
    28.4637,
    77.0404,
    0.8,
  ),
  GurugramLocation(
    'Sector 15 — Chakkarpur Road',
    'Sector 10-20',
    28.4650,
    77.0420,
    0.6,
  ),
  GurugramLocation('Sector 16 — Market', 'Sector 10-20', 28.4690, 77.0370, 0.6),
  GurugramLocation(
    'Sector 17 — Market & Temple',
    'Sector 10-20',
    28.4720,
    77.0350,
    0.6,
  ),
  GurugramLocation(
    'Sector 18 — Civil Lines',
    'Sector 10-20',
    28.4760,
    77.0330,
    0.7,
  ),
  GurugramLocation(
    'Sector 19 — Civil Lines',
    'Sector 10-20',
    28.4790,
    77.0300,
    0.6,
  ),
  GurugramLocation('Sector 20', 'Sector 10-20', 28.4820, 77.0280, 0.5),

  // ---- Sectors 21-30
  GurugramLocation('Sector 21 — Market', 'Sector 21-30', 28.4740, 77.0440, 0.7),
  GurugramLocation(
    'Sector 21 — Railway Colony',
    'Sector 21-30',
    28.4720,
    77.0480,
    0.6,
  ),
  GurugramLocation('Sector 22 — Market', 'Sector 21-30', 28.4690, 77.0470, 0.6),
  GurugramLocation('Sector 23 — Market', 'Sector 21-30', 28.4660, 77.0500, 0.6),
  GurugramLocation(
    'Sector 23 — Old DLF',
    'Sector 21-30',
    28.4640,
    77.0540,
    0.5,
  ),
  GurugramLocation('Sector 24', 'Sector 21-30', 28.4610, 77.0580, 0.5),
  GurugramLocation('Sector 26 — Market', 'Sector 21-30', 28.4682, 77.0543, 0.6),
  GurugramLocation(
    'Sector 26 — Old Delhi Road',
    'Sector 21-30',
    28.4700,
    77.0560,
    0.6,
  ),
  GurugramLocation(
    'Sector 27 — VIP Road',
    'Sector 21-30',
    28.4800,
    77.0520,
    0.5,
  ),
  GurugramLocation('Sector 28', 'Sector 21-30', 28.4830, 77.0500, 0.5),
  GurugramLocation('Sector 29', 'Sector 21-30', 28.4860, 77.0480, 0.5),
  GurugramLocation('Sector 30', 'Sector 21-30', 28.4890, 77.0460, 0.5),

  // ---- Sectors 31-40
  GurugramLocation('Sector 31', 'Sector 31-40', 28.4550, 77.0620, 0.6),
  GurugramLocation(
    'Sector 32 — Golf Course Ext Road',
    'Sector 31-40',
    28.4480,
    77.0650,
    0.7,
  ),
  GurugramLocation('Sector 33', 'Sector 31-40', 28.4420, 77.0680, 0.5),
  GurugramLocation('Sector 34', 'Sector 31-40', 28.4360, 77.0710, 0.5),
  GurugramLocation('Sector 35', 'Sector 31-40', 28.4300, 77.0740, 0.5),
  GurugramLocation('Sector 36', 'Sector 31-40', 28.4240, 77.0770, 0.5),
  GurugramLocation('Sector 37', 'Sector 31-40', 28.4590, 77.0700, 0.6),
  GurugramLocation(
    'Sector 37C — Iffco Chowk',
    'Sector 31-40',
    28.4710,
    77.0800,
    0.8,
  ),
  GurugramLocation(
    'Sector 37C — Metro Station',
    'Sector 31-40',
    28.4730,
    77.0820,
    0.7,
  ),
  GurugramLocation('Sector 38', 'Sector 31-40', 28.4740, 77.0880, 0.5),
  GurugramLocation('Sector 39', 'Sector 31-40', 28.4760, 77.0940, 0.5),
  GurugramLocation('Sector 40', 'Sector 31-40', 28.4780, 77.1000, 0.5),

  // ---- Sectors 41-50
  GurugramLocation(
    'Sector 41 — Rajiv Chowk (MG Road)',
    'Sector 41-50',
    28.4562,
    77.0274,
    0.9,
  ),
  GurugramLocation(
    'Sector 42 — Rajiv Chowk',
    'Sector 41-50',
    28.4540,
    77.0230,
    0.9,
  ),
  GurugramLocation(
    'Sector 43 — Golf Course Road',
    'Sector 41-50',
    28.4400,
    77.0880,
    0.7,
  ),
  GurugramLocation(
    'Sector 44 — NH-8 (Underpass)',
    'Sector 41-50',
    28.4860,
    77.0860,
    0.8,
  ),
  GurugramLocation(
    'Sector 45 — NH-8 Underpass',
    'Sector 41-50',
    28.4830,
    77.0800,
    0.9,
  ),
  GurugramLocation(
    'Sector 46 — Golf Course Ext',
    'Sector 41-50',
    28.4380,
    77.0930,
    0.6,
  ),
  GurugramLocation(
    'Sector 47 — Golf Course Ext',
    'Sector 41-50',
    28.4340,
    77.0990,
    0.6,
  ),
  GurugramLocation(
    'Sector 48 — Golf Course Ext',
    'Sector 41-50',
    28.4300,
    77.1050,
    0.6,
  ),
  GurugramLocation('Sector 49 — NH-8', 'Sector 41-50', 28.4260, 77.1100, 0.7),
  GurugramLocation(
    'Sector 49 — Sohna Road',
    'Sector 41-50',
    28.4187,
    77.0621,
    0.8,
  ),
  GurugramLocation(
    'Sector 50 — Sohna Road',
    'Sector 41-50',
    28.4140,
    77.0560,
    0.7,
  ),

  // ---- Sectors 51-60
  GurugramLocation(
    'Sector 51 — Sohna Road',
    'Sector 51-60',
    28.4090,
    77.0500,
    0.6,
  ),
  GurugramLocation(
    'Sector 52 — Rapid Metro',
    'Sector 51-60',
    28.4320,
    77.0860,
    0.7,
  ),
  GurugramLocation(
    'Sector 53 — Golf Course Road',
    'Sector 51-60',
    28.4260,
    77.0920,
    0.6,
  ),
  GurugramLocation(
    'Sector 54 — Golf Course Road',
    'Sector 51-60',
    28.4339,
    77.1007,
    0.7,
  ),
  GurugramLocation(
    'Sector 54 — HUDA Market',
    'Sector 51-60',
    28.4360,
    77.1030,
    0.7,
  ),
  GurugramLocation('Sector 55', 'Sector 51-60', 28.4300, 77.1080, 0.5),
  GurugramLocation('Sector 56 — NH-8', 'Sector 51-60', 28.4280, 77.1000, 0.7),
  GurugramLocation(
    'Sector 56 — Badshahpur Road',
    'Sector 51-60',
    28.4250,
    77.1040,
    0.6,
  ),
  GurugramLocation('Sector 57 — Market', 'Sector 51-60', 28.4378, 77.0574, 0.6),
  GurugramLocation(
    'Sector 57 — Sohna Road',
    'Sector 51-60',
    28.4350,
    77.0610,
    0.7,
  ),
  GurugramLocation('Sector 58', 'Sector 51-60', 28.4400, 77.0650, 0.5),
  GurugramLocation('Sector 59', 'Sector 51-60', 28.4440, 77.0690, 0.5),
  GurugramLocation('Sector 60', 'Sector 51-60', 28.4480, 77.0730, 0.5),

  // ---- Sectors 61-70 (New Gurugram)
  GurugramLocation(
    'Sector 61 — Golf Course Ext',
    'Sector 61-70',
    28.4200,
    77.1120,
    0.6,
  ),
  GurugramLocation(
    'Sector 62 — Golf Course Ext',
    'Sector 61-70',
    28.4160,
    77.1170,
    0.6,
  ),
  GurugramLocation('Sector 63', 'Sector 61-70', 28.4120, 77.1220, 0.5),
  GurugramLocation('Sector 65', 'Sector 61-70', 28.4050, 77.1280, 0.5),
  GurugramLocation('Sector 66', 'Sector 61-70', 28.4000, 77.1330, 0.5),
  GurugramLocation('Sector 67', 'Sector 61-70', 28.3950, 77.1380, 0.5),
  GurugramLocation('Sector 68', 'Sector 61-70', 28.3900, 77.1430, 0.5),
  GurugramLocation('Sector 69', 'Sector 61-70', 28.3850, 77.1480, 0.5),
  GurugramLocation('Sector 70', 'Sector 61-70', 28.3800, 77.1530, 0.5),

  // ---- Sectors 71-85
  GurugramLocation('Sector 71', 'Sector 71-85', 28.4510, 77.0760, 0.5),
  GurugramLocation('Sector 72', 'Sector 71-85', 28.4550, 77.0800, 0.5),
  GurugramLocation('Sector 73', 'Sector 71-85', 28.4590, 77.0840, 0.5),
  GurugramLocation('Sector 74', 'Sector 71-85', 28.4630, 77.0880, 0.5),
  GurugramLocation('Sector 75', 'Sector 71-85', 28.4670, 77.0920, 0.5),
  GurugramLocation('Sector 76', 'Sector 71-85', 28.4710, 77.0960, 0.5),
  GurugramLocation('Sector 77', 'Sector 71-85', 28.4750, 77.1000, 0.5),
  GurugramLocation('Sector 78', 'Sector 71-85', 28.4790, 77.1040, 0.5),
  GurugramLocation('Sector 79', 'Sector 71-85', 28.4830, 77.1080, 0.5),
  GurugramLocation('Sector 80', 'Sector 71-85', 28.4870, 77.1120, 0.5),
  GurugramLocation('Sector 81', 'Sector 71-85', 28.4910, 77.1160, 0.5),
  GurugramLocation('Sector 82', 'Sector 71-85', 28.4950, 77.1200, 0.5),
  GurugramLocation('Sector 83', 'Sector 71-85', 28.4990, 77.1240, 0.5),
  GurugramLocation('Sector 84', 'Sector 71-85', 28.5030, 77.1280, 0.5),
  GurugramLocation('Sector 85', 'Sector 71-85', 28.5070, 77.1320, 0.5),

  // ---- Sectors 86-100
  GurugramLocation('Sector 86', 'Sector 86-100', 28.4100, 77.0400, 0.5),
  GurugramLocation('Sector 88', 'Sector 86-100', 28.4000, 77.0300, 0.5),
  GurugramLocation('Sector 90', 'Sector 86-100', 28.3900, 77.0200, 0.5),
  GurugramLocation('Sector 91', 'Sector 86-100', 28.3800, 77.0100, 0.5),
  GurugramLocation('Sector 92', 'Sector 86-100', 28.3700, 77.0000, 0.5),
  GurugramLocation('Sector 93', 'Sector 86-100', 28.3600, 76.9900, 0.5),
  GurugramLocation('Sector 95', 'Sector 86-100', 28.3400, 76.9700, 0.5),
  GurugramLocation('Sector 99', 'Sector 86-100', 28.4500, 77.1300, 0.5),
  GurugramLocation('Sector 100', 'Sector 86-100', 28.4540, 77.1340, 0.5),

  // ---- Sectors 101-125
  GurugramLocation(
    'Sector 102 — NH-8',
    'Sector 101-125',
    28.4480,
    77.1400,
    0.6,
  ),
  GurugramLocation(
    'Sector 103 — NH-8',
    'Sector 101-125',
    28.4440,
    77.1460,
    0.6,
  ),
  GurugramLocation('Sector 104', 'Sector 101-125', 28.4400, 77.1520, 0.5),
  GurugramLocation('Sector 105', 'Sector 101-125', 28.4360, 77.1580, 0.5),
  GurugramLocation('Sector 106', 'Sector 101-125', 28.4320, 77.1640, 0.5),
  GurugramLocation('Sector 107', 'Sector 101-125', 28.4280, 77.1700, 0.5),
  GurugramLocation('Sector 108', 'Sector 101-125', 28.4240, 77.1760, 0.5),
  GurugramLocation('Sector 109', 'Sector 101-125', 28.4200, 77.1820, 0.5),
  GurugramLocation('Sector 110', 'Sector 101-125', 28.4160, 77.1880, 0.5),
  GurugramLocation('Sector 111', 'Sector 101-125', 28.4120, 77.1940, 0.5),
  GurugramLocation('Sector 112', 'Sector 101-125', 28.4080, 77.2000, 0.5),
  GurugramLocation('Sector 113', 'Sector 101-125', 28.4040, 77.2060, 0.5),
  GurugramLocation('Sector 114', 'Sector 101-125', 28.4000, 77.2120, 0.5),
  GurugramLocation('Sector 115', 'Sector 101-125', 28.3960, 77.2180, 0.5),

  // ---- Key roads & underpasses (most flood-prone)
  GurugramLocation(
    'MG Road Underpass — Rajiv Chowk',
    'Roads & Underpasses',
    28.4562,
    77.0274,
    1.0,
  ),
  GurugramLocation(
    'NH-8 Sector 44 Underpass',
    'Roads & Underpasses',
    28.4860,
    77.0860,
    0.9,
  ),
  GurugramLocation(
    'NH-8 Sector 45 Underpass',
    'Roads & Underpasses',
    28.4830,
    77.0800,
    0.9,
  ),
  GurugramLocation(
    'NH-48 near Narsinghpur',
    'Roads & Underpasses',
    28.3843,
    76.9442,
    0.9,
  ),
  GurugramLocation(
    'Sohna Road — Sector 49 stretch',
    'Roads & Underpasses',
    28.4187,
    77.0621,
    0.8,
  ),
  GurugramLocation(
    'Sohna Road — Sector 50 stretch',
    'Roads & Underpasses',
    28.4140,
    77.0560,
    0.7,
  ),
  GurugramLocation(
    'Badshahpur Road',
    'Roads & Underpasses',
    28.3986,
    77.0969,
    0.8,
  ),
  GurugramLocation(
    'Kherki Daula Flyover (NH-48)',
    'Roads & Underpasses',
    28.4041,
    77.0178,
    0.8,
  ),
  GurugramLocation(
    'Old Railway Road',
    'Roads & Underpasses',
    28.4618,
    77.0225,
    0.9,
  ),
  GurugramLocation(
    'NH-8 Baani Square',
    'Roads & Underpasses',
    28.4421,
    77.0433,
    0.7,
  ),
  GurugramLocation(
    'Golf Course Road — Sector 54',
    'Roads & Underpasses',
    28.4339,
    77.1007,
    0.7,
  ),
  GurugramLocation(
    'Golf Course Extension Road',
    'Roads & Underpasses',
    28.4300,
    77.0950,
    0.7,
  ),
  GurugramLocation(
    'Delhi-Gurugram Expressway (NH-48)',
    'Roads & Underpasses',
    28.5000,
    77.0800,
    0.8,
  ),
  GurugramLocation(
    'Farrukhnagar Road',
    'Roads & Underpasses',
    28.3700,
    76.9600,
    0.6,
  ),
  GurugramLocation(
    'Pataudi Road',
    'Roads & Underpasses',
    28.3900,
    76.9200,
    0.5,
  ),

  // ---- Hospitals (critical priority)
  GurugramLocation(
    'Medanta — The Medicity, Sector 38',
    'Hospitals',
    28.4820,
    77.0900,
    1.0,
  ),
  GurugramLocation(
    'Fortis Memorial Research Institute, Sector 44',
    'Hospitals',
    28.4840,
    77.0880,
    1.0,
  ),
  GurugramLocation(
    'Artemis Hospital, Sector 51',
    'Hospitals',
    28.4410,
    77.0750,
    1.0,
  ),
  GurugramLocation(
    'Max Super Speciality, Sushant Lok',
    'Hospitals',
    28.4670,
    77.0640,
    1.0,
  ),
  GurugramLocation(
    'CK Birla Hospital (BMHRC), Sector 51',
    'Hospitals',
    28.4430,
    77.0770,
    1.0,
  ),
  GurugramLocation(
    'W Pratiksha Hospital, Sector 56',
    'Hospitals',
    28.4270,
    77.1010,
    1.0,
  ),
  GurugramLocation(
    'Columbia Asia, Palam Vihar',
    'Hospitals',
    28.5100,
    77.0400,
    1.0,
  ),
  GurugramLocation(
    'Narayana Multispeciality, Sector 28',
    'Hospitals',
    28.4800,
    77.0460,
    1.0,
  ),

  // ---- Malls & commercial
  GurugramLocation(
    'Ambience Mall, NH-8',
    'Malls & Commercial',
    28.4932,
    77.1025,
    0.6,
  ),
  GurugramLocation(
    'MGF Metropolitan Mall, Sector 28',
    'Malls & Commercial',
    28.4816,
    77.0840,
    0.6,
  ),
  GurugramLocation(
    'DLF CyberHub, DLF Phase 3',
    'Malls & Commercial',
    28.4940,
    77.0890,
    0.7,
  ),
  GurugramLocation(
    'DLF Phase 3 — Cyber City',
    'Malls & Commercial',
    28.4934,
    77.0904,
    0.7,
  ),
  GurugramLocation(
    'Worldmark, DLF Phase 3',
    'Malls & Commercial',
    28.4950,
    77.0920,
    0.6,
  ),
  GurugramLocation(
    'Central Square, Sector 29',
    'Malls & Commercial',
    28.4870,
    77.0460,
    0.6,
  ),
  GurugramLocation(
    'V3S East Centre, Sector 11',
    'Malls & Commercial',
    28.4490,
    77.0340,
    0.6,
  ),

  // ---- Metro / Rapid Metro stations
  GurugramLocation(
    'IFFCO Chowk Metro Station',
    'Metro Stations',
    28.4710,
    77.0780,
    0.8,
  ),
  GurugramLocation(
    'MG Road Metro Station',
    'Metro Stations',
    28.4630,
    77.0270,
    0.8,
  ),
  GurugramLocation(
    'Gurugram Metro Station (HUDA City Centre)',
    'Metro Stations',
    28.4590,
    77.0640,
    0.7,
  ),
  GurugramLocation(
    'Sikanderpur Metro Station',
    'Metro Stations',
    28.4780,
    77.1010,
    0.7,
  ),
  GurugramLocation(
    'Phase 2 Metro Station',
    'Metro Stations',
    28.4800,
    77.1050,
    0.6,
  ),
  GurugramLocation(
    'Belvedere Towers Rapid Metro',
    'Metro Stations',
    28.4660,
    77.0870,
    0.6,
  ),
  GurugramLocation(
    'Sector 53-54 Rapid Metro',
    'Metro Stations',
    28.4300,
    77.1020,
    0.6,
  ),
  GurugramLocation(
    'Sector 42-43 Rapid Metro',
    'Metro Stations',
    28.4520,
    77.0830,
    0.6,
  ),
  GurugramLocation(
    'Sector 55-56 Rapid Metro',
    'Metro Stations',
    28.4260,
    77.1010,
    0.6,
  ),

  // ---- Schools & colleges
  GurugramLocation(
    'DPS Sector 45',
    'Schools & Colleges',
    28.4810,
    77.0830,
    0.8,
  ),
  GurugramLocation(
    'Amity International School, Sector 46',
    'Schools & Colleges',
    28.4360,
    77.0920,
    0.8,
  ),
  GurugramLocation(
    'GD Goenka School, Sohna Road',
    'Schools & Colleges',
    28.4100,
    77.0450,
    0.8,
  ),
  GurugramLocation(
    'Suncity School, Sector 54',
    'Schools & Colleges',
    28.4370,
    77.1020,
    0.8,
  ),
  GurugramLocation(
    'IILM University, Sector 53',
    'Schools & Colleges',
    28.4220,
    77.0960,
    0.7,
  ),
  GurugramLocation(
    'BML Munjal University, NH-8',
    'Schools & Colleges',
    28.3300,
    76.9100,
    0.7,
  ),

  // ---- Residential colonies & villages
  GurugramLocation(
    'Sushant Lok Phase 1',
    'Colonies & Villages',
    28.4670,
    77.0650,
    0.7,
  ),
  GurugramLocation(
    'Sushant Lok Phase 2',
    'Colonies & Villages',
    28.4580,
    77.0720,
    0.6,
  ),
  GurugramLocation(
    'Sushant Lok Phase 3',
    'Colonies & Villages',
    28.4490,
    77.0790,
    0.6,
  ),
  GurugramLocation('Palam Vihar', 'Colonies & Villages', 28.5120, 77.0380, 0.6),
  GurugramLocation(
    'South City 1',
    'Colonies & Villages',
    28.4100,
    77.0800,
    0.6,
  ),
  GurugramLocation(
    'South City 2',
    'Colonies & Villages',
    28.4000,
    77.0900,
    0.6,
  ),
  GurugramLocation(
    'Ansal Palam Vihar Extension',
    'Colonies & Villages',
    28.5150,
    77.0350,
    0.5,
  ),
  GurugramLocation(
    'Ardee City, Sector 52',
    'Colonies & Villages',
    28.4310,
    77.0840,
    0.6,
  ),
  GurugramLocation(
    'Nirvana Country, Sector 50',
    'Colonies & Villages',
    28.4120,
    77.0600,
    0.6,
  ),
  GurugramLocation(
    'Tulip Violet, Sector 70',
    'Colonies & Villages',
    28.3780,
    77.1540,
    0.5,
  ),
  GurugramLocation(
    'Emaar Palm Heights, Sector 77',
    'Colonies & Villages',
    28.4740,
    77.1010,
    0.5,
  ),
  GurugramLocation(
    'Adani Brahma Samsara, Sector 63',
    'Colonies & Villages',
    28.4130,
    77.1210,
    0.5,
  ),
  GurugramLocation(
    'Kherki Daula Village',
    'Colonies & Villages',
    28.4030,
    77.0170,
    0.6,
  ),
  GurugramLocation(
    'Garhi Harsaru Village',
    'Colonies & Villages',
    28.4300,
    76.9500,
    0.5,
  ),
  GurugramLocation('Bhim Nagar', 'Colonies & Villages', 28.4200, 76.9800, 0.5),
  GurugramLocation(
    'Rajendra Park',
    'Colonies & Villages',
    28.4160,
    76.9860,
    0.5,
  ),
  GurugramLocation('New Colony', 'Colonies & Villages', 28.4100, 76.9920, 0.5),
  GurugramLocation(
    'Krishna Colony',
    'Colonies & Villages',
    28.4050,
    76.9980,
    0.5,
  ),
  GurugramLocation(
    'Saraswati Vihar',
    'Colonies & Villages',
    28.4000,
    77.0040,
    0.5,
  ),
  GurugramLocation(
    'Vishal Enclave',
    'Colonies & Villages',
    28.3950,
    77.0100,
    0.5,
  ),

  // ---- Industrial areas
  GurugramLocation('Udyog Vihar Phase 1', 'Industrial', 28.4980, 77.0780, 0.5),
  GurugramLocation('Udyog Vihar Phase 4', 'Industrial', 28.5010, 77.0730, 0.6),
  GurugramLocation('IMT Manesar', 'Industrial', 28.3580, 76.9380, 0.6),
  GurugramLocation(
    'Bawal Industrial Area',
    'Industrial',
    28.1100,
    76.7100,
    0.5,
  ),
];

/// Find a location by name (fuzzy: case-insensitive contains)
GurugramLocation? findLocation(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  for (final loc in gurugramLocations) {
    if (loc.name.toLowerCase().contains(q)) return loc;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Weather helpers
// ---------------------------------------------------------------------------

// Public endpoint is configurable per build; secrets are never committed to the client.
const String nalanetraBackendBaseUrl = String.fromEnvironment(
  'NALANETRA_BACKEND_BASE_URL',
  defaultValue: 'https://floodgrid-mexkc7wa.manus.space',
);
const String openWeatherApiKey = String.fromEnvironment(
  'OPENWEATHER_API_KEY',
  defaultValue: '',
);

const String groqApiKey = String.fromEnvironment(
  'GROQ_API_KEY',
  defaultValue: '',
);
