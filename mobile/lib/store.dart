import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'config.dart';
import 'citizen_auth_service.dart';
import 'staff_auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Data model: one report == one citizen sighting of a flooded location
// ---------------------------------------------------------------------------

class FloodReport {
  final String id;
  final double lat;
  final double lon;
  final String locationName;
  final String? photoPath;
  final String severitySummary;
  final SeverityBand band;
  final double severityScore; // 0-1 from AI
  final double rainfallScore; // 0-1 from rainfall context
  final double criticality; // 0-1 (hospital/school zone)
  final DateTime at;
  final String reporterName;
  final String incidentId; // merged incident id
  String? beforePhotoPath; // crew closure proof
  String? afterPhotoPath; // crew closure proof
  bool isSynced;

  FloodReport({
    required this.id,
    required this.lat,
    required this.lon,
    required this.locationName,
    this.photoPath,
    required this.severitySummary,
    required this.band,
    required this.severityScore,
    required this.rainfallScore,
    required this.criticality,
    required this.at,
    required this.reporterName,
    required this.incidentId,
    this.beforePhotoPath,
    this.afterPhotoPath,
    this.isSynced = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lon': lon,
    'locationName': locationName,
    'photoPath': photoPath,
    'severitySummary': severitySummary,
    'band': band.name,
    'severityScore': severityScore,
    'rainfallScore': rainfallScore,
    'criticality': criticality,
    'at': at.toIso8601String(),
    'reporterName': reporterName,
    'incidentId': incidentId,
    'beforePhotoPath': beforePhotoPath,
    'afterPhotoPath': afterPhotoPath,
    'isSynced': isSynced,
  };

  factory FloodReport.fromJson(Map<String, dynamic> json) => FloodReport(
    id: json['id'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    locationName: json['locationName'] as String,
    photoPath: json['photoPath'] as String?,
    severitySummary: json['severitySummary'] as String? ?? '',
    band: SeverityBand.values.firstWhere(
      (b) => b.name == json['band'],
      orElse: () => SeverityBand.moderate,
    ),
    severityScore: (json['severityScore'] as num?)?.toDouble() ?? 0.5,
    rainfallScore: (json['rainfallScore'] as num?)?.toDouble() ?? 0.5,
    criticality: (json['criticality'] as num?)?.toDouble() ?? 0.5,
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    reporterName: json['reporterName'] as String? ?? 'Citizen',
    incidentId: json['incidentId'] as String? ?? 'INC-001',
    beforePhotoPath: json['beforePhotoPath'] as String?,
    afterPhotoPath: json['afterPhotoPath'] as String?,
    isSynced: (json['isSynced'] as bool?) ?? true,
  );

  double priorityScore(List<FloodReport> allReports) {
    // P = 0.30S + 0.20R + 0.15C + 0.15D + 0.10T + 0.10A
    final duplicates = allReports
        .where((r) => r.incidentId == incidentId)
        .length;
    final accumulation = (duplicates / 15).clamp(
      0.0,
      1.0,
    ); // A (Max 15 reports for 1.0)

    // Time since first report in hours (max 12h for demo intensity)
    final firstReport = allReports
        .where((r) => r.incidentId == incidentId)
        .map((r) => r.at)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final hoursSince = DateTime.now().difference(firstReport).inMinutes / 60.0;
    final escalationTime = (hoursSince / 12.0).clamp(0.0, 1.0); // T

    // Mock population density based on location name or distance
    final popDensity =
        locationName.contains('NH-48') || locationName.contains('Sector 14')
        ? 0.95
        : 0.6; // D

    return (0.30 * severityScore) +
        (0.20 * rainfallScore) +
        (0.15 * criticality) +
        (0.15 * popDensity) +
        (0.10 * escalationTime) +
        (0.10 * accumulation);
  }
}

enum NotifKind {
  weather,
  emergency,
  merge,
  assignment,
  escalation,
  rejected,
  info,
  verified,
  crewAssigned,
}

enum NotifAudience { citizen, municipal, crew }

class Notif {
  final NotifKind kind;
  final String titleEn;
  final String titleHi;
  final String? incidentId;
  final String? assignmentIncidentId;
  final String? imagePath; // Incoming flood or field image
  final String? beforeImagePath; // Explicit before proof, when available
  final String? afterImagePath; // Explicit crew after proof, never synthesized
  final String? municipalImagePath;
  final String? locationName;
  final String? reporterName;
  final int? reportCount;
  final SeverityBand? severityBand;
  final double? severityScore;
  final Set<NotifAudience> audiences;
  final DateTime at;
  Notif({
    required this.kind,
    required this.titleEn,
    required this.titleHi,
    this.incidentId,
    this.assignmentIncidentId,
    this.imagePath,
    this.beforeImagePath,
    this.afterImagePath,
    this.municipalImagePath,
    this.locationName,
    this.reporterName,
    this.reportCount,
    this.severityBand,
    this.severityScore,
    this.audiences = const {
      NotifAudience.citizen,
      NotifAudience.municipal,
      NotifAudience.crew,
    },
    DateTime? at,
  }) : at = at ?? DateTime.now();

  String? imageFor(NotifAudience audience) =>
      audience == NotifAudience.municipal
      ? (municipalImagePath ?? imagePath)
      : imagePath;
}

class WeatherObservation {
  final GurugramLocation location;
  final String condition;
  final String description;
  final double temperatureC;
  final double rainMmPerHour;
  final double windSpeedMs;
  final DateTime observedAt;

  const WeatherObservation({
    required this.location,
    required this.condition,
    required this.description,
    required this.temperatureC,
    required this.rainMmPerHour,
    required this.windSpeedMs,
    required this.observedAt,
  });

  bool get isRaining =>
      rainMmPerHour > 0 || condition.toLowerCase().contains('rain');
}

class CrewMember {
  final String id;
  final String name;
  final String role;
  final String ward;
  final String contactNumber;
  final String currentLocation;
  final int shiftStartedMinutesAgo;
  final int etaMinutes;
  final String? avatarPath;
  final bool offDuty;

  const CrewMember({
    required this.id,
    required this.name,
    required this.role,
    required this.ward,
    required this.currentLocation,
    required this.shiftStartedMinutesAgo,
    required this.etaMinutes,
    this.contactNumber = '18001801817',
    this.avatarPath,
    this.offDuty = false,
  });
}

class AppStore extends ChangeNotifier {
  AppLang lang = AppLang.en;
  AppThemeMode themeMode = AppThemeMode.light;
  Portal? portal;
  String userName = 'Guest User';
  String userId = 'GUEST-001';
  String pendingOtp = '';
  CitizenAuthSession? citizenSession;
  CitizenChallenge? pendingCitizenChallenge;
  StaffAuthSession? staffSession;
  StaffChallenge? pendingStaffChallenge;
  String pendingStaffEmail = '';
  String pendingStaffId = '';
  bool citizenAuthReady = false;
  bool authReady = false;
  bool citizenAuthBusy = false;
  String? citizenAuthError;

  bool get isAuthenticated =>
      citizenSession != null || staffSession != null || portal == Portal.admin;

  List<FloodReport> reports = [];
  int startTab = 0;
  List<CrewJob> jobs = [];
  List<Notif> notifications = [];
  List<WeatherObservation> weatherObservations = [];
  bool weatherStationsLoading = false;
  String? weatherStationsError;
  DateTime? weatherStationsUpdatedAt;
  List<ResourceItemData> resources = [];

  static const String mcgHelpline = '18001801817';
  // Demo roster identities are operational placeholders, not real private staff records.
  // Contact actions route to the official MCG control room; no personal numbers are invented.
  static const crewRoster = <CrewMember>[
    CrewMember(
      id: 'Crew-07',
      name: 'Rakesh Kumar',
      avatarPath: 'assets/crew_avatars/crew_01_rakesh.jpg',
      role: 'Drainage Response',
      ward: 'Ward 14',
      currentLocation: 'Sector 14 Underpass',
      shiftStartedMinutesAgo: 42,
      etaMinutes: 18,
    ),
    CrewMember(
      id: 'Crew-12',
      name: 'Mohit Yadav',
      avatarPath: 'assets/crew_avatars/crew_02_mohit.jpg',
      role: 'Pump Operations',
      ward: 'Ward 12',
      currentLocation: 'NH-48 Narsinghpur',
      shiftStartedMinutesAgo: 64,
      etaMinutes: 12,
    ),
    CrewMember(
      id: 'Crew-03',
      name: 'Arun Singh',
      avatarPath: 'assets/crew_avatars/crew_03_arun.jpg',
      role: 'Health Corridor',
      ward: 'Ward 13',
      currentLocation: 'Civil Hospital Road',
      shiftStartedMinutesAgo: 58,
      etaMinutes: 10,
    ),
    CrewMember(
      id: 'Crew-04',
      name: 'Deepak Verma',
      avatarPath: 'assets/crew_avatars/crew_04_deepak.jpg',
      role: 'Drainage Response',
      ward: 'Ward 15',
      currentLocation: 'Palam Vihar Main Drain',
      shiftStartedMinutesAgo: 83,
      etaMinutes: 24,
    ),
    CrewMember(
      id: 'Crew-09',
      name: 'Sanjay Meena',
      avatarPath: 'assets/crew_avatars/crew_05_sanjay.jpg',
      role: 'Road Maintenance',
      ward: 'Ward 14',
      currentLocation: 'DLF Phase 3 Metro',
      shiftStartedMinutesAgo: 112,
      etaMinutes: 20,
    ),
    CrewMember(
      id: 'Crew-15',
      name: 'Vijay Rawat',
      avatarPath: 'assets/crew_avatars/crew_06_vijay.jpg',
      role: 'Traffic & Rescue',
      ward: 'Ward 12',
      currentLocation: 'Huda City Centre',
      shiftStartedMinutesAgo: 136,
      etaMinutes: 15,
    ),
    CrewMember(
      id: 'Crew-18',
      name: 'Amit Dahiya',
      avatarPath: 'assets/crew_avatars/crew_07_amit.jpg',
      role: 'Desilting Unit',
      ward: 'Ward 16',
      currentLocation: 'Sector 57 Market',
      shiftStartedMinutesAgo: 28,
      etaMinutes: 30,
    ),
    CrewMember(
      id: 'Crew-21',
      name: 'Naveen Kumar',
      avatarPath: 'assets/crew_avatars/crew_08_naveen.jpg',
      role: 'Emergency Support',
      ward: 'Ward 11',
      currentLocation: 'MCG Base — Sector 10',
      shiftStartedMinutesAgo: 0,
      etaMinutes: 0,
      offDuty: true,
    ),
    CrewMember(
      id: 'Crew-22',
      name: 'Pankaj Saini',
      avatarPath: 'assets/crew_avatars/crew_09_pankaj.jpg',
      role: 'Drainage Response',
      ward: 'Ward 10',
      currentLocation: 'Sector 15 Market',
      shiftStartedMinutesAgo: 36,
      etaMinutes: 16,
    ),
    CrewMember(
      id: 'Crew-23',
      name: 'Vikas Malik',
      avatarPath: 'assets/crew_avatars/crew_10_vikas.jpg',
      role: 'Pump Operations',
      ward: 'Ward 18',
      currentLocation: 'Sector 29 Market',
      shiftStartedMinutesAgo: 31,
      etaMinutes: 22,
    ),
    CrewMember(
      id: 'Crew-24',
      name: 'Harish Sharma',
      avatarPath: 'assets/crew_avatars/crew_11_harish.jpg',
      role: 'Road Maintenance',
      ward: 'Ward 17',
      currentLocation: 'Sector 31 Service Road',
      shiftStartedMinutesAgo: 49,
      etaMinutes: 26,
    ),
    CrewMember(
      id: 'Crew-25',
      name: 'Rajesh Choudhary',
      avatarPath: 'assets/crew_avatars/crew_12_rajesh.jpg',
      role: 'Traffic & Rescue',
      ward: 'Ward 19',
      currentLocation: 'Sector 38 Chowk',
      shiftStartedMinutesAgo: 55,
      etaMinutes: 14,
    ),
    CrewMember(
      id: 'Crew-26',
      name: 'Manoj Kumar',
      avatarPath: 'assets/crew_avatars/crew_13_manoj.jpg',
      role: 'Drainage Response',
      ward: 'Ward 20',
      currentLocation: 'Sector 40 Local Road',
      shiftStartedMinutesAgo: 19,
      etaMinutes: 17,
    ),
    CrewMember(
      id: 'Crew-27',
      name: 'Gaurav Bansal',
      avatarPath: 'assets/crew_avatars/crew_14_gaurav.jpg',
      role: 'Desilting Unit',
      ward: 'Ward 21',
      currentLocation: 'Sector 44 NH-48 Underpass',
      shiftStartedMinutesAgo: 27,
      etaMinutes: 35,
    ),
    CrewMember(
      id: 'Crew-28',
      name: 'Sunil Fauji',
      avatarPath: 'assets/crew_avatars/crew_15_sunil.jpg',
      role: 'Pump Operations',
      ward: 'Ward 22',
      currentLocation: 'Sector 46 Subhash Chowk',
      shiftStartedMinutesAgo: 74,
      etaMinutes: 19,
    ),
    CrewMember(
      id: 'Crew-29',
      name: 'Karan Ahlawat',
      avatarPath: 'assets/crew_avatars/crew_16_karan.jpg',
      role: 'Emergency Support',
      ward: 'Ward 23',
      currentLocation: 'Sector 49 Sohna Road',
      shiftStartedMinutesAgo: 44,
      etaMinutes: 21,
    ),
    CrewMember(
      id: 'Crew-30',
      name: 'Ashok Kumar',
      avatarPath: 'assets/crew_avatars/crew_17_ashok.jpg',
      role: 'Road Maintenance',
      ward: 'Ward 24',
      currentLocation: 'Sector 56 Badshahpur Road',
      shiftStartedMinutesAgo: 68,
      etaMinutes: 28,
    ),
    CrewMember(
      id: 'Crew-31',
      name: 'Devendra Pal',
      avatarPath: 'assets/crew_avatars/crew_18_devendra.jpg',
      role: 'Drainage Response',
      ward: 'Ward 25',
      currentLocation: 'Sector 57 Low-Lying Area',
      shiftStartedMinutesAgo: 23,
      etaMinutes: 13,
    ),
    CrewMember(
      id: 'Crew-32',
      name: 'Nitin Hooda',
      avatarPath: 'assets/crew_avatars/crew_19_nitin.jpg',
      role: 'Traffic & Rescue',
      ward: 'Ward 26',
      currentLocation: 'MG Road Underpass',
      shiftStartedMinutesAgo: 39,
      etaMinutes: 11,
    ),
    CrewMember(
      id: 'Crew-33',
      name: 'Lokesh Rana',
      avatarPath: 'assets/crew_avatars/crew_20_lokesh.jpg',
      role: 'Health Corridor',
      ward: 'Ward 27',
      currentLocation: 'Civil Hospital Route',
      shiftStartedMinutesAgo: 51,
      etaMinutes: 9,
    ),
    CrewMember(
      id: 'Crew-34',
      name: 'Suresh Tanwar',
      avatarPath: 'assets/crew_avatars/crew_21_suresh.jpg',
      role: 'Desilting Unit',
      ward: 'Ward 28',
      currentLocation: 'DLF Phase 1 Access Road',
      shiftStartedMinutesAgo: 46,
      etaMinutes: 25,
    ),
    CrewMember(
      id: 'Crew-35',
      name: 'Ravi Bishnoi',
      avatarPath: 'assets/crew_avatars/crew_22_ravi.jpg',
      role: 'Pump Operations',
      ward: 'Ward 29',
      currentLocation: 'DLF Phase 2 Underpass',
      shiftStartedMinutesAgo: 61,
      etaMinutes: 18,
    ),
    CrewMember(
      id: 'Crew-36',
      name: 'Jitender Singh',
      avatarPath: 'assets/crew_avatars/crew_23_jitender.jpg',
      role: 'Drainage Response',
      ward: 'Ward 30',
      currentLocation: 'DLF Phase 4 Service Road',
      shiftStartedMinutesAgo: 33,
      etaMinutes: 20,
    ),
    CrewMember(
      id: 'Crew-37',
      name: 'Tarun Yadav',
      avatarPath: 'assets/crew_avatars/crew_24_tarun.jpg',
      role: 'Road Maintenance',
      ward: 'Ward 31',
      currentLocation: 'Palam Vihar Main Drain',
      shiftStartedMinutesAgo: 25,
      etaMinutes: 23,
    ),
    CrewMember(
      id: 'Crew-38',
      name: 'Vishal Kumar',
      avatarPath: 'assets/crew_avatars/crew_25_vishal.jpg',
      role: 'Emergency Support',
      ward: 'Ward 32',
      currentLocation: 'MCG Base — Sector 10',
      shiftStartedMinutesAgo: 0,
      etaMinutes: 0,
      offDuty: true,
    ),
  ];
  static final weatherStationLocations = <GurugramLocation>[
    gurugramLocations[0],
    gurugramLocations[11],
    gurugramLocations[14],
    gurugramLocations[32],
    gurugramLocations[36],
    gurugramLocations[38],
    gurugramLocations[44],
    gurugramLocations[47],
    gurugramLocations[55],
    gurugramLocations[57],
    gurugramLocations[74],
    gurugramLocations[77],
  ];
  List<BroadcastMessage> broadcasts = [];
  final Set<String> verifiedIncidents = {};
  final Set<String> dispatchedIncidents = {};
  final Map<String, String> rejectedReasons = {};
  final Map<String, String> incidentCrew = {};

  // User-provided India/Gurugram-context flood evidence photos.
  // Sector labels are demo-data mappings, not verified photo geotags.
  static const municipalNotificationImages = <String>[
    'assets/user_municipal_notifications/alert_01_sector40_flood.jpg',
    'assets/user_municipal_notifications/alert_02_aria_mall_corridor.jpg',
    'assets/user_municipal_notifications/alert_03_sector54_flood.jpg',
    'assets/user_municipal_notifications/alert_04_nh48_underpass.webp',
    'assets/user_municipal_notifications/alert_05_sector40_road.jpg',
    'assets/user_municipal_notifications/alert_06_civil_hospital_corridor.jpg',
    'assets/user_municipal_notifications/alert_07_palam_vihar_lane.jpg',
    'assets/user_municipal_notifications/alert_08_sector14_corridor.jpg',
    'assets/user_municipal_notifications/alert_09_sector54_parking.jpg',
    'assets/user_municipal_notifications/alert_10_sector56_parking.jpg',
  ];

  static const heatmapLiveFeedImages = <String>[
    'assets/user_heatmap_live_feed/photo_01_4228.jpg',
    'assets/user_heatmap_live_feed/photo_02_4227.jpg',
    'assets/user_heatmap_live_feed/photo_03_4226.jpg',
    'assets/user_heatmap_live_feed/photo_04_4225.jpg',
    'assets/user_heatmap_live_feed/photo_05_4224.webp',
    'assets/user_heatmap_live_feed/photo_06_4223.jpg',
    'assets/user_heatmap_live_feed/photo_07_4222.jpg',
    'assets/user_heatmap_live_feed/photo_08_3917.jpg',
    'assets/user_heatmap_live_feed/photo_09_3916.jpg',
    'assets/user_heatmap_live_feed/photo_10_3915.jpg',
    'assets/user_heatmap_live_feed/photo_11_3914.jpg',
    'assets/user_heatmap_live_feed/photo_12_3913.jpg',
    'assets/user_heatmap_live_feed/photo_13_3912.jpg',
    'assets/user_heatmap_live_feed/photo_14_3911.jpg',
    'assets/user_heatmap_live_feed/photo_15_3910.webp',
    'assets/user_heatmap_live_feed/photo_16_3909.jpg',
    'assets/user_heatmap_live_feed/photo_17_3906.png',
    'assets/user_heatmap_live_feed/photo_18_3905.jpg',
    'assets/user_heatmap_live_feed/photo_19_3903.jpg',
    'assets/user_heatmap_live_feed/photo_20_3904.jpg',
  ];

  static const dispatchFloodImages = <String>[
    'assets/user_dispatch_floods/dispatch_01_sector14_underpass.jpg',
    'assets/user_dispatch_floods/dispatch_02_civil_hospital.jpg',
    'assets/user_dispatch_floods/dispatch_03_nh48.jpg',
    'assets/user_dispatch_floods/dispatch_04_huda_city.jpg',
    'assets/user_dispatch_floods/dispatch_05_palam_drain.jpg',
  ];

  static const pendingVerifyPreviewImages = <String>[
    'assets/user_verify_previews/verify_01_nh48_flood.jpg',
    'assets/user_verify_previews/verify_02_civil_hospital_flood.jpg',
    'assets/user_verify_previews/verify_03_palam_flood.png',
    'assets/user_verify_previews/verify_04_dlf_flood.webp',
    'assets/user_verify_previews/verify_05_huda_flood.png',
  ];

  static const demoFloodImages = <String>[
    'assets/user_flood_incidents/01_user_flood_upload.jpg',
    'assets/user_flood_incidents/02_user_flood_upload.jpg',
    'assets/user_flood_incidents/03_user_flood_upload.jpg',
    'assets/user_flood_incidents/04_user_flood_upload.jpg',
    'assets/user_flood_incidents/05_user_flood_upload.jpg',
    'assets/user_flood_incidents/06_user_flood_upload.jpg',
    'assets/user_flood_incidents/07_user_flood_upload.jpg',
    'assets/user_flood_incidents/08_user_flood_upload.jpg',
    'assets/user_flood_incidents/09_user_flood_upload.jpg',
    'assets/user_flood_incidents/10_user_flood_upload.jpg',
    'assets/user_flood_incidents/11_user_flood_upload.jpg',
    'assets/user_flood_incidents/12_user_flood_upload.jpg',
    'assets/user_flood_incidents/13_user_flood_upload.jpg',
    'assets/user_flood_incidents/14_user_flood_upload.jpg',
    'assets/user_flood_incidents/15_user_flood_upload.jpg',
  ];
  List<double> responseEfficiency = [68, 71, 69, 78, 75, 84, 81];
  List<int> incidentVolumeTrend = [5, 7, 6, 9, 8, 11, 10];
  DateTime analyticsUpdatedAt = DateTime.now();
  int liveTick = 0;
  Timer? _liveTimer;
  Timer? _weatherTimer;
  bool _disposed = false;
  GurugramLocation selectedLocation = gurugramLocations[11]; // Sector 14

  AppStore({bool enableLiveUpdates = true}) {
    seedDemoData();
    // Defer platform plugins and network work until after construction so the
    // Flutter engine can render its first frame safely on OEM Android builds.
    if (enableLiveUpdates) {
      Future<void>.delayed(Duration.zero, () {
        if (_disposed) return;
        _restoreAuthSessions();
        _restoreOfflineReports();
        if (_disposed) return;
        _startLiveSimulation();
        fetchWeather();
      });
    }
  }

  // Weather state
  String weatherMain = 'Unavailable';
  double weatherTemp = 0;
  double rainRate = 0;
  String weatherDescEn = 'Live weather is not available yet. Tap Retry.';
  String weatherDescHi = 'लाइव मौसम अभी उपलब्ध नहीं है। Retry दबाएं।';
  bool weatherReady = false;
  bool weatherLoading = false;
  bool weatherUsingStationFallback = false;
  DateTime? weatherLastAttemptAt;
  DateTime? weatherLastUpdatedAt;
  String? weatherError;
  bool backendChecking = false;
  bool backendReachable = false;
  String backendStatus = 'Not checked';

  String get backendHealthUrl => '$nalanetraBackendBaseUrl/';

  Future<void> checkBackendConnection() async {
    if (backendChecking) return;
    backendChecking = true;
    backendStatus = 'Checking';
    notifyListeners();
    try {
      final response = await http
          .get(Uri.parse(backendHealthUrl))
          .timeout(const Duration(seconds: 8));
      backendReachable = response.statusCode < 500;
      backendStatus = backendReachable
          ? 'Connected (${response.statusCode})'
          : 'Unavailable (${response.statusCode})';
    } catch (_) {
      backendReachable = false;
      backendStatus = 'Unavailable';
    } finally {
      backendChecking = false;
      notifyListeners();
    }
  }

  Future<void> fetchWeather() async {
    if (_disposed || weatherLoading) return;
    weatherLoading = true;
    weatherLastAttemptAt = DateTime.now();
    weatherError = null;
    notifyListeners();
    try {
      final observation = await _fetchObservationWithRetry(selectedLocation);
      _applyWeatherObservation(observation, usingFallback: false);
      weatherStationsError = null;
    } catch (e) {
      if (_disposed) return;
      final fallback = _nearestWeatherObservation();
      if (fallback != null) {
        _applyWeatherObservation(fallback, usingFallback: true);
        weatherError = '${_weatherErrorText(e)} Showing nearest station data.';
      } else {
        weatherReady = false;
        weatherUsingStationFallback = false;
        weatherError = _weatherErrorText(e);
      }
      debugPrint('Weather fetch error: $e');
    } finally {
      if (_disposed) return;
      weatherLoading = false;
      notifyListeners();
    }
  }

  Future<WeatherObservation> _fetchObservationWithRetry(
    GurugramLocation location, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _fetchObservation(location);
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    throw lastError ?? Exception('OpenWeather request failed');
  }

  Future<WeatherObservation> _fetchObservation(
    GurugramLocation location,
  ) async {
    if (openWeatherApiKey.trim().isEmpty) {
      throw Exception('OpenWeather API key missing at build time');
    }
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?lat=${location.lat}&lon=${location.lon}'
      '&appid=${Uri.encodeQueryComponent(openWeatherApiKey)}&units=metric',
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('OpenWeather HTTP ${resp.statusCode}');
    }
    final decoded = json.decode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('OpenWeather returned an invalid response');
    }
    final weatherList = decoded['weather'];
    final main = decoded['main'];
    if (weatherList is! List || weatherList.isEmpty || main is! Map) {
      throw Exception('OpenWeather response is missing weather fields');
    }
    final weather = weatherList.first;
    final rain = decoded['rain'];
    final wind = decoded['wind'];
    if (weather is! Map) {
      throw Exception('OpenWeather response is missing condition fields');
    }
    final rainMm = rain is Map
        ? ((rain['1h'] as num?)?.toDouble() ??
              (((rain['3h'] as num?)?.toDouble() ?? 0.0) / 3.0))
        : 0.0;
    final observedEpoch = (decoded['dt'] as num?)?.toInt();
    final observedAt = observedEpoch == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(
            observedEpoch * 1000,
            isUtc: true,
          ).toLocal();
    return WeatherObservation(
      location: location,
      condition: (weather['main'] as String?) ?? 'Unknown',
      description: (weather['description'] as String?) ?? 'Current conditions',
      temperatureC: (main['temp'] as num?)?.toDouble() ?? 0.0,
      rainMmPerHour: rainMm,
      windSpeedMs: wind is Map
          ? (wind['speed'] as num?)?.toDouble() ?? 0.0
          : 0.0,
      observedAt: observedAt,
    );
  }

