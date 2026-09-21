import 'dart:io';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

// ---------------------------------------------------------------------------
// NalaNetra FloodGrid — Crew Portal
// Field response workflow: missions -> navigation -> proof -> verification.
// Citizen and Municipal portal widgets are intentionally not imported here.
// ---------------------------------------------------------------------------

class CrewPortal extends StatefulWidget {
  const CrewPortal({super.key});

  @override
  State<CrewPortal> createState() => _CrewPortalState();
}

class _CrewPortalState extends State<CrewPortal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CrewMember _currentCrew(AppStore store) {
    final requestedId = store.userId.trim();
    return AppStore.crewRoster.firstWhere(
      (member) => member.id == requestedId,
      orElse: () => AppStore.crewRoster.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final crew = _currentCrew(store);

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF1F5F9),
      appBar: _CrewHeaderBar(
        title: en ? 'Field Response Unit' : 'फील्ड रिस्पांस यूनिट',
        subtitle:
            '${en ? 'Crew ID' : 'क्रू आईडी'}: ${crew.id} | ${en ? 'Zone' : 'ज़ोन'}: ${crew.ward.replaceFirst('Ward ', 'Sector ')}',
        onProfile: () => _showCrewProfile(context, store, crew, en, isDark),
        onSettings: () => _showCrewSettings(context, store, en, isDark),
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? GovColors.navyDeep : GovColors.navy,
            child: TabBar(
              controller: _tabController,
              indicatorColor: GovColors.gold,
              indicatorWeight: 4,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.assignment_rounded, size: 20),
                  text: en ? 'Active Jobs' : 'सक्रिय कार्य',
                ),
                Tab(
                  icon: const Icon(Icons.history_rounded, size: 20),
                  text: en ? 'Completed' : 'पूरे हुए',
                ),
                Tab(
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                  ),
                  text: en ? 'Alerts' : 'अलर्ट',
                ),
              ],
            ),
          ),
          _CrewStats(store: store, en: en, isDark: isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/operations'),
                icon: const Icon(Icons.hub_outlined),
                label: Text(
                  en ? 'Open scalable operations' : 'स्केलेबल संचालन खोलें',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GovColors.navy,
                  side: const BorderSide(color: GovColors.navy),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CrewJobsList(
                  store: store,
                  en: en,
                  isDark: isDark,
                  showCompleted: false,
                  onOpenJob: (job) => _openJobDetails(context, job),
                  onNavigate: (job) => _openNavigation(context, job),
                ),
                _CrewJobsList(
                  store: store,
                  en: en,
                  isDark: isDark,
                  showCompleted: true,
                  onOpenJob: (job) => _openJobDetails(context, job),
                  onNavigate: (job) => _openNavigation(context, job),
                ),
                _CrewAlertsTab(
                  store: store,
                  en: en,
                  isDark: isDark,
                  onOpenNotification: (notification) =>
                      _showCrewAlertDetails(context, notification, en, isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openJobDetails(BuildContext context, CrewJob job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CrewJobDetailsScreen(
          jobId: job.incidentId,
          onNavigate: () => _openNavigation(context, job),
          onProof: () => _showProofSheet(context, job),
          onWorkUpdate: () => _showWorkUpdateSheet(context, job),
        ),
      ),
    );
  }

  void _openNavigation(BuildContext context, CrewJob job) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _CrewNavigationScreen(job: job)));
  }

  void _showProofSheet(BuildContext context, CrewJob job) {
    final store = context.read<AppStore>();
    final en = store.lang == AppLang.en;
    final isDark = store.themeMode == AppThemeMode.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProofCaptureSheet(
        job: job,
        store: store,
        en: en,
        isDark: isDark,
        onCapture: () => _captureAfterProof(sheetContext, job, store, en),
      ),
    );
  }

  Future<void> _captureAfterProof(
    BuildContext sheetContext,
    CrewJob job,
    AppStore store,
    bool en,
  ) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (!sheetContext.mounted) return;
    if (picked == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(
            en ? 'After photo is required.' : 'सफाई के बाद की फोटो जरूरी है।',
          ),
        ),
      );
      return;
    }
    store.updateJobStatus(
      job.incidentId,
      IncidentLifecycle.workProgress,
      beforePhoto: job.beforePhotoPath,
      afterPhoto: picked.path,
    );
    Navigator.of(sheetContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          en
              ? 'Proof submitted for municipal verification.'
              : 'प्रमाण नगर निगम सत्यापन के लिए जमा हो गया।',
        ),
      ),
    );
  }

  void _showWorkUpdateSheet(BuildContext context, CrewJob job) {
    final store = context.read<AppStore>();
    final en = store.lang == AppLang.en;
    final isDark = store.themeMode == AppThemeMode.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _WorkUpdateSheet(
        job: job,
        store: store,
        en: en,
        isDark: isDark,
        onSave: () {
          store.updateJobStatus(
            job.incidentId,
            IncidentLifecycle.workProgress,
            beforePhoto: job.beforePhotoPath,
          );
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                en ? 'Mission progress saved.' : 'मिशन की प्रगति सेव हो गई।',
              ),
            ),
          );
        },
        onProof: () => _captureAfterProof(sheetContext, job, store, en),
      ),
    );
  }

  void _showCrewAlertDetails(
    BuildContext context,
    Notif notification,
    bool en,
    bool isDark,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? GovColors.cardDark : Colors.white,
        title: Text(
          en ? notification.titleEn : notification.titleHi,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.locationName?.isNotEmpty == true)
              _DetailLine(
                icon: Icons.location_on_outlined,
                label: en ? 'Location' : 'स्थान',
                value: notification.locationName!,
                isDark: isDark,
              ),
            if (notification.severityScore != null)
              _DetailLine(
                icon: Icons.auto_awesome_outlined,
                label: en ? 'AI score' : 'एआई स्कोर',
                value: '${(notification.severityScore! * 100).round()}%',
                isDark: isDark,
              ),
            _DetailLine(
              icon: Icons.schedule_outlined,
              label: en ? 'Received' : 'प्राप्त समय',
              value: _relativeTime(notification.at),
              isDark: isDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(en ? 'CLOSE' : 'बंद करें'),
          ),
        ],
      ),
    );
  }

  void _showCrewProfile(
    BuildContext context,
    AppStore store,
    CrewMember crew,
    bool en,
    bool isDark,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CrewProfileSheet(store: store, crew: crew, en: en, isDark: isDark),
    );
  }

  void _showCrewSettings(
    BuildContext context,
    AppStore store,
    bool en,
    bool isDark,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CrewSettingsSheet(
        store: store,
        en: en,
        isDark: isDark,
        onSignOut: () {
          store.logout();
          Navigator.of(sheetContext).pop();
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        },
      ),
    );
  }
}

class _CrewHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  const _CrewHeaderBar({
    required this.title,
    required this.subtitle,
    required this.onProfile,
    required this.onSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      height: preferredSize.height + topInset,
      padding: EdgeInsets.fromLTRB(14, topInset + 6, 8, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GovColors.navy, GovColors.navyDeep],
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/logo.png',
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Crew profile',
            onPressed: onProfile,
            icon: const Icon(
              Icons.badge_outlined,
              color: Colors.white,
              size: 21,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
          IconButton(
            tooltip: 'Settings and support',
            onPressed: onSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 21,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          ),
        ],
      ),
    );
  }
}

class _CrewStats extends StatelessWidget {
  final AppStore store;
  final bool en;
  final bool isDark;

  const _CrewStats({
    required this.store,
    required this.en,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final active = store.jobs.where((job) => !job.isDone).length;
    final completed = store.jobs.where((job) => job.isDone).length;
    final proofPending = store.jobs
        .where((job) => job.hasAfterProof && !job.isDone)
        .length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: isDark ? GovColors.bgDark : Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              _CrewStat(
                label: en ? 'Active Missions' : 'सक्रिय मिशन',
                value: '$active',
                color: GovColors.severe,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _CrewStat(
                label: en ? 'Completed Today' : 'आज पूरे हुए',
                value: '$completed',
                color: GovColors.ok,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _CrewStat(
                label: en ? 'Proof Pending' : 'प्रमाण लंबित',
                value: '$proofPending',
                color: GovColors.gold,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: GovColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GovColors.navy.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: GovColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    en
                        ? 'MISSION MODE ACTIVE  •  Prioritize the assigned hotspot and upload proof before closing.'
                        : 'मिशन मोड सक्रिय  •  असाइन हॉटस्पॉट को प्राथमिकता दें और बंद करने से पहले प्रमाण अपलोड करें।',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : GovColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _CrewStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrewJobsList extends StatelessWidget {
  final AppStore store;
  final bool en;
  final bool isDark;
  final bool showCompleted;
  final ValueChanged<CrewJob> onOpenJob;
  final ValueChanged<CrewJob> onNavigate;

  const _CrewJobsList({
    required this.store,
    required this.en,
    required this.isDark,
    required this.showCompleted,
    required this.onOpenJob,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final jobs = store.jobs
        .where((job) => showCompleted ? job.isDone : !job.isDone)
        .toList();
    jobs.sort((a, b) => b.priority.compareTo(a.priority));

    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showCompleted
                    ? Icons.verified_outlined
                    : Icons.assignment_late_outlined,
                size: 64,
                color: isDark
                    ? Colors.white24
                    : GovColors.navy.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 16),
              Text(
                showCompleted
                    ? (en
                          ? 'No verified missions yet'
                          : 'अभी कोई सत्यापित मिशन नहीं')
                    : (en ? 'No active missions' : 'कोई सक्रिय मिशन नहीं'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: jobs.length,
      itemBuilder: (context, index) => _CrewJobCard(
        job: jobs[index],
        store: store,
        en: en,
        isDark: isDark,
        onOpen: () => onOpenJob(jobs[index]),
        onNavigate: () => onNavigate(jobs[index]),
      ),
    );
  }
}

// Active mission cards deliberately use this flood-only catalog. These assets
// are incoming waterlogging evidence and are never used as crew after-proof.
const _crewActiveJobFloodImagesByIncident = <String, String>{
  'INC-8291': 'assets/user_active_job_floods/active_job_flood_01.jpg',
  'INC-7721': 'assets/user_active_job_floods/active_job_flood_02.jpg',
  'INC-1092': 'assets/user_active_job_floods/active_job_flood_03.jpg',
  'INC-5521': 'assets/user_active_job_floods/active_job_flood_04.jpg',
  'INC-3341': 'assets/user_active_job_floods/active_job_flood_05.jpg',
  'INC-9901': 'assets/user_active_job_floods/active_job_flood_06.jpg',
};

const _crewActiveJobFloodSequence = <String>[
  'assets/user_active_job_floods/active_job_flood_01.jpg',
  'assets/user_active_job_floods/active_job_flood_02.jpg',
  'assets/user_active_job_floods/active_job_flood_03.jpg',
  'assets/user_active_job_floods/active_job_flood_04.jpg',
  'assets/user_active_job_floods/active_job_flood_05.jpg',
  'assets/user_active_job_floods/active_job_flood_06.jpg',
  'assets/user_active_job_floods/active_job_flood_07.webp',
  'assets/user_active_job_floods/active_job_flood_08.jpg',
];

String _crewActiveJobFloodImageFor(String incidentId) {
  return _crewActiveJobFloodImagesByIncident[incidentId] ??
      _crewActiveJobFloodSequence[incidentId.hashCode.abs() %
          _crewActiveJobFloodSequence.length];
}

class _CrewJobCard extends StatelessWidget {
  final CrewJob job;
  final AppStore store;
  final bool en;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onNavigate;

  const _CrewJobCard({
    required this.job,
    required this.store,
    required this.en,
    required this.isDark,
    required this.onOpen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final report = store.reports.firstWhere(
      (item) => item.incidentId == job.incidentId,
      orElse: () => FloodReport(
        id: 'crew-${job.incidentId}',
        lat: job.lat,
        lon: job.lon,
        locationName: job.location,
        severitySummary: 'Field incident',
        band: SeverityBand.severe,
        severityScore: job.severity / 100,
        rainfallScore: 0.6,
        criticality: 0.7,
        at: job.dispatchedAt,
        reporterName: 'Citizen report',
        incidentId: job.incidentId,
      ),
    );
    final status = job.status;
    final statusColor = status.color;
    final evidencePath = _crewActiveJobFloodImageFor(job.incidentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.32),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 132,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: _EvidenceImage(
                      key: ValueKey('crew-active-job-image-${job.incidentId}'),
                      path: evidencePath,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.68),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            job.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(label: status.label, color: statusColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${en ? 'Incident' : 'इंसिडेंट'}: ${job.incidentId}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : GovColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      _StatusPill(
                        label: job.priority >= 90
                            ? (en ? 'CRITICAL' : 'गंभीर')
                            : (en ? 'HIGH PRIORITY' : 'उच्च प्राथमिकता'),
                        color: job.priority >= 90
                            ? GovColors.critical
                            : GovColors.severe,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      _MetaText(
                        icon: Icons.auto_awesome_outlined,
                        text: 'AI ${job.priority}%',
                        color: GovColors.navy,
                        isDark: isDark,
                      ),
                      _MetaText(
                        icon: Icons.groups_outlined,
                        text: '${job.reporters} ${en ? 'reports' : 'रिपोर्ट'}',
                        color: GovColors.navy,
                        isDark: isDark,
                      ),
                      _MetaText(
                        icon: Icons.access_time_outlined,
                        text: _relativeTime(job.dispatchedAt),
                        color: Colors.grey,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(en ? 'VIEW MISSION' : 'मिशन देखें'),
                          style: _primaryButtonStyle(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onNavigate,
                          icon: const Icon(Icons.navigation_outlined, size: 16),
                          label: Text(en ? 'NAVIGATE' : 'रास्ता देखें'),
                          style: _outlineButtonStyle(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _crewFloodFeedImages = <String>[
  'assets/user_crew_floods/crew_flood_01.jpg',
  'assets/user_crew_floods/crew_flood_02.jpg',
  'assets/user_crew_floods/crew_flood_03.jpg',
  'assets/user_crew_floods/crew_flood_04.jpg',
  'assets/user_crew_floods/crew_flood_05.jpg',
  'assets/user_crew_floods/crew_flood_06.webp',
  'assets/user_crew_floods/crew_flood_07.jpg',
  'assets/user_crew_floods/crew_flood_08.jpg',
  'assets/user_crew_floods/crew_flood_09.jpg',
  'assets/user_crew_floods/crew_flood_10.jpg',
  'assets/user_crew_floods/crew_flood_11.jpg',
  'assets/user_crew_floods/crew_flood_12.jpg',
  'assets/user_crew_floods/crew_flood_13.jpg',
  'assets/user_crew_floods/crew_flood_14.jpg',
  'assets/user_crew_floods/crew_flood_15.jpg',
  'assets/user_crew_floods/crew_flood_16.webp',
  'assets/user_crew_floods/crew_flood_17.jpg',
  'assets/user_crew_floods/crew_flood_18.jpg',
  'assets/user_crew_floods/crew_flood_19.png',
  'assets/user_crew_floods/crew_flood_20.jpg',
  'assets/user_crew_floods/crew_flood_21.jpg',
];

class _CrewAlertsTab extends StatelessWidget {
  final AppStore store;
  final bool en;
  final bool isDark;
  final ValueChanged<Notif> onOpenNotification;

  const _CrewAlertsTab({
    required this.store,
    required this.en,
    required this.isDark,
    required this.onOpenNotification,
  });

  List<Notif> _floodFeed(AppStore store) {
    final reports = store.reports
        .where((report) => report.photoPath?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (reports.isEmpty) return const [];

    final start = store.liveTick % reports.length;
    return List<Notif>.generate(8, (index) {
      final report = reports[(start + index) % reports.length];
      final location = report.locationName.split('—').first.trim();
      return Notif(
        kind: NotifKind.emergency,
        incidentId: report.incidentId,
        assignmentIncidentId: report.incidentId,
        titleEn: 'Flood water reported — $location',
        titleHi: 'जलभराव रिपोर्ट — $location',
        imagePath: _crewFloodFeedImages[index % _crewFloodFeedImages.length],
        locationName: report.locationName,
        reporterName: report.reporterName,
        reportCount: store.reports
            .where((item) => item.incidentId == report.incidentId)
            .length,
        severityBand: report.band,
        severityScore: report.severityScore,
        audiences: const {NotifAudience.crew},
        at: report.at,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _floodFeed(store);
    if (alerts.isEmpty) {
      return Center(
        child: Text(
          en ? 'No crew alerts' : 'कोई क्रू अलर्ट नहीं',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final color = _notificationColor(alert.kind);
        return Material(
          key: ValueKey('crew_feed_$index'),
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpenNotification(alert),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      alert.imagePath ?? _crewFloodFeedImages[index],
                      width: 82,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 82,
                        height: 72,
                        color: color.withValues(alpha: 0.12),
                        child: Icon(
                          _notificationIcon(alert.kind),
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          en ? alert.titleEn : alert.titleHi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : GovColors.navy,
                          ),
                        ),
                        if (alert.locationName?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            alert.locationName!,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : GovColors.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${_relativeTime(alert.at)}  •  ${alert.reporterName ?? 'Citizen report'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CrewJobDetailsScreen extends StatelessWidget {
  final String jobId;
  final VoidCallback onNavigate;
  final VoidCallback onProof;
  final VoidCallback onWorkUpdate;

  const _CrewJobDetailsScreen({
    required this.jobId,
    required this.onNavigate,
    required this.onProof,
    required this.onWorkUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final en = store.lang == AppLang.en;
    final isDark = store.themeMode == AppThemeMode.dark;
    final job = store.jobFor(jobId);
    if (job == null) {
      return Scaffold(
        appBar: AppBar(title: Text(en ? 'Mission Details' : 'मिशन विवरण')),
        body: Center(
          child: Text(en ? 'Mission unavailable' : 'मिशन उपलब्ध नहीं'),
        ),
      );
    }
    final report = store.reports.firstWhere(
      (item) => item.incidentId == job.incidentId,
      orElse: () => FloodReport(
        id: 'detail-${job.incidentId}',
        lat: job.lat,
        lon: job.lon,
        locationName: job.location,
        severitySummary: 'Field incident',
        band: SeverityBand.severe,
        severityScore: job.severity / 100,
        rainfallScore: 0.6,
        criticality: 0.7,
        at: job.dispatchedAt,
        reporterName: 'Citizen report',
        incidentId: job.incidentId,
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF1F5F9),
      appBar: GovHeader(
        title: en ? 'Mission Details' : 'मिशन विवरण',
        subtitle: job.incidentId,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _DetailEvidenceCard(job: job, report: report, en: en, isDark: isDark),
          const SizedBox(height: 14),
          _SectionTitle(
            title: en ? 'Priority context' : 'प्राथमिकता जानकारी',
            isDark: isDark,
          ),
          _InfoPanel(
            isDark: isDark,
            children: [
              _DetailLine(
                icon: Icons.auto_awesome_outlined,
                label: en ? 'AI priority score' : 'एआई प्राथमिकता स्कोर',
                value: '${job.priority} / 100',
                isDark: isDark,
              ),
              _DetailLine(
                icon: Icons.water_drop_outlined,
                label: en ? 'Severity' : 'तीव्रता',
                value: '${job.severity}%',
                isDark: isDark,
              ),
              _DetailLine(
                icon: Icons.groups_outlined,
                label: en ? 'Similar reports' : 'मिलती-जुलती रिपोर्ट',
                value: '${job.reporters}',
                isDark: isDark,
              ),
              _DetailLine(
                icon: Icons.local_hospital_outlined,
                label: en ? 'Critical route' : 'महत्वपूर्ण मार्ग',
                value: report.criticality >= 0.7
                    ? (en
                          ? 'Hospital / public route'
                          : 'अस्पताल / सार्वजनिक मार्ग')
                    : (en ? 'Local road' : 'स्थानीय सड़क'),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle(
            title: en ? 'Mission actions' : 'मिशन के कार्य',
            isDark: isDark,
          ),
          _InfoPanel(
            isDark: isDark,
            children: [
              if (job.status == IncidentLifecycle.dispatched)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      store.updateJobStatus(
                        job.incidentId,
                        IncidentLifecycle.onSite,
                        beforePhoto: job.beforePhotoPath,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            en
                                ? 'Arrival confirmed. Mission is now ON SITE.'
                                : 'पहुंच की पुष्टि हो गई। मिशन साइट पर है।',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(
                      en
                          ? 'CONFIRM ARRIVAL / START MISSION'
                          : 'पहुंच की पुष्टि / मिशन शुरू करें',
                    ),
                    style: _primaryButtonStyle(),
                  ),
                ),
              if (job.status == IncidentLifecycle.onSite ||
                  job.status == IncidentLifecycle.workProgress)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onWorkUpdate,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(
                      en ? 'UPDATE WORK PROGRESS' : 'कार्य प्रगति अपडेट करें',
                    ),
                    style: _primaryButtonStyle(),
                  ),
                ),
              if (!job.hasAfterProof &&
                  job.status != IncidentLifecycle.dispatched)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onProof,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        en
                            ? 'CAPTURE AFTER PHOTO & SUBMIT PROOF'
                            : 'बाद की फोटो और प्रमाण जमा करें',
                      ),
                      style: _primaryButtonStyle(color: GovColors.gold),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(
                      en ? 'NAVIGATE TO INCIDENT' : 'घटना स्थल तक रास्ता',
                    ),
                    style: _outlineButtonStyle(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProofStatePanel(job: job, en: en, isDark: isDark),
        ],
      ),
    );
  }
}

class _DetailEvidenceCard extends StatelessWidget {
  final CrewJob job;
  final FloodReport report;
  final bool en;
  final bool isDark;

  const _DetailEvidenceCard({
    required this.job,
    required this.report,
    required this.en,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final before = _crewActiveJobFloodImageFor(job.incidentId);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            child: _EvidenceImage(
              key: ValueKey(
                'crew-mission-detail-image-${job.incidentId}-$before',
              ),
              path: before,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.location,
                  style: GoogleFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : GovColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${en ? 'Incident' : 'इंसिडेंट'} ${job.incidentId}  •  ${en ? 'Reported by' : 'रिपोर्टर'} ${report.reporterName}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatusPill(
                      label: job.status.label,
                      color: job.status.color,
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: 'AI ${job.priority}%',
                      color: job.priority >= 90
                          ? GovColors.critical
                          : GovColors.severe,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofStatePanel extends StatelessWidget {
  final CrewJob job;
  final bool en;
  final bool isDark;

  const _ProofStatePanel({
    required this.job,
    required this.en,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ready = job.hasAfterProof;
    final color = ready ? GovColors.ok : GovColors.gold;
    return _InfoPanel(
      isDark: isDark,
      children: [
        Row(
          children: [
            Icon(
              ready
                  ? Icons.check_circle_outline
                  : Icons.photo_camera_back_outlined,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ready
                    ? (en
                          ? 'Proof uploaded — awaiting municipal verification'
                          : 'प्रमाण अपलोड — नगर निगम सत्यापन लंबित')
                    : (en
                          ? 'After photo is required before closure'
                          : 'बंद करने से पहले बाद की फोटो जरूरी है'),
                style: TextStyle(
                  color: isDark ? Colors.white : GovColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ready ? 0.8 : 0.45,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          ready
              ? (en
                    ? 'Crew uploaded → Municipal review → Verified closure'
                    : 'क्रू अपलोड → नगर निगम समीक्षा → सत्यापित समापन')
              : (en
                    ? 'Crew on site → Work update → After proof'
                    : 'क्रू साइट पर → कार्य अपडेट → बाद का प्रमाण'),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _CrewNavigationScreen extends StatefulWidget {
  final CrewJob job;

  const _CrewNavigationScreen({required this.job});

  @override
  State<_CrewNavigationScreen> createState() => _CrewNavigationScreenState();
}

class _CrewNavigationScreenState extends State<_CrewNavigationScreen> {
  final MapController _mapController = MapController();
  final geo.Distance _distance = const geo.Distance();
  Timer? _movementTimer;
  List<geo.LatLng> _routePoints = const [];
  int _vehicleIndex = 0;
  double _segmentProgress = 0;
  geo.LatLng? _gpsOrigin;
  bool _gpsLoading = true;
  double? _routeDistanceKm;
  double? _routeDurationMinutes;
  bool _routeLoading = true;
  bool _routeFromNetwork = false;
  bool _navigating = false;

  CrewJob get job => widget.job;

  geo.LatLng get _destination => geo.LatLng(job.lat, job.lon);

  geo.LatLng get _fallbackOrigin =>
      geo.LatLng(job.lat + 0.018, job.lon - 0.014);

  geo.LatLng get _origin => _gpsOrigin ?? _fallbackOrigin;

  geo.LatLng get _vehiclePosition {
    if (_routePoints.isEmpty) return _origin;
    final startIndex = _vehicleIndex.clamp(0, _routePoints.length - 1);
    if (startIndex >= _routePoints.length - 1) return _routePoints.last;
    final start = _routePoints[startIndex];
    final end = _routePoints[startIndex + 1];
    return geo.LatLng(
      start.latitude + (end.latitude - start.latitude) * _segmentProgress,
      start.longitude + (end.longitude - start.longitude) * _segmentProgress,
    );
  }

  double get _remainingDistanceKm {
    if (_routePoints.length < 2 || _vehicleIndex >= _routePoints.length - 1) {
      return 0;
    }
    var metres = _distance.as(
      geo.LengthUnit.Meter,
      _vehiclePosition,
      _routePoints[_vehicleIndex + 1],
    );
    for (var index = _vehicleIndex + 2; index < _routePoints.length; index++) {
      metres += _distance.as(
        geo.LengthUnit.Meter,
        _routePoints[index - 1],
        _routePoints[index],
      );
    }
    return metres / 1000;
  }

  double get _remainingDurationMinutes => _remainingDistanceKm * 2.5;

  @override
  void initState() {
    super.initState();
    _routePoints = _fallbackRoute();
    _routeDistanceKm = _calculateRouteDistance(_routePoints);
    _routeDurationMinutes = (_routeDistanceKm ?? 4.8) * 2.5;
    _fitRouteToMap(_routePoints);
    _loadGpsOrigin();
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  List<geo.LatLng> _fallbackRoute() {
    return List<geo.LatLng>.generate(12, (index) {
      final t = index / 11;
      final curve = (index == 0 || index == 11)
          ? 0.0
          : (index.isEven ? 0.0012 : -0.0008);
      return geo.LatLng(
        _origin.latitude +
            (_destination.latitude - _origin.latitude) * t +
            curve,
        _origin.longitude + (_destination.longitude - _origin.longitude) * t,
      );
    });
  }

  double _calculateRouteDistance(List<geo.LatLng> points) {
    if (points.length < 2) return 4.8;
    var metres = 0.0;
    for (var index = 1; index < points.length; index++) {
      metres += _distance.as(
        geo.LengthUnit.Meter,
        points[index - 1],
        points[index],
      );
    }
    return metres / 1000;
  }

  void _fitRouteToMap(List<geo.LatLng> points) {
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(42, 104, 42, 136),
            maxZoom: 15.6,
          ),
        );
      } catch (_) {
        // The map may not be mounted yet; the initial camera remains usable.
      }
    });
  }

  Future<void> _loadGpsOrigin() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission unavailable');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(const Duration(seconds: 7));
      if (!mounted) return;
      setState(() {
        _gpsOrigin = geo.LatLng(position.latitude, position.longitude);
        _gpsLoading = false;
        _routePoints = _fallbackRoute();
        _routeDistanceKm = _calculateRouteDistance(_routePoints);
        _routeDurationMinutes = (_routeDistanceKm ?? 4.8) * 2.5;
      });
      await _loadRoadRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() => _gpsLoading = false);
      await _loadRoadRoute();
    }
  }

  Future<void> _loadRoadRoute() async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_origin.longitude},${_origin.latitude};'
        '${_destination.longitude},${_destination.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception('Route request failed');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) throw Exception('No route found');
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.length < 2) {
        throw Exception('Route geometry unavailable');
      }
      final points = coordinates
          .map((point) {
            final pair = point as List<dynamic>;
            return geo.LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          })
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _vehicleIndex = 0;
        _segmentProgress = 0;
        _routeDistanceKm =
            ((route['distance'] as num?)?.toDouble() ?? 0) / 1000;
        _routeDurationMinutes =
            ((route['duration'] as num?)?.toDouble() ?? 0) / 60;
        _routeLoading = false;
        _routeFromNetwork = true;
      });
      _fitRouteToMap(points);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routeLoading = false);
    }
  }

  void _startNavigation(AppStore store, bool en) {
    if (!_navigating) {
      setState(() => _navigating = true);
      if (job.status == IncidentLifecycle.dispatched) {
        store.updateJobStatus(
          job.incidentId,
          IncidentLifecycle.onSite,
          beforePhoto: job.beforePhotoPath,
        );
      }
      _movementTimer?.cancel();
      _movementTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!mounted) return;
        if (_vehicleIndex >= _routePoints.length - 1) {
          _movementTimer?.cancel();
          return;
        }
        setState(() {
          _segmentProgress += 0.06;
          if (_segmentProgress >= 1) {
            _segmentProgress = 0;
            _vehicleIndex += 1;
          }
        });
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          en
              ? 'Navigation started. Crew vehicle is moving on the route.'
              : 'नेविगेशन शुरू हो गया। क्रू वाहन मार्ग पर आगे बढ़ रहा है।',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final en = store.lang == AppLang.en;
    final isDark = store.themeMode == AppThemeMode.dark;
    final destinationLabel = job.location.split('—').first.trim();
    final distanceLabel =
        '${(_navigating ? _remainingDistanceKm : (_routeDistanceKm ?? 4.8)).toStringAsFixed(1)} km';
    final etaLabel =
        '${(_navigating ? _remainingDurationMinutes : (_routeDurationMinutes ?? 12)).round()} min';

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF1F5F9),
      appBar: GovHeader(
        title: en ? 'Navigate to Mission' : 'मिशन तक रास्ता',
        subtitle: destinationLabel,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF17213A)
                    : const Color(0xFFE3EDF0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: geo.LatLng(
                        (_origin.latitude + _destination.latitude) / 2,
                        (_origin.longitude + _destination.longitude) / 2,
                      ),
                      initialZoom: 13.8,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: isDark
                            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                            : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nalanetra.floodgrid',
                        subdomains: const ['a', 'b', 'c', 'd'],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 6,
                            color: GovColors.navy,
                            borderStrokeWidth: 2,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _vehiclePosition,
                            width: 84,
                            height: 70,
                            child: _RouteVehicleMarker(
                              moving: _navigating,
                              label: en ? 'Crew vehicle' : 'क्रू वाहन',
                            ),
                          ),
                          Marker(
                            point: _destination,
                            width: 190,
                            height: 74,
                            child: _RouteDestinationMarker(
                              label: destinationLabel,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MapChip(
                          icon: Icons.route_outlined,
                          label: '$distanceLabel  •  $etaLabel',
                          isDark: isDark,
                        ),
                        _MapChip(
                          icon: Icons.location_on,
                          label: en ? 'Gurugram' : 'गुरुग्राम',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.76)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _navigating
                                ? Icons.directions_car_filled
                                : Icons.route,
                            color: _navigating
                                ? GovColors.ok
                                : GovColors.severe,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _navigating
                                  ? (en
                                        ? 'Crew vehicle moving to the incident point.'
                                        : 'क्रू वाहन घटना स्थल की ओर बढ़ रहा है।')
                                  : (en
                                        ? 'Follow the blue route. Avoid waterlogged road segments.'
                                        : 'नीले मार्ग का पालन करें। जलभराव वाले मार्ग से बचें।'),
                              style: TextStyle(
                                color: isDark ? Colors.white : GovColors.navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_routeLoading)
                    Positioned(
                      top: 76,
                      left: 14,
                      child: _MapChip(
                        icon: Icons.sync,
                        label: en
                            ? 'Loading road route…'
                            : 'सड़क मार्ग लोड हो रहा है…',
                        isDark: isDark,
                      ),
                    ),
                  if (_routeFromNetwork && !_routeLoading)
                    Positioned(
                      top: 76,
                      left: 14,
                      child: _MapChip(
                        icon: Icons.check_circle_outline,
                        label: en ? 'Live road route' : 'लाइव सड़क मार्ग',
                        isDark: isDark,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startNavigation(store, en),
                icon: Icon(
                  _navigating
                      ? Icons.directions_car_filled
                      : Icons.navigation_outlined,
                ),
                label: Text(
                  _navigating
                      ? (en ? 'NAVIGATION IN PROGRESS' : 'नेविगेशन जारी है')
                      : (en ? 'START NAVIGATION' : 'नेविगेशन शुरू करें'),
                ),
                style: _primaryButtonStyle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteVehicleMarker extends StatelessWidget {
  final bool moving;
  final String label;

  const _RouteVehicleMarker({required this.moving, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: GovColors.navy,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Icon(
          moving ? Icons.local_shipping : Icons.location_on,
          color: GovColors.navy,
          size: 34,
        ),
      ],
    );
  }
}

class _RouteDestinationMarker extends StatelessWidget {
  final String label;
  final bool isDark;

  const _RouteDestinationMarker({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 178),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GovColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Icon(Icons.location_on, color: GovColors.critical, size: 40),
      ],
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final bool isDark;

  _RouteMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = isDark ? Colors.white24 : Colors.white
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    final route = Paint()
      ..color = GovColors.navy
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final blocked = Paint()
      ..color = GovColors.critical.withValues(alpha: 0.72)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final roads = [
      Path()
        ..moveTo(0, size.height * 0.25)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.18,
          size.width,
          size.height * 0.38,
        ),
      Path()
        ..moveTo(size.width * 0.12, size.height)
        ..quadraticBezierTo(
          size.width * 0.28,
          size.height * 0.62,
          size.width * 0.68,
          size.height * 0.48,
        )
        ..quadraticBezierTo(
          size.width * 0.84,
          size.height * 0.40,
          size.width,
          size.height * 0.08,
        ),
      Path()
        ..moveTo(size.width * 0.52, 0)
        ..quadraticBezierTo(
          size.width * 0.48,
          size.height * 0.35,
          size.width * 0.20,
          size.height,
        ),
    ];
    for (final path in roads) {
      canvas.drawPath(path, road);
    }
    final safeRoute = Path()
      ..moveTo(size.width * 0.17, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.66,
        size.width * 0.57,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.43,
        size.width * 0.83,
        size.height * 0.23,
      );
    canvas.drawPath(safeRoute, route);
    canvas.drawLine(
      Offset(size.width * 0.31, size.height * 0.70),
      Offset(size.width * 0.48, size.height * 0.73),
      blocked,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _ProofCaptureSheet extends StatelessWidget {
  final CrewJob job;
  final AppStore store;
  final bool en;
  final bool isDark;
  final VoidCallback onCapture;

  const _ProofCaptureSheet({
    required this.job,
    required this.store,
    required this.en,
    required this.isDark,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final before = job.beforePhotoPath.isNotEmpty
        ? job.beforePhotoPath
        : AppStore.demoFloodImages[0];
    return _BottomSheetSurface(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(isDark: isDark),
          Text(
            en ? 'After Photo & Proof' : 'बाद की फोटो और प्रमाण',
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            en
                ? 'Capture the cleared result at the same location.'
                : 'उसी स्थान पर जलभराव हटने की फोटो लें।',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _EvidencePairTile(
                  label: en ? 'BEFORE' : 'पहले',
                  path: before,
                  color: GovColors.severe,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.grey),
              ),
              Expanded(
                child: Container(
                  height: 112,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: GovColors.navy,
                        size: 30,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        en ? 'AFTER' : 'बाद',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProofChecklist(en: en, isDark: isDark),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(en ? 'CAPTURE AFTER PHOTO' : 'बाद की फोटो लें'),
              style: _primaryButtonStyle(color: GovColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkUpdateSheet extends StatelessWidget {
  final CrewJob job;
  final AppStore store;
  final bool en;
  final bool isDark;
  final VoidCallback onSave;
  final VoidCallback onProof;

  const _WorkUpdateSheet({
    required this.job,
    required this.store,
    required this.en,
    required this.isDark,
    required this.onSave,
    required this.onProof,
  });

  @override
  Widget build(BuildContext context) {
    return _BottomSheetSurface(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(isDark: isDark),
          Text(
            en ? 'Update Mission' : 'मिशन अपडेट करें',
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.location,
            style: TextStyle(
              color: isDark ? Colors.white70 : GovColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _UpdateRow(
            icon: Icons.water_damage_outlined,
            label: en ? 'Water level reduced' : 'पानी का स्तर कम हुआ',
            isDark: isDark,
          ),
          _UpdateRow(
            icon: Icons.cleaning_services_outlined,
            label: en ? 'Drain inlet cleared' : 'नाली का इनलेट साफ हुआ',
            isDark: isDark,
          ),
          _UpdateRow(
            icon: Icons.construction_outlined,
            label: en ? 'High-power pump deployed' : 'हाई-पावर पंप लगाया गया',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Text(
            en
                ? 'Progress: ${job.hasAfterProof ? '100%' : '70%'}'
                : 'प्रगति: ${job.hasAfterProof ? '100%' : '70%'}',
            style: TextStyle(
              color: isDark ? Colors.white : GovColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: job.hasAfterProof ? 1 : 0.7,
            minHeight: 9,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(GovColors.ok),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(en ? 'SAVE PROGRESS' : 'प्रगति सेव करें'),
              style: _primaryButtonStyle(),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onProof,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(en ? 'CAPTURE AFTER PHOTO' : 'बाद की फोटो लें'),
              style: _outlineButtonStyle(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewProfileSheet extends StatelessWidget {
  final AppStore store;
  final CrewMember crew;
  final bool en;
  final bool isDark;

  const _CrewProfileSheet({
    required this.store,
    required this.crew,
    required this.en,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeJobs = store.jobs.where((job) => !job.isDone).length;
    return _BottomSheetSurface(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(isDark: isDark),
          Row(
            children: [
              _CrewAvatar(crew: crew, size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crew.name,
                      style: GoogleFonts.poppins(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      crew.role,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : GovColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(
                      label: en ? 'ON DUTY' : 'ड्यूटी पर',
                      color: GovColors.ok,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _IdentityCard(
            isDark: isDark,
            rows: [
              ('Crew ID', crew.id),
              ('Ward', crew.ward),
              ('Current location', crew.currentLocation),
              ('Contact', AppStore.mcgHelpline),
              ('Active missions', '$activeJobs'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      en
                          ? 'Command Centre contact opened.'
                          : 'कमांड सेंटर संपर्क खोला गया।',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.phone_outlined),
              label: Text(
                en ? 'CONTACT COMMAND CENTRE' : 'कमांड सेंटर से संपर्क करें',
              ),
              style: _outlineButtonStyle(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewSettingsSheet extends StatelessWidget {
  final AppStore store;
  final bool en;
  final bool isDark;
  final VoidCallback onSignOut;

  const _CrewSettingsSheet({
    required this.store,
    required this.en,
    required this.isDark,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return _BottomSheetSurface(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(isDark: isDark),
          Text(
            en ? 'Settings & Support' : 'सेटिंग्स और सहायता',
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: en ? 'Language' : 'भाषा',
            value: en ? 'English / हिंदी' : 'हिंदी / English',
            isDark: isDark,
            onTap: () => store.setLang(en ? AppLang.hi : AppLang.en),
          ),
          _SettingsTile(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            title: en ? 'Theme' : 'थीम',
            value: isDark ? 'Dark' : 'Light',
            isDark: isDark,
            onTap: () =>
                store.setTheme(isDark ? AppThemeMode.light : AppThemeMode.dark),
          ),
          _SettingsTile(
            icon: Icons.location_on_outlined,
            title: en ? 'Location permission' : 'स्थान अनुमति',
            value: en ? 'Allowed' : 'अनुमति है',
            isDark: isDark,
            onTap: () => _showInfo(
              context,
              en
                  ? 'Location is used to confirm mission arrival.'
                  : 'मिशन पहुंच की पुष्टि के लिए स्थान का उपयोग होता है।',
            ),
          ),
          _SettingsTile(
            icon: Icons.camera_alt_outlined,
            title: en ? 'Camera permission' : 'कैमरा अनुमति',
            value: en ? 'Allowed for proof' : 'प्रमाण के लिए अनुमति है',
            isDark: isDark,
            onTap: () => _showInfo(
              context,
              en
                  ? 'Camera is used only for flood and after-proof photos.'
                  : 'कैमरा केवल बाढ़ और बाद के प्रमाण फोटो के लिए है।',
            ),
          ),
          _SettingsTile(
            icon: Icons.menu_book_outlined,
            title: en ? 'Crew User Guide' : 'क्रू यूज़र गाइड',
            value: en
                ? 'Mission steps and evidence rules'
                : 'मिशन चरण और प्रमाण नियम',
            isDark: isDark,
            onTap: () => _showInfo(
              context,
              en
                  ? 'Open a mission, confirm arrival, capture evidence, and submit proof.'
                  : 'मिशन खोलें, पहुंच की पुष्टि करें, प्रमाण लें और जमा करें।',
            ),
          ),
          _SettingsTile(
            icon: Icons.support_agent_outlined,
            title: en ? 'Contact Command Centre' : 'कमांड सेंटर से संपर्क',
            value: AppStore.mcgHelpline,
            isDark: isDark,
            onTap: () => _showInfo(
              context,
              en
                  ? 'Official MCG helpline: ${AppStore.mcgHelpline}'
                  : 'आधिकारिक MCG हेल्पलाइन: ${AppStore.mcgHelpline}',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, color: GovColors.critical),
              label: Text(
                en ? 'SIGN OUT' : 'साइन आउट',
                style: const TextStyle(color: GovColors.critical),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: GovColors.critical),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(en ? 'Crew Support' : 'क्रू सहायता'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(en ? 'CLOSE' : 'बंद करें'),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final bool isDark;
  final List<(String, String)> rows;

  const _IdentityCard({required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1D2C50), const Color(0xFF101B36)]
              : [const Color(0xFFF3F7FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GovColors.gold.withValues(alpha: 0.38)),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.$1,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isDark ? Colors.white : GovColors.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: GovColors.navy),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CrewAvatar extends StatelessWidget {
  final CrewMember crew;
  final double size;

  const _CrewAvatar({required this.crew, required this.size});

  @override
  Widget build(BuildContext context) {
    final path = crew.avatarPath;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: GovColors.gold,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: path == null
            ? const ColoredBox(
                color: GovColors.navy,
                child: Icon(Icons.engineering, color: Colors.white),
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: GovColors.navy,
                  child: Icon(Icons.engineering, color: Colors.white),
                ),
              ),
      ),
    );
  }
}

class _EvidenceImage extends StatelessWidget {
  final String path;

  const _EvidenceImage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: GovColors.navy.withValues(alpha: 0.10),
      child: const Center(
        child: Icon(
          Icons.water_damage_outlined,
          color: GovColors.navy,
          size: 42,
        ),
      ),
    );
    if (path.startsWith('/')) {
      return Image.file(
        File(path),
        key: ValueKey(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.asset(
      path,
      key: ValueKey(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _EvidencePairTile extends StatelessWidget {
  final String label;
  final String path;
  final Color color;

  const _EvidencePairTile({
    required this.label,
    required this.path,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _EvidenceImage(path: path),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofChecklist extends StatelessWidget {
  final bool en;
  final bool isDark;

  const _ProofChecklist({required this.en, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final labels = [
      en ? 'Same location and GPS confirmed' : 'उसी स्थान और GPS की पुष्टि',
      en ? 'Work area visible' : 'कार्य क्षेत्र दिखाई दे',
      en ? 'No person in evidence frame' : 'प्रमाण फोटो में कोई व्यक्ति नहीं',
    ];
    return Column(
      children: labels
          .map(
            (label) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: GovColors.ok, size: 17),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _UpdateRow({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: GovColors.navy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : GovColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.check_circle, color: GovColors.ok, size: 19),
        ],
      ),
    );
  }
}

class _BottomSheetSurface extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _BottomSheetSurface({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        decoration: BoxDecoration(
          color: isDark ? GovColors.bgDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: child,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final bool isDark;

  const _SheetHandle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _InfoPanel({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : GovColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: GovColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isDark ? Colors.white : GovColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool isDark;

  const _MetaText({
    required this.icon,
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white70 : color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white70 : color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _MapChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: GovColors.navy),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : GovColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _MapPin({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black87 : Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : GovColors.navy,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Icon(Icons.location_on, color: color, size: 32),
      ],
    );
  }
}

String _relativeTime(DateTime time) {
  final minutes = DateTime.now().difference(time).inMinutes;
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  return '${hours}h ago';
}

Color _notificationColor(NotifKind kind) {
  return switch (kind) {
    NotifKind.emergency || NotifKind.escalation => GovColors.critical,
    NotifKind.assignment || NotifKind.crewAssigned => GovColors.navy,
    NotifKind.verified => GovColors.ok,
    NotifKind.rejected => GovColors.severe,
    _ => GovColors.gold,
  };
}

IconData _notificationIcon(NotifKind kind) {
  return switch (kind) {
    NotifKind.emergency || NotifKind.escalation => Icons.warning_amber_rounded,
    NotifKind.assignment ||
    NotifKind.crewAssigned => Icons.assignment_turned_in_outlined,
    NotifKind.verified => Icons.verified_outlined,
    NotifKind.rejected => Icons.replay_outlined,
    _ => Icons.info_outline,
  };
}

ButtonStyle _primaryButtonStyle({Color color = GovColors.navy}) {
  return ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
  );
}

ButtonStyle _outlineButtonStyle(bool isDark) {
  return OutlinedButton.styleFrom(
    foregroundColor: isDark ? Colors.white : GovColors.navy,
    side: BorderSide(
      color: isDark ? Colors.white54 : GovColors.navy,
      width: 1.4,
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
  );
}