  void _applyWeatherObservation(
    WeatherObservation observation, {
    required bool usingFallback,
  }) {
    weatherMain = observation.condition;
    weatherTemp = observation.temperatureC;
    rainRate = observation.rainMmPerHour;
    weatherReady = true;
    weatherUsingStationFallback = usingFallback;
    weatherLastUpdatedAt = observation.observedAt;
    final label = observation.location.name.split('—').first.trim();
    weatherDescEn = '${observation.description} in $label';
    weatherDescHi = '$label में ${observation.description}';
  }

  WeatherObservation? _nearestWeatherObservation([
    List<WeatherObservation>? observations,
  ]) {
    final source = observations ?? weatherObservations;
    if (source.isEmpty) return null;
    final sorted = [...source]
      ..sort((a, b) {
        final aDistance = _distanceSquared(a.location, selectedLocation);
        final bDistance = _distanceSquared(b.location, selectedLocation);
        return aDistance.compareTo(bDistance);
      });
    return sorted.first;
  }

  double _distanceSquared(GurugramLocation a, GurugramLocation b) {
    final latDelta = a.lat - b.lat;
    final lonDelta = a.lon - b.lon;
    return (latDelta * latDelta) + (lonDelta * lonDelta);
  }

  String _weatherErrorText(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.contains('API key missing')) {
      return 'OpenWeather key missing in this build. Rebuild with OPENWEATHER_API_KEY.';
    }
    if (message.contains('HTTP 401')) {
      return 'OpenWeather rejected the key (401). Check the build-time key.';
    }
    if (message.contains('HTTP 429')) {
      return 'OpenWeather rate limit reached. Tap Retry in a moment.';
    }
    if (message.contains('TimeoutException') || message.contains('timed out')) {
      return 'OpenWeather timed out. Tap Retry.';
    }
    return 'OpenWeather unavailable. Tap Retry.';
  }

  Future<void> refreshWeatherStations() async {
    if (_disposed || weatherStationsLoading) return;
    weatherStationsLoading = true;
    weatherLastAttemptAt = DateTime.now();
    weatherStationsError = null;
    weatherError = null;
    notifyListeners();
    final stationLocations = weatherStationLocations;
    var failedStations = 0;
    Object? lastError;
    try {
      final fetched = await Future.wait(
        stationLocations.map((location) async {
          try {
            return await _fetchObservationWithRetry(location, maxAttempts: 2);
          } catch (e) {
            failedStations++;
            lastError = e;
            debugPrint('Weather station ${location.name} failed: $e');
            return null;
          }
        }),
      );
      final results = fetched.whereType<WeatherObservation>().toList();
      if (results.isEmpty) {
        final failure =
            lastError ?? Exception('No weather stations returned data');
        throw failure;
      }
      weatherObservations = results;
      weatherStationsUpdatedAt = DateTime.now();
      final selected = results
          .where((item) => item.location.name == selectedLocation.name)
          .firstOrNull;
      final effective = selected ?? _nearestWeatherObservation(results);
      if (effective != null) {
        _applyWeatherObservation(effective, usingFallback: selected == null);
      }
      if (selected == null) {
        weatherStationsError =
            'Selected location unavailable; showing nearest station data.';
        weatherError = weatherStationsError;
      } else if (failedStations > 0) {
        weatherStationsError =
            '$failedStations station(s) failed; showing available readings.';
      }
    } catch (e) {
      if (_disposed) return;
      // Preserve the last successful observation and timestamp. The UI will
      // show that the reading is stale and offer Retry rather than going blank.
      weatherStationsError = _weatherErrorText(e);
      weatherError = weatherStationsError;
      debugPrint('Weather stations error: $e');
    } finally {
      if (_disposed) return;
      weatherStationsLoading = false;
      notifyListeners();
    }
  }

  void _startLiveSimulation() {
    _refreshAnalyticsSnapshot(notify: false);
    refreshWeatherStations();
    _weatherTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      refreshWeatherStations();
    });
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      advanceResourceUsage();
      _simulateDynamicAlert();
      await fetchWeather();
      _refreshAnalyticsSnapshot();
    });
  }

  /// Advances operational resource usage for the Inventory tab. Each item has
  /// a demo-safe step so the dashboard visibly changes during a presentation;
  /// once the item reaches full capacity, the next tick represents a fresh
  /// deployment cycle and resets its active count to zero.
  void advanceResourceUsage() {
    if (_disposed) return;
    for (final resource in resources) {
      resource.advanceUsage();
    }
    notifyListeners();
  }

  String imageForIncident(String incidentId, {int salt = 0}) {
    final hash = incidentId.codeUnits.fold<int>(
      salt,
      (value, unit) => value + unit,
    );
    return demoFloodImages[hash.abs() % demoFloodImages.length];
  }

  void _refreshAnalyticsSnapshot({bool notify = true}) {
    final total = reports.length;
    final active = reports
        .where((r) => statusOf(r.incidentId) != IncidentLifecycle.verified)
        .length;
    final verified = total - active;
    final closureRatio = total == 0 ? 0.0 : verified / total;
    final queuePressure = total == 0 ? 0.0 : active / total;
    final rainPenalty = rainRate.clamp(0.0, 8.0).toDouble() * 1.15;
    final efficiency =
        (64.0 +
                closureRatio * 22.0 -
                queuePressure * 7.0 -
                rainPenalty +
                (liveTick % 5) * 0.7)
            .clamp(35.0, 98.0)
            .toDouble();

    responseEfficiency = [...responseEfficiency.skip(1), efficiency];
    incidentVolumeTrend = [...incidentVolumeTrend.skip(1), total];
    analyticsUpdatedAt = DateTime.now();
    liveTick++;
    if (notify) notifyListeners();
  }

  String get analyticsSyncLabel =>
      '${analyticsUpdatedAt.hour.toString().padLeft(2, '0')}:${analyticsUpdatedAt.minute.toString().padLeft(2, '0')}:${analyticsUpdatedAt.second.toString().padLeft(2, '0')}';

  void _simulateDynamicAlert() {
    final now = DateTime.now();
    final evidenceReports = reports
        .where((report) => report.photoPath?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (evidenceReports.isEmpty) return;
    final report = evidenceReports[now.second % evidenceReports.length];
    final locationLabel = report.locationName.split('—').first.trim();
    final newNotif = Notif(
      kind: NotifKind.emergency,
      incidentId: report.incidentId,
      assignmentIncidentId: report.incidentId,
      titleEn: 'Alert: Rising water levels at $locationLabel',
      titleHi: 'अलर्ट: $locationLabel में जल स्तर बढ़ रहा है',
      imagePath: report.photoPath,
      municipalImagePath:
          municipalNotificationImages[now.second %
              municipalNotificationImages.length],
      locationName: report.locationName,
      severityBand: report.band,
      severityScore: report.severityScore,
      reporterName: report.reporterName,
      reportCount: reports
          .where((item) => item.incidentId == report.incidentId)
          .length,
      audiences: const {NotifAudience.municipal},
      at: now,
    );
    addNotification(newNotif);
  }

  void seedDemoData() {
    resources = [
      ResourceItemData(
        id: 'R1',
        nameEn: 'High-Power Pumps',
        nameHi: 'हाई-पावर पंप',
        total: 12,
        active: 8,
        cycleStep: 2,
        deptEn: 'Drainage Wing',
        deptHi: 'ड्रेनेज विंग',
        icon: 'waves',
        color: 0xFF2196F3,
      ),
      ResourceItemData(
        id: 'R2',
        nameEn: 'Rescue Boats',
        nameHi: 'बचाव नौकाएं',
        total: 4,
        active: 2,
        cycleStep: 1,
        deptEn: 'NDRF Support',
        deptHi: 'NDRF सहायता',
        icon: 'sailing',
        color: 0xFFFF9800,
      ),
      ResourceItemData(
        id: 'R3',
        nameEn: 'Sandbags',
        nameHi: 'रेत की बोरियां',
        total: 2500,
        active: 1200,
        cycleStep: 450,
        deptEn: 'Civil Defense',
        deptHi: 'सिविल डिफेंस',
        icon: 'inventory_2',
        color: 0xFF795548,
      ),
      ResourceItemData(
        id: 'R4',
        nameEn: 'Emergency Vehicles',
        nameHi: 'आपातकालीन वाहन',
        total: 8,
        active: 6,
        cycleStep: 1,
        deptEn: 'Traffic Police',
        deptHi: 'ट्रैफिक पुलिस',
        icon: 'local_shipping',
        color: 0xFFF44336,
      ),
    ];

    broadcasts = [
      BroadcastMessage(
        id: 'B1',
        msgEn: 'Heavy rain expected in Sector 14 till 8 PM',
        msgHi: 'सेक्टर 14 में रात 8 बजे तक भारी बारिश की संभावना',
        target: 'Ward 12, 14',
        time: '10m ago',
      ),
      BroadcastMessage(
        id: 'B2',
        msgEn: 'Traffic diversion on NH-48 due to waterlogging',
        msgHi: 'जलभराव के कारण NH-48 पर यातायात डायवर्जन',
        target: 'All Gurugram',
        time: '45m ago',
      ),
    ];

    reports = [
      FloodReport(
        id: 'R-8291',
        lat: 28.4586,
        lon: 77.0294,
        locationName: 'Sector 14 Underpass',
        photoPath: demoFloodImages[0],
        severitySummary: 'Critical flooding, road blocked',
        band: SeverityBand.critical,
        severityScore: 0.92,
        rainfallScore: 0.9,
        criticality: 1.0,
        at: DateTime.now().subtract(const Duration(minutes: 4)),
        reporterName: 'Rahul K.',
        incidentId: 'INC-8291',
      ),
      FloodReport(
        id: 'R-7721',
        lat: 28.3843,
        lon: 76.9442,
        locationName: 'NH-48 Narsinghpur',
        photoPath: demoFloodImages[13],
        beforePhotoPath: demoFloodImages[13],
        afterPhotoPath: '',
        severitySummary: 'Severe waterlogging, heavy traffic',
        band: SeverityBand.severe,
        severityScore: 0.88,
        rainfallScore: 0.7,
        criticality: 0.8,
        at: DateTime.now().subtract(const Duration(minutes: 12)),
        reporterName: 'Priya S.',
        incidentId: 'INC-7721',
      ),
      FloodReport(
        id: 'R-1092',
        lat: 28.4200,
        lon: 77.0400,
        locationName: 'Civil Hospital Road',
        photoPath: demoFloodImages[14],
        beforePhotoPath: demoFloodImages[14],
        afterPhotoPath: '',
        severitySummary: 'Water entering premises, urgent',
        band: SeverityBand.critical,
        severityScore: 0.95,
        rainfallScore: 0.85,
        criticality: 1.0,
        at: DateTime.now().subtract(const Duration(minutes: 25)),
        reporterName: 'Dr. Mehta',
        incidentId: 'INC-1092',
      ),
      FloodReport(
        id: 'R-5521',
        lat: 28.4700,
        lon: 77.0100,
        locationName: 'Palam Vihar Main Drain',
        photoPath: demoFloodImages[3],
        beforePhotoPath: demoFloodImages[3],
        afterPhotoPath: '',
        severitySummary: 'Drain overflowing, nearby houses at risk',
        band: SeverityBand.severe,
        severityScore: 0.82,
        rainfallScore: 0.75,
        criticality: 0.7,
        at: DateTime.now().subtract(const Duration(minutes: 40)),
        reporterName: 'Vikram A.',
        incidentId: 'INC-5521',
      ),
      FloodReport(
        id: 'R-3341',
        lat: 28.4900,
        lon: 77.0900,
        locationName: 'DLF Phase 3 Metro Stn',
        photoPath: demoFloodImages[1],
        beforePhotoPath: demoFloodImages[1],
        afterPhotoPath: '',
        severitySummary: 'Knee deep water at entry',
        band: SeverityBand.moderate,
        severityScore: 0.65,
        rainfallScore: 0.6,
        criticality: 0.9,
        at: DateTime.now().subtract(const Duration(hours: 1)),
        reporterName: 'Anjali M.',
        incidentId: 'INC-3341',
      ),
      FloodReport(
        id: 'R-9901',
        lat: 28.4100,
        lon: 77.0300,
        locationName: 'Huda City Centre',
        photoPath: demoFloodImages[11],
        beforePhotoPath: demoFloodImages[11],
        afterPhotoPath: '',
        severitySummary: 'Metro entrance flooded',
        band: SeverityBand.severe,
        severityScore: 0.85,
        rainfallScore: 0.8,
        criticality: 0.9,
        at: DateTime.now().subtract(const Duration(hours: 2)),
        reporterName: 'Suresh P.',
        incidentId: 'INC-9901',
      ),
      FloodReport(
        id: 'R-2047',
        lat: 28.4300,
        lon: 77.0500,
        locationName: 'Sector 30 Hotspot',
        photoPath: demoFloodImages[8],
        beforePhotoPath: demoFloodImages[8],
        afterPhotoPath: '',
        severitySummary: 'Moderate waterlogging, drainage issues',
        band: SeverityBand.moderate,
        severityScore: 0.55,
        rainfallScore: 0.5,
        criticality: 0.6,
        at: DateTime.now().subtract(const Duration(hours: 3)),
        reporterName: 'Amit V.',
        incidentId: 'INC-2047',
      ),
    ];

    notifications = [
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Waterlogging alert — Sector 40 internal road',
        titleHi: 'जलभराव अलर्ट — सेक्टर 40 आंतरिक सड़क',
        location: 'Sector 40, Gurugram',
        assignmentIncidentId: 'INC-2047',
        image: municipalNotificationImages[0],
        band: SeverityBand.severe,
        score: 0.74,
        reporterName: 'Rahul K.',
        reportCount: 7,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Critical flood alert — Sector 54 Aria Mall corridor',
        titleHi: 'गंभीर बाढ़ अलर्ट — सेक्टर 54 आरिया मॉल कॉरिडोर',
        location: 'Sector 54, Gurugram',
        assignmentIncidentId: 'INC-3341',
        image: municipalNotificationImages[1],
        band: SeverityBand.critical,
        score: 0.88,
        reporterName: 'Priya S.',
        reportCount: 12,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Severe flood alert — Sector 54 Ward 12 service road',
        titleHi: 'गंभीर जलभराव अलर्ट — सेक्टर 54 वार्ड 12 सर्विस रोड',
        location: 'Sector 54 Ward 12, Gurugram',
        assignmentIncidentId: 'INC-3341',
        image: municipalNotificationImages[2],
        band: SeverityBand.severe,
        score: 0.82,
        reporterName: 'Amit V.',
        reportCount: 9,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Critical flood alert — NH-48 Narsinghpur underpass',
        titleHi: 'गंभीर बाढ़ अलर्ट — NH-48 नरसिंगपुर अंडरपास',
        location: 'NH-48 Narsinghpur, Gurugram',
        assignmentIncidentId: 'INC-7721',
        image: municipalNotificationImages[3],
        band: SeverityBand.critical,
        score: 0.96,
        reporterName: 'Mohit Y.',
        reportCount: 15,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Severe flood alert — Sector 40 / Golf Course Extension',
        titleHi: 'गंभीर जलभराव अलर्ट — सेक्टर 40 / गोल्फ कोर्स एक्सटेंशन',
        location: 'Sector 40, Gurugram',
        assignmentIncidentId: 'INC-2047',
        image: municipalNotificationImages[4],
        band: SeverityBand.severe,
        score: 0.78,
        reporterName: 'Neha R.',
        reportCount: 6,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Critical flood alert — Civil Hospital Road',
        titleHi: 'गंभीर बाढ़ अलर्ट — सिविल हॉस्पिटल रोड',
        location: 'Civil Hospital Road, Gurugram',
        assignmentIncidentId: 'INC-1092',
        image: municipalNotificationImages[5],
        band: SeverityBand.critical,
        score: 0.91,
        reporterName: 'Dr. Mehta',
        reportCount: 11,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Severe drain overflow — Palam Vihar Main Drain',
        titleHi: 'गंभीर नाला ओवरफ्लो — पालम विहार मुख्य नाला',
        location: 'Palam Vihar, Gurugram',
        assignmentIncidentId: 'INC-5521',
        image: municipalNotificationImages[6],
        band: SeverityBand.severe,
        score: 0.84,
        reporterName: 'Vikram A.',
        reportCount: 8,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Critical flood alert — Sector 14 Underpass',
        titleHi: 'गंभीर बाढ़ अलर्ट — सेक्टर 14 अंडरपास',
        location: 'Sector 14 Underpass, Gurugram',
        assignmentIncidentId: 'INC-8291',
        image: municipalNotificationImages[7],
        band: SeverityBand.critical,
        score: 0.95,
        reporterName: 'Suresh P.',
        reportCount: 14,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Severe basement flooding — Sector 54 parking',
        titleHi: 'गंभीर बेसमेंट जलभराव — सेक्टर 54 पार्किंग',
        location: 'Sector 54, Gurugram',
        assignmentIncidentId: 'INC-3341',
        image: municipalNotificationImages[8],
        band: SeverityBand.severe,
        score: 0.87,
        reporterName: 'Karan D.',
        reportCount: 10,
      ),
      _municipalFloodNotif(
        kind: NotifKind.emergency,
        titleEn: 'Critical flood alert — Sector 56 low-lying area',
        titleHi: 'गंभीर बाढ़ अलर्ट — सेक्टर 56 निचला क्षेत्र',
        location: 'Sector 56, Gurugram',
        assignmentIncidentId: 'INC-9901',
        image: municipalNotificationImages[9],
        band: SeverityBand.critical,
        score: 0.90,
        reporterName: 'Pooja S.',
        reportCount: 13,
      ),
    ];

    jobs = [
      CrewJob(
        incidentId: 'INC-8291',
        location: 'Sector 14 Underpass',
        lat: 28.4586,
        lon: 77.0294,
        priority: 92,
        severity: 92,
        reporters: 15,
        crewName: 'Crew-07',
        wing: 'Drainage',
        status: IncidentLifecycle.dispatched,
        dispatchedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        beforePhotoPath: demoFloodImages[0],
        afterPhotoPath: '',
      ),
      CrewJob(
        incidentId: 'INC-7721',
        location: 'NH-48 Narsinghpur',
        lat: 28.3843,
        lon: 76.9442,
        priority: 88,
        severity: 88,
        reporters: 8,
        crewName: 'Crew-12',
        wing: 'Water Supply',
        status: IncidentLifecycle.onSite,
        dispatchedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        beforePhotoPath: demoFloodImages[13],
        afterPhotoPath: '',
        pendingPreviewPath: pendingVerifyPreviewImages[0],
      ),
      CrewJob(
        incidentId: 'INC-1092',
        location: 'Civil Hospital Road',
        lat: 28.4200,
        lon: 77.0400,
        priority: 95,
        severity: 95,
        reporters: 5,
        crewName: 'Crew-03',
        wing: 'Health',
        status: IncidentLifecycle.onSite,
        dispatchedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        beforePhotoPath: demoFloodImages[14],
        afterPhotoPath: '',
        pendingPreviewPath: pendingVerifyPreviewImages[1],
      ),
      CrewJob(
        incidentId: 'INC-5521',
        location: 'Palam Vihar Main Drain',
        lat: 28.4700,
        lon: 77.0100,
        priority: 82,
        severity: 82,
        reporters: 3,
        crewName: 'Crew-04',
        wing: 'Drainage',
        status: IncidentLifecycle.onSite,
        dispatchedAt: DateTime.now().subtract(const Duration(minutes: 40)),
        beforePhotoPath: demoFloodImages[3],
        afterPhotoPath: '',
        pendingPreviewPath: pendingVerifyPreviewImages[2],
      ),
      CrewJob(
        incidentId: 'INC-3341',
        location: 'DLF Phase 3 Metro Stn',
        lat: 28.4900,
        lon: 77.0900,
        priority: 65,
        severity: 65,
        reporters: 12,
        crewName: 'Crew-09',
        wing: 'Maintenance',
        status: IncidentLifecycle.onSite,
        dispatchedAt: DateTime.now().subtract(const Duration(hours: 1)),
        beforePhotoPath: demoFloodImages[1],
        afterPhotoPath: '',
        pendingPreviewPath: pendingVerifyPreviewImages[3],
      ),
      CrewJob(
        incidentId: 'INC-9901',
        location: 'Huda City Centre',
        lat: 28.4100,
        lon: 77.0300,
        priority: 85,
        severity: 85,
        reporters: 20,
        crewName: 'Crew-15',
        wing: 'Water Supply',
        status: IncidentLifecycle.onSite,
        dispatchedAt: DateTime.now().subtract(const Duration(hours: 2)),
        beforePhotoPath: demoFloodImages[11],
        afterPhotoPath: '',
        pendingPreviewPath: pendingVerifyPreviewImages[4],
      ),
    ];

    notifyListeners();
  }

  Notif _municipalFloodNotif({
    required NotifKind kind,
    required String titleEn,
    required String titleHi,
    required String location,
    required String image,
    required SeverityBand band,
    required double score,
    String? incidentId,
    String? assignmentIncidentId,
    String? reporterName,
    int? reportCount,
  }) {
    return Notif(
      kind: kind,
      titleEn: titleEn,
      titleHi: titleHi,
      incidentId: incidentId,
      assignmentIncidentId: assignmentIncidentId,
      imagePath: image,
      municipalImagePath: image,
      locationName: location,
      reporterName: reporterName,
      reportCount: reportCount,
      severityBand: band,
      severityScore: score,
      audiences: const {NotifAudience.municipal},
    );
  }

  Notif _withSeedAudience(Notif notification) {
    final audiences = switch (notification.kind) {
      NotifKind.weather ||
      NotifKind.emergency ||
      NotifKind.merge ||
      NotifKind.escalation => const {NotifAudience.municipal},
      NotifKind.crewAssigned => const {
        NotifAudience.municipal,
        NotifAudience.crew,
      },
      NotifKind.verified => const {NotifAudience.municipal},
      NotifKind.rejected => const {
        NotifAudience.citizen,
        NotifAudience.municipal,
        NotifAudience.crew,
      },
      NotifKind.assignment => const {NotifAudience.crew},
      NotifKind.info =>
        notification.titleEn.startsWith('New citizen report')
            ? const {NotifAudience.citizen, NotifAudience.municipal}
            : const {NotifAudience.municipal},
    };
    return Notif(
      kind: notification.kind,
      titleEn: notification.titleEn,
      titleHi: notification.titleHi,
      incidentId: notification.incidentId,
      assignmentIncidentId: notification.assignmentIncidentId,
      imagePath: notification.imagePath,
      beforeImagePath: notification.beforeImagePath,
      afterImagePath: notification.afterImagePath,
      municipalImagePath: notification.municipalImagePath,
      locationName: notification.locationName,
      reporterName: notification.reporterName,
      reportCount: notification.reportCount,
      severityBand: notification.severityBand,
      severityScore: notification.severityScore,
      audiences: audiences,
      at: notification.at,
    );
  }

  String t(String en, String hi) => lang == AppLang.en ? en : hi;

  void setLang(AppLang l) {
    lang = l;
    notifyListeners();
  }

  void setTheme(AppThemeMode m) {
    themeMode = m;
    notifyListeners();
  }

  Future<void> _restoreAuthSessions() async {
    final restoredCitizen = await CitizenAuthService.restore();
    if (_disposed) return;
    final restoredOfficer = await StaffAuthService.restore(Portal.officer);
    if (_disposed) return;
    final restoredCrew = await StaffAuthService.restore(Portal.crew);
    if (_disposed) return;

    citizenSession = restoredCitizen;
    if (restoredCitizen != null) {
      userName = restoredCitizen.name;
      userId = 'CITIZEN-${restoredCitizen.userId}';
      portal = Portal.citizen;
    } else if (restoredOfficer != null) {
      staffSession = restoredOfficer;
      userName = restoredOfficer.name;
      userId = 'STAFF-${restoredOfficer.userId}';
      portal = Portal.officer;
    } else if (restoredCrew != null) {
      staffSession = restoredCrew;
      userName = restoredCrew.name;
      userId = 'STAFF-${restoredCrew.userId}';
      portal = Portal.crew;
    }

    citizenAuthReady = true;
    authReady = true;
    notifyListeners();
  }

  Future<void> registerCitizen({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    citizenAuthBusy = true;
    citizenAuthError = null;
    notifyListeners();
    try {
      pendingCitizenChallenge = await CitizenAuthService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
      userName = fullName.trim();
      portal = Portal.citizen;
    } on CitizenAuthException catch (e) {
      citizenAuthError = e.message;
      rethrow;
    } finally {
      citizenAuthBusy = false;
      notifyListeners();
    }
  }

  Future<void> verifyCitizen({required String emailCode}) async {
    final challenge = pendingCitizenChallenge;
    if (challenge == null)
      throw const CitizenAuthException(
        'Verification session expired. Start again.',
      );
    citizenAuthBusy = true;
    citizenAuthError = null;
    notifyListeners();
    try {
      citizenSession = await CitizenAuthService.verify(
        challengeId: challenge.challengeId,
        emailCode: emailCode,
      );
      userName = citizenSession!.name;
      userId = 'CITIZEN-${citizenSession!.userId}';
      portal = Portal.citizen;
      pendingCitizenChallenge = null;
    } on CitizenAuthException catch (e) {
      citizenAuthError = e.message;
      rethrow;
    } finally {
      citizenAuthBusy = false;
      notifyListeners();
    }
  }

  Future<void> loginCitizen({
    required String email,
    required String password,
  }) async {
    citizenAuthBusy = true;
    citizenAuthError = null;
    notifyListeners();
    try {
      citizenSession = await CitizenAuthService.login(
        email: email,
        password: password,
      );
      userName = citizenSession!.name;
      userId = 'CITIZEN-${citizenSession!.userId}';
      portal = Portal.citizen;
    } on CitizenAuthException catch (e) {
      citizenAuthError = e.message;
      rethrow;
    } finally {
      citizenAuthBusy = false;
      notifyListeners();
    }
  }

  Future<void> resendCitizenCodes() async {
    final session = citizenSession;
    final challenge = pendingCitizenChallenge;
    final userId = session?.userId ?? challenge?.userId;
    if (userId == null || userId <= 0)
      throw const CitizenAuthException(
        'Verification session expired. Start again.',
      );
    pendingCitizenChallenge = await CitizenAuthService.resend(userId: userId);
    notifyListeners();
  }

  Future<void> resendCitizenCodesByEmail(String email) async {
    pendingCitizenChallenge = await CitizenAuthService.resendByEmail(
      email: email,
    );
    portal = Portal.citizen;
    notifyListeners();
  }

  Future<void> registerStaff({
    required Portal portal,
    required String staffId,
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      pendingStaffChallenge = await StaffAuthService.register(
        role: portal,
        staffId: staffId,
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
      );
      this.portal = portal;
      pendingStaffEmail = email.trim();
      pendingStaffId = staffId.trim().toUpperCase();
      notifyListeners();
    } on StaffAuthException catch (e) {
      throw CitizenAuthException(e.message);
    }
  }

  Future<void> verifyStaff({
    required Portal portal,
    required String emailCode,
  }) async {
    final challenge = pendingStaffChallenge;
    if (challenge == null || challenge.portal != portal) {
      throw const CitizenAuthException(
        'Staff verification session expired. Start again.',
      );
    }
    try {
      staffSession = await StaffAuthService.verify(
        role: portal,
        challengeId: challenge.challengeId,
        emailCode: emailCode,
      );
      userName = staffSession!.name;
      userId = 'STAFF-${staffSession!.userId}';
      this.portal = portal;
      pendingStaffChallenge = null;
      pendingStaffEmail = '';
      pendingStaffId = '';
      notifyListeners();
    } on StaffAuthException catch (e) {
      throw CitizenAuthException(e.message);
    }
  }

  Future<void> loginStaff({
    required Portal portal,
    required String staffId,
    required String email,
    required String password,
  }) async {
    try {
      staffSession = await StaffAuthService.login(
        role: portal,
        staffId: staffId,
        email: email,
        password: password,
      );
      userName = staffSession!.name;
      userId = 'STAFF-${staffSession!.userId}';
      this.portal = portal;
      notifyListeners();
    } on StaffAuthException catch (e) {
      throw CitizenAuthException(e.message);
    }
  }

  Future<void> resendStaffCode({
    required Portal portal,
    required String staffId,
    required String email,
  }) async {
    try {
      pendingStaffChallenge = await StaffAuthService.resendByEmail(
        role: portal,
        staffId: staffId,
        email: email,
      );
      this.portal = portal;
      pendingStaffEmail = email.trim();
      pendingStaffId = staffId.trim().toUpperCase();
      notifyListeners();
    } on StaffAuthException catch (e) {
      throw CitizenAuthException(e.message);
    }
  }

  void setUserName(String name) {
    userName = name;
    notifyListeners();
  }

  void setPortal(Portal p) {
    portal = p;
    notifyListeners();
  }

  void setPendingOtp(String otp) {
    pendingOtp = otp;
    notifyListeners();
  }

  void login(String name, String id, Portal p) {
    userName = name;
    userId = id;
    portal = p;
    notifyListeners();
  }

  void logout() {
    CitizenAuthService.clear();
    StaffAuthService.clear(Portal.officer);
    StaffAuthService.clear(Portal.crew);
    citizenSession = null;
    pendingCitizenChallenge = null;
    staffSession = null;
    pendingStaffChallenge = null;
    pendingStaffEmail = '';
    pendingStaffId = '';
    portal = null;
    userName = 'Guest User';
    userId = 'GUEST-001';
    notifyListeners();
  }

  void setStartTab(int index) {
    startTab = index;
    notifyListeners();
  }

  void addBroadcast(BroadcastMessage b) {
    broadcasts.add(b);
    notifyListeners();
  }

  static const String _offlineReportsKey = 'nalanetra.offline.reports.json';

  Future<void> _saveOfflineReports() async {
    try {
      final userReports = reports.where((r) => r.id.startsWith('R-')).toList();
      final encoded = jsonEncode(userReports.map((r) => r.toJson()).toList());
      const storage = FlutterSecureStorage();
      await storage.write(key: _offlineReportsKey, value: encoded);
    } catch (e) {
      debugPrint('Failed to save offline reports: $e');
    }
  }

  Future<void> _restoreOfflineReports() async {
    try {
      const storage = FlutterSecureStorage();
      final saved = await storage.read(key: _offlineReportsKey);
      if (saved != null && saved.isNotEmpty) {
        final list = jsonDecode(saved) as List;
        final restored = list
            .map((item) => FloodReport.fromJson(item as Map<String, dynamic>))
            .toList();
        for (final r in restored) {
          if (!reports.any((existing) => existing.id == r.id)) {
            reports = [...reports, r];
          }
        }
        _refreshAnalyticsSnapshot(notify: false);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to restore offline reports: $e');
    }
  }

  Future<void> syncOfflineReports() async {
    if (!backendReachable) await checkBackendConnection();
    if (!backendReachable) return;

    final unSynced = reports.where((r) => !r.isSynced).toList();
    if (unSynced.isEmpty) return;

    for (final r in unSynced) {
      try {
        final payload = {
          'locationLabel': r.locationName,
          'lat': r.lat,
          'lng': r.lon,
          'depthTag': r.band.name,
          'notes': r.severitySummary,
        };
        final res = await http
            .post(
              Uri.parse(
                '$nalanetraBackendBaseUrl/api/trpc/incident.submit?batch=1',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'0': payload}),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          r.isSynced = true;
        }
      } catch (e) {
        debugPrint('Sync failed for report ${r.id}: $e');
      }
    }
    await _saveOfflineReports();
    notifyListeners();
  }

  void addReport(FloodReport report) {
    reports = [...reports, report];
    _refreshAnalyticsSnapshot(notify: false);
    _saveOfflineReports();
    syncOfflineReports();
    addNotification(
      Notif(
        kind: NotifKind.info,
        incidentId: report.incidentId,
        titleEn: 'New citizen report received: ${report.locationName}',
        titleHi: 'नागरिक रिपोर्ट प्राप्त: ${report.locationName}',
        assignmentIncidentId: report.incidentId,
        imagePath: report.photoPath,
        municipalImagePath:
            municipalNotificationImages[reports.length %
                municipalNotificationImages.length],
        locationName: report.locationName,
        reporterName: report.reporterName,
        reportCount: reports
            .where((item) => item.incidentId == report.incidentId)
            .length,
        severityBand: report.band,
        severityScore: report.severityScore,
        audiences: const {NotifAudience.citizen, NotifAudience.municipal},
        at: report.at,
      ),
    );
    notifyListeners();
  }

  List<Notif> notificationsFor(Portal role) {
    final audience = switch (role) {
      Portal.citizen => NotifAudience.citizen,
      Portal.officer || Portal.admin => NotifAudience.municipal,
      Portal.crew => NotifAudience.crew,
    };
    return notifications
        .where((notification) => notification.audiences.contains(audience))
        .toList(growable: false);
  }

  void addNotification(Notif n) {
    // Preserve null image paths. A missing field photo is a missing field photo;
    // never replace it with an unrelated catalog image.
    notifications = [n, ...notifications];
    if (notifications.length > 30) notifications.removeLast();
    _refreshAnalyticsSnapshot(notify: false);
    notifyListeners();
  }

  void setLocation(GurugramLocation l) {
    selectedLocation = l;
    fetchWeather(); // Refresh weather immediately when location changes
    notifyListeners();
  }

  List<FloodReport> priorityQueue() {
    final latestReports = <String, FloodReport>{};
    for (final r in reports) {
      if (!latestReports.containsKey(r.incidentId) ||
          r.at.isAfter(latestReports[r.incidentId]!.at)) {
        latestReports[r.incidentId] = r;
      }
    }
    final list = latestReports.values.toList();
    list.sort(
      (a, b) => b.priorityScore(reports).compareTo(a.priorityScore(reports)),
    );
    return list;
  }

  IncidentLifecycle statusOf(String incidentId) {
    if (verifiedIncidents.contains(incidentId))
      return IncidentLifecycle.verified;
    final jobIndex = jobs.indexWhere((j) => j.incidentId == incidentId);
    if (jobIndex != -1) return jobs[jobIndex].status;
    return IncidentLifecycle.submitted;
  }

  CrewJob? jobFor(String incidentId) {
    final index = jobs.indexWhere((job) => job.incidentId == incidentId);
    return index == -1 ? null : jobs[index];
  }

  void sendBroadcast(String msgEn, String msgHi, String target) {
    broadcasts.insert(
      0,
      BroadcastMessage(
        id: 'B${DateTime.now().millisecondsSinceEpoch}',
        msgEn: msgEn,
        msgHi: msgHi,
        target: target,
        time: 'Just now',
      ),
    );
    addNotification(
      Notif(
        kind: NotifKind.emergency,
        titleEn: 'BROADCAST: $target',
        titleHi: 'ब्रॉडकास्ट: $target',
        imagePath: municipalNotificationImages.first,
        municipalImagePath: municipalNotificationImages.first,
        locationName: 'Gurugram Command Centre',
        severityBand: SeverityBand.severe,
        severityScore: 0.80,
        audiences: const {NotifAudience.municipal},
      ),
    );
    notifyListeners();
  }

  void dispatchCrew(String incidentId, String crewName) {
    final crew = crewRoster.firstWhere(
      (member) => member.id == crewName,
      orElse: () => crewRoster.first,
    );
    final incidentAlreadyActive = jobs.any(
      (job) => job.incidentId == incidentId && !job.isDone,
    );
    final crewAlreadyAssigned = jobs.any(
      (job) => job.crewName == crew.id && !job.isDone,
    );
    if (crew.offDuty || incidentAlreadyActive || crewAlreadyAssigned) return;

    dispatchedIncidents.add(incidentId);
    incidentCrew[incidentId] = crew.id;

    final report = reports.firstWhere((r) => r.incidentId == incidentId);
    jobs.add(
      CrewJob(
        incidentId: incidentId,
        location: report.locationName,
        lat: report.lat,
        lon: report.lon,
        priority: (report.priorityScore(reports) * 100).toInt(),
        severity: (report.severityScore * 100).toInt(),
        reporters: reports.where((r) => r.incidentId == incidentId).length,
        crewName: crew.id,
        wing: crew.role,
        status: IncidentLifecycle.dispatched,
        dispatchedAt: DateTime.now(),
        beforePhotoPath: report.photoPath ?? '',
        afterPhotoPath: '',
      ),
    );

    addNotification(
      Notif(
        kind: NotifKind.crewAssigned,
        incidentId: incidentId,
        titleEn:
            '${crew.name} (${crew.id}) dispatched to ${report.locationName}',
        titleHi:
            '${crew.name} (${crew.id}) को ${report.locationName} के लिए रवाना किया गया',
        imagePath: report.photoPath,
        municipalImagePath:
            municipalNotificationImages[incidentId.codeUnits.fold<int>(
                  0,
                  (sum, unit) => sum + unit,
                ) %
                municipalNotificationImages.length],
        locationName: report.locationName,
        reporterName: report.reporterName,
        reportCount: reports
            .where((item) => item.incidentId == report.incidentId)
            .length,
        severityBand: report.band,
        severityScore: report.severityScore,
        audiences: const {NotifAudience.municipal, NotifAudience.crew},
      ),
    );
    addNotification(
      Notif(
        kind: NotifKind.info,
        incidentId: incidentId,
        titleEn: 'Your waterlogging report is assigned to a municipal crew',
        titleHi: 'आपकी जलभराव रिपोर्ट नगर निगम की टीम को सौंप दी गई है',
        imagePath: report.photoPath,
        audiences: const {NotifAudience.citizen},
      ),
    );

    notifyListeners();
  }

  bool assignCrewForNotification(String? incidentId, String crewId) {
    final target = incidentId?.trim();
    if (target == null || target.isEmpty) return false;
    final jobsBefore = jobs.length;
    dispatchCrew(target, crewId);
    return jobs.length > jobsBefore;
  }

  void updateJobStatus(
    String incidentId,
    IncidentLifecycle status, {
    String? beforePhoto,
    String? afterPhoto,
  }) {
    final index = jobs.indexWhere((j) => j.incidentId == incidentId);
    if (index == -1) return;
    final job = jobs[index];
    job.setStatus(status);
    final sourceReport = reports
        .where((report) => report.incidentId == incidentId)
        .firstOrNull;
    final canonicalBefore = sourceReport?.photoPath?.trim();
    if (canonicalBefore?.isNotEmpty == true) {
      job.beforePhotoPath = canonicalBefore!;
    } else if (job.beforePhotoPath.isEmpty &&
        beforePhoto != null &&
        beforePhoto.trim().isNotEmpty) {
      job.beforePhotoPath = beforePhoto.trim();
    }
    if (status == IncidentLifecycle.dispatched) {
      // Rework starts a fresh proof cycle; never reuse a prior cleanup image.
      job.afterPhotoPath = '';
      job.afterProofUploaded = false;
      job.afterUploadedAt = null;
    }
    final candidateAfter = afterPhoto?.trim();
    if (candidateAfter != null &&
        candidateAfter.isNotEmpty &&
        candidateAfter != job.beforePhotoPath) {
      job.afterPhotoPath = candidateAfter;
      job.afterProofUploaded = true;
      job.afterUploadedAt = DateTime.now();
    }
    if (status == IncidentLifecycle.onSite) {
      final report = reports.firstWhere(
        (item) => item.incidentId == incidentId,
        orElse: () => FloodReport(
          id: 'unknown',
          lat: job.lat,
          lon: job.lon,
          locationName: job.location,
          severitySummary: 'Field incident',
          band: SeverityBand.moderate,
          severityScore: 0.5,
          rainfallScore: 0.5,
          criticality: 0.5,
          at: DateTime.now(),
          reporterName: 'System',
          incidentId: incidentId,
        ),
      );
      addNotification(
        Notif(
          kind: NotifKind.assignment,
          incidentId: incidentId,
          titleEn: 'Crew is on site at ${report.locationName}',
          titleHi: 'क्रू ${report.locationName} पर पहुंच गई है',
          imagePath: job.beforePhotoPath,
          municipalImagePath:
              municipalNotificationImages[incidentId.codeUnits.fold<int>(
                    0,
                    (sum, unit) => sum + unit,
                  ) %
                  municipalNotificationImages.length],
          locationName: report.locationName,
          reporterName: report.reporterName,
          reportCount: reports
              .where((item) => item.incidentId == report.incidentId)
              .length,
          severityBand: report.band,
          severityScore: report.severityScore,
          audiences: const {NotifAudience.municipal, NotifAudience.crew},
        ),
      );
    }
    if (job.hasAfterProof) {
      addNotification(
        Notif(
          kind: NotifKind.info,
          incidentId: incidentId,
          titleEn:
              'After-cleanup proof uploaded — awaiting municipal verification',
          titleHi:
              'सफाई के बाद का प्रमाण अपलोड — नगर निगम सत्यापन की प्रतीक्षा',
          imagePath: job.beforePhotoPath,
          municipalImagePath:
              municipalNotificationImages[incidentId.codeUnits.fold<int>(
                    0,
                    (sum, unit) => sum + unit,
                  ) %
                  municipalNotificationImages.length],
          beforeImagePath: job.beforePhotoPath,
          afterImagePath: job.afterPhotoPath,
          locationName: sourceReport?.locationName ?? job.location,
          reporterName: sourceReport?.reporterName,
          reportCount: reports
              .where((item) => item.incidentId == incidentId)
              .length,
          severityBand: sourceReport?.band ?? SeverityBand.moderate,
          severityScore: sourceReport?.severityScore ?? job.severity / 100,
          audiences: const {NotifAudience.municipal, NotifAudience.crew},
        ),
      );
    }
    _refreshAnalyticsSnapshot(notify: false);
    notifyListeners();
  }

  void verifyIncident(String incidentId) {
    final job = jobs.firstWhere((j) => j.incidentId == incidentId);
    if (job.beforePhotoPath.trim().isEmpty || !job.hasAfterProof) return;
    verifiedIncidents.add(incidentId);
    job.setStatus(IncidentLifecycle.verified);
    final sourceReport = reports
        .where((report) => report.incidentId == incidentId)
        .firstOrNull;
    final reportLocation = sourceReport?.locationName ?? job.location;
    final reportBand = sourceReport?.band ?? SeverityBand.moderate;
    final reportScore = sourceReport?.severityScore ?? job.severity / 100;
    // Citizen closure update: the matched pair is intentionally available to
    // the reporter after supervisor verification.
    addNotification(
      Notif(
        kind: NotifKind.verified,
        incidentId: incidentId,
        titleEn: 'Incident $incidentId Verified & Closed',
        titleHi: 'इंसिडेंट $incidentId सत्यापित और बंद',
        imagePath: job.afterPhotoPath,
        beforeImagePath: job.beforePhotoPath,
        afterImagePath: job.afterPhotoPath,
        locationName: reportLocation,
        severityBand: reportBand,
        severityScore: reportScore,
        audiences: const {NotifAudience.citizen},
      ),
    );
    // Municipal feed: flood evidence only. The supervisor comparison remains
    // in the Verify tab, where the same job ID supplies both images.
    addNotification(
      Notif(
        kind: NotifKind.verified,
        incidentId: incidentId,
        titleEn: 'Incident $incidentId closed — flood report verified',
        titleHi: 'इंसिडेंट $incidentId बंद — जलभराव रिपोर्ट सत्यापित',
        imagePath: job.beforePhotoPath,
        municipalImagePath:
            municipalNotificationImages[incidentId.codeUnits.fold<int>(
                  0,
                  (sum, unit) => sum + unit,
                ) %
                municipalNotificationImages.length],
        locationName: reportLocation,
        severityBand: reportBand,
        severityScore: reportScore,
        audiences: const {NotifAudience.municipal},
      ),
    );
    _refreshAnalyticsSnapshot(notify: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _liveTimer?.cancel();
    _weatherTimer?.cancel();
    super.dispose();
  }
}

class ResourceItemData {
  final String id, nameEn, nameHi, deptEn, deptHi, icon;
  final int total;
  int active;
  final int cycleStep;
  final int color;
  ResourceItemData({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.total,
    required this.active,
    this.cycleStep = 1,
    required this.deptEn,
    required this.deptHi,
    required this.icon,
    required this.color,
  });

  void advanceUsage() {
    if (total <= 0) return;
    final next = active + cycleStep;
    active = next >= total ? 0 : next;
  }
}

class BroadcastMessage {
  final String id, msgEn, msgHi, target, time;
  BroadcastMessage({
    required this.id,
    required this.msgEn,
    required this.msgHi,
    required this.target,
    required this.time,
  });
}
