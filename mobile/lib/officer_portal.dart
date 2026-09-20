import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:io';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

// ---------------------------------------------------------------------------
// HIGH-FIDELITY MUNICIPAL COMMAND CENTRE (Officer Portal)
// ---------------------------------------------------------------------------

Widget _portalEvidenceImage(
  String? path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  final resolved = path?.trim() ?? '';
  if (resolved.isEmpty) {
    return _missingPortalEvidence(width: width, height: height);
  }
  final fallback = _missingPortalEvidence(width: width, height: height);
  if (resolved.startsWith('/')) {
    return Image.file(
      File(resolved),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
    return Image.network(
      resolved,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  return Image.asset(
    resolved,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => fallback,
  );
}

Widget _missingPortalEvidence({double? width, double? height}) {
  return Container(
    width: width,
    height: height,
    color: Colors.blueGrey.withOpacity(0.12),
    alignment: Alignment.center,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined, color: Colors.blueGrey),
        SizedBox(height: 4),
        Text(
          'No field photo attached',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey, fontSize: 11),
        ),
      ],
    ),
  );
}

class OfficerPortal extends StatefulWidget {
  const OfficerPortal({super.key});
  @override
  State<OfficerPortal> createState() => _OfficerPortalState();
}

class _OfficerPortalState extends State<OfficerPortal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF8FAFC),
      appBar: GovHeader(
        title: en ? 'Command Centre' : 'कमांड सेंटर',
        subtitle: en
            ? 'Municipal Response Management'
            : 'नगर निगम प्रतिक्रिया प्रबंधन',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: GovColors.gold,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.analytics, size: 20),
              text: en ? 'Overview' : 'अवलोकन',
            ),
            Tab(
              icon: const Icon(Icons.assignment_ind, size: 20),
              text: en ? 'Dispatch' : 'डिस्पैच',
            ),
            Tab(
              icon: const Icon(Icons.verified, size: 20),
              text: en ? 'Verify' : 'वेरिफाई',
            ),
            Tab(
              icon: const Icon(Icons.inventory, size: 20),
              text: en ? 'Inventory' : 'इन्वेंट्री',
            ),
            Tab(
              icon: const Icon(Icons.groups, size: 20),
              text: en ? 'Crew Control' : 'क्रू कंट्रोल',
            ),
            Tab(
              icon: const Icon(Icons.rss_feed, size: 20),
              text: en ? 'Broadcast' : 'प्रसारण',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(isDark: isDark, store: store, en: en),
          _IncidentsTab(isDark: isDark, store: store, en: en),
          _VerifyTab(isDark: isDark, store: store, en: en),
          _ResourcesTab(isDark: isDark, store: store, en: en),
          _CrewControlTab(isDark: isDark, store: store, en: en),
          _BroadcastTab(isDark: isDark, store: store, en: en),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  final bool en;
  const _DashboardTab({
    required this.isDark,
    required this.store,
    required this.en,
  });

  @override
  Widget build(BuildContext context) {
    final active = store.reports
        .where(
          (r) => store.statusOf(r.incidentId) != IncidentLifecycle.verified,
        )
        .length;
    final verified = store.reports
        .where(
          (r) => store.statusOf(r.incidentId) == IncidentLifecycle.verified,
        )
        .length;
    final liveFeed = store.notificationsFor(Portal.officer).take(10).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/operations'),
          icon: const Icon(Icons.hub_outlined),
          label: Text(
            en ? 'Open scalable operations' : 'स्केलेबल संचालन खोलें',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: GovColors.navy,
            side: const BorderSide(color: GovColors.navy),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          ),
        ),
        const SizedBox(height: 14),
        // 1. KPI Stats Row
        Row(
          children: [
            _KpiCard(
              label: en ? 'Critical' : 'गंभीर',
              value:
                  '${store.reports.where((r) => r.priorityScore(store.reports) > 0.8).length}',
              color: GovColors.critical,
              isDark: isDark,
              trend: '+5%',
            ),
            _KpiCard(
              label: en ? 'Active' : 'सक्रिय',
              value: '$active',
              color: GovColors.severe,
              isDark: isDark,
              trend: '+12%',
            ),
            _KpiCard(
              label: en ? 'Verified' : 'सत्यापित',
              value: '$verified',
              color: GovColors.ok,
              isDark: isDark,
              trend: '+8%',
            ),
            _KpiCard(
              label: en ? 'Crews' : 'क्रू',
              value: '${AppStore.crewRoster.length}',
              color: GovColors.navy,
              isDark: isDark,
              trend:
                  '${AppStore.crewRoster.where((crew) => !crew.offDuty).length} on duty',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Heatmap & Live Feed Row (High-Fidelity)
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final gap = narrow ? 0.0 : 16.0;
            final heatmapWidth = narrow
                ? constraints.maxWidth
                : constraints.maxWidth * .6 - gap / 2;
            final liveFeedWidth = narrow
                ? constraints.maxWidth
                : constraints.maxWidth * .4 - gap / 2;
            return Wrap(
              spacing: gap,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: heatmapWidth,
                  child: _ChartContainer(
                    title: en
                        ? 'City-wide Flood Heatmap'
                        : 'शहर-व्यापी बाढ़ हीटमैप',
                    isDark: isDark,
                    child: Container(
                      height: narrow ? 320 : 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? Colors.black26 : Colors.grey[100],
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: GovColors.critical.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    en ? 'LIVE SENSORS' : 'लाइव सेंसर',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final reports = store.reports.take(6).toList();
                                if (reports.isEmpty) {
                                  return Center(
                                    child: Text(
                                      en
                                          ? 'No live incidents'
                                          : 'कोई लाइव घटना नहीं',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: reports.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        mainAxisExtent: narrow ? 74 : 50,
                                      ),
                                  itemBuilder: (context, imageIndex) {
                                    final report = reports[imageIndex];
                                    final image =
                                        AppStore
                                            .heatmapLiveFeedImages[imageIndex %
                                            AppStore
                                                .heatmapLiveFeedImages
                                                .length];
                                    final priority = report.priorityScore(
                                      store.reports,
                                    );
                                    final location = report.locationName
                                        .split(' ')
                                        .take(2)
                                        .join(' ');
                                    final severityColor = priority > 0.8
                                        ? GovColors.critical
                                        : GovColors.gold;
                                    return GestureDetector(
                                      onTap: () => _showIncidentDetails(
                                        context,
                                        report,
                                        en,
                                        isDark,
                                        imageOverride: image,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            _evidenceImage(
                                              image,
                                              width: narrow ? 160 : 100,
                                              height: narrow ? 74 : 50,
                                            ),
                                            Positioned(
                                              top: 5,
                                              right: 5,
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: severityColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 5,
                                              right: 5,
                                              bottom: 5,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  location,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: liveFeedWidth,
                  child: _ChartContainer(
                    title: en ? 'Live Feed' : 'लाइव फीड',
                    isDark: isDark,
                    child: SizedBox(
                      height: narrow ? 430 : 270,
                      child: ListView.builder(
                        itemCount: liveFeed.length,
                        itemBuilder: (context, i) {
                          final n = liveFeed[i];
                          final feedImage =
                              AppStore.heatmapLiveFeedImages[i %
                                  AppStore.heatmapLiveFeedImages.length];
                          final targetIncidentId =
                              n.assignmentIncidentId ?? n.incidentId;
                          final activeJob = targetIncidentId == null
                              ? null
                              : store.jobFor(targetIncidentId);
                          final alreadyAssigned =
                              activeJob != null && !activeJob.isDone;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: () => _showNotificationDetails(
                                context,
                                n,
                                en,
                                isDark,
                                imageOverride: feedImage,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 4,
                                    height: 76,
                                    color: _getNotifColor(n.kind),
                                  ),
                                  const SizedBox(width: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: _evidenceImage(
                                      feedImage,
                                      width: 88,
                                      height: 72,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          en ? n.titleEn : n.titleHi,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (n.locationName?.isNotEmpty == true)
                                          Text(
                                            n.locationName!,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isDark
                                                  ? Colors.white70
                                                  : GovColors.navy,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (n.severityBand != null &&
                                            n.severityScore != null)
                                          Text(
                                            'AI ${(n.severityScore! * 100).round()}% • ${severityOf(n.severityBand!).label}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: severityOf(n.severityBand!)
                                                  .color,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        if (n.reporterName?.trim().isNotEmpty ==
                                                true ||
                                            n.reportCount != null)
                                          Text(
                                            '${n.reporterName?.trim().isNotEmpty == true ? n.reporterName!.trim() : (en ? 'Citizen report' : 'नागरिक रिपोर्ट')} • ${n.reportCount ?? 1} ${en ? 'similar reports' : 'मिलती-जुलती रिपोर्ट'}',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${DateTime.now().difference(n.at).inMinutes}m ago',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            SizedBox(
                                              height: 28,
                                              child: ElevatedButton.icon(
                                                onPressed:
                                                    targetIncidentId == null ||
                                                        alreadyAssigned
                                                    ? null
                                                    : () =>
                                                          _showDispatchCrewPicker(
                                                            context,
                                                            store,
                                                            targetIncidentId,
                                                            en,
                                                          ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      alreadyAssigned
                                                      ? GovColors.ok
                                                      : GovColors.navy,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 0,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                icon: Icon(
                                                  alreadyAssigned
                                                      ? Icons
                                                            .check_circle_outline
                                                      : Icons.groups_outlined,
                                                  size: 13,
                                                ),
                                                label: Text(
                                                  alreadyAssigned
                                                      ? (en
                                                            ? 'ASSIGNED'
                                                            : 'असाइन')
                                                      : (en
                                                            ? 'ASSIGN CREW'
                                                            : 'क्रू असाइन'),
                                                  style: const TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
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
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // 3. Response Trend Chart (Truly Dynamic)
        _ChartContainer(
          title: en
              ? 'Response Efficiency (Live)'
              : 'प्रतिक्रिया दक्षता (लाइव)',
          isDark: isDark,
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final time = DateTime.now().subtract(
                          Duration(hours: 6 - val.toInt()),
                        );
                        return Text(
                          '${time.hour}:00',
                          style: TextStyle(
                            fontSize: 8,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: store.responseEfficiency
                        .asMap()
                        .entries
                        .map(
                          (entry) => FlSpot(entry.key.toDouble(), entry.value),
                        )
                        .toList(),
                    isCurved: true,
                    color: GovColors.gold,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: GovColors.gold.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Distribution Chart
        Row(
          children: [
            Expanded(
              child: _ChartContainer(
                title: en ? 'Severity Distribution' : 'गंभीरता वितरण',
                isDark: isDark,
                child: _SeverityDistribution(
                  store: store,
                  en: en,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChartContainer(
                title: en ? 'Weather Context' : 'मौसम संदर्भ',
                isDark: isDark,
                child: _WeatherStationsPanel(
                  store: store,
                  en: en,
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _evidenceImage(String? path, {double? width, double? height}) {
    final resolved = path?.trim() ?? '';
    if (resolved.isEmpty) {
      return _missingPortalEvidence(width: width, height: height);
    }
    final fallback = _missingPortalEvidence(width: width, height: height);
    if (resolved.startsWith('/')) {
      return Image.file(
        File(resolved),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.asset(
      resolved,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  void _showNotificationDetails(
    BuildContext context,
    Notif notification,
    bool en,
    bool isDark, {
    String? imageOverride,
  }) {
    // Municipal alerts are flood/action evidence only, never a proof gallery.
    final galleryImages = <String?>[
      imageOverride ?? notification.imageFor(NotifAudience.municipal),
    ];
    int page = 0;
    final hostContext = context;
    final targetIncidentId =
        notification.assignmentIncidentId ?? notification.incidentId;
    final activeJob = targetIncidentId == null
        ? null
        : store.jobFor(targetIncidentId);
    final alreadyAssigned = activeJob != null && !activeJob.isDone;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? GovColors.cardDark : Colors.white,
          title: Text(
            en ? 'Live Alert' : 'लाइव अलर्ट',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: PageView.builder(
                      itemCount: galleryImages.length,
                      onPageChanged: (value) => setState(() => page = value),
                      itemBuilder: (_, index) => _evidenceImage(
                        galleryImages[index],
                        width: double.infinity,
                        height: 250,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    galleryImages.length,
                    (index) => Container(
                      width: index == page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == page ? GovColors.gold : Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  en ? notification.titleEn : notification.titleHi,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (notification.locationName?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    en
                        ? 'Location: ${notification.locationName}'
                        : 'स्थान: ${notification.locationName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GovColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (notification.severityBand != null &&
                    notification.severityScore != null)
                  Text(
                    en
                        ? 'Severity: ${severityOf(notification.severityBand!).label} • ${(notification.severityScore! * 100).round()}%'
                        : 'गंभीरता: ${severityOf(notification.severityBand!).label} • ${(notification.severityScore! * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: severityOf(notification.severityBand!).color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  en
                      ? 'Received ${DateTime.now().difference(notification.at).inMinutes} minutes ago'
                      : '${DateTime.now().difference(notification.at).inMinutes} मिनट पहले प्राप्त',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (notification.reporterName?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    en
                        ? 'Reported by: ${notification.reporterName!.trim()}'
                        : 'रिपोर्टर: ${notification.reporterName!.trim()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (notification.reportCount != null)
                  Text(
                    en
                        ? 'Same-location reports: ${notification.reportCount}'
                        : 'इसी स्थान की रिपोर्ट: ${notification.reportCount}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (targetIncidentId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    en
                        ? 'Incident: $targetIncidentId'
                        : 'घटना: $targetIncidentId',
                    style: const TextStyle(
                      fontSize: 11,
                      color: GovColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (targetIncidentId != null)
              ElevatedButton.icon(
                onPressed: alreadyAssigned
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _showDispatchCrewPicker(
                          hostContext,
                          store,
                          targetIncidentId,
                          en,
                        );
                      },
                icon: Icon(
                  alreadyAssigned
                      ? Icons.check_circle_outline
                      : Icons.groups_outlined,
                ),
                label: Text(
                  alreadyAssigned
                      ? (en ? 'ASSIGNED' : 'असाइन है')
                      : (en ? 'ASSIGN CREW' : 'क्रू असाइन करें'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: alreadyAssigned
                      ? GovColors.ok
                      : GovColors.navy,
                  foregroundColor: Colors.white,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(en ? 'CLOSE' : 'बंद करें'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIncidentDetails(
    BuildContext context,
    FloodReport report,
    bool en,
    bool isDark, {
    String? imageOverride,
  }) {
    // Incident review in the command centre shows the submitted flood photo
    // only; cleanup evidence belongs to the proof-review flow.
    final galleryImages = <String?>[imageOverride ?? report.photoPath];
    final score = (report.priorityScore(store.reports) * 100).round();
    int page = 0;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? GovColors.cardDark : Colors.white,
          title: Text(
            report.locationName,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: PageView.builder(
                      itemCount: galleryImages.length,
                      onPageChanged: (value) => setState(() => page = value),
                      itemBuilder: (_, index) => _evidenceImage(
                        galleryImages[index],
                        width: double.infinity,
                        height: 280,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    galleryImages.length,
                    (index) => Container(
                      width: index == page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == page ? GovColors.gold : Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  en
                      ? 'Incident ${report.incidentId}'
                      : 'घटना ${report.incidentId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  en
                      ? report.severitySummary
                      : 'AI द्वारा गंभीरता का आकलन पूरा',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  en
                      ? 'AI priority score: $score%'
                      : 'AI प्राथमिकता स्कोर: $score%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GovColors.critical,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  en
                      ? 'GPS: ${report.lat.toStringAsFixed(4)}, ${report.lon.toStringAsFixed(4)}'
                      : 'GPS: ${report.lat.toStringAsFixed(4)}, ${report.lon.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(en ? 'CLOSE' : 'बंद करें'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNotifColor(NotifKind kind) {
    switch (kind) {
      case NotifKind.emergency:
        return GovColors.critical;
      case NotifKind.weather:
        return Colors.blue;
      case NotifKind.verified:
        return GovColors.ok;
      default:
        return GovColors.gold;
    }
  }
}

class _IncidentsTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  final bool en;
  const _IncidentsTab({
    required this.isDark,
    required this.store,
    required this.en,
  });

  @override
  Widget build(BuildContext context) {
    final list = store.priorityQueue().where((r) {
      // Dispatch must show unassigned incidents and already-active assignments;
      // only verified/closed work leaves this queue.
      return store.statusOf(r.incidentId) != IncidentLifecycle.verified;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final report = list[index];
        final activeJob = store.jobFor(report.incidentId);
        final isDispatched =
            activeJob != null &&
            activeJob.status != IncidentLifecycle.submitted &&
            activeJob.status != IncidentLifecycle.merged &&
            activeJob.status != IncidentLifecycle.verified;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: report.priorityScore(store.reports) > 0.8
                  ? GovColors.critical.withOpacity(0.3)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: GovColors.critical.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PRIORITY: ${(report.priorityScore(store.reports) * 100).toInt()}%',
                                style: const TextStyle(
                                  color: GovColors.critical,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              report.id,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          report.locationName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          en
                              ? report.severitySummary
                              : 'AI द्वारा निर्धारित: गंभीर जलभराव',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (activeJob != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.groups,
                                size: 13,
                                color: activeJob.status.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${activeJob.crewName} • ${activeJob.status.label}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: activeJob.status.color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _portalEvidenceImage(
                      AppStore.dispatchFloodImages[index %
                          AppStore.dispatchFloodImages.length],
                      width: 112,
                      height: 112,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.people, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    en
                        ? '${(report.lat * 100).toInt() % 15 + 2} Reports Merged'
                        : '${(report.lat * 100).toInt() % 15 + 2} रिपोर्टें मर्ज की गईं',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: isDispatched
                        ? null
                        : () => _showDispatchCrewPicker(
                            context,
                            store,
                            report.incidentId,
                            en,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDispatched
                          ? Colors.grey
                          : GovColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isDispatched
                          ? (en ? 'ASSIGNED' : 'असाइन किया गया')
                          : (en ? 'DISPATCH' : 'भेजें'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VerifyTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  final bool en;
  const _VerifyTab({
    required this.isDark,
    required this.store,
    required this.en,
  });

  void _showJobEvidence(BuildContext context, CrewJob job) {
    final images = <String?>[job.beforePhotoPath];
    if (job.hasAfterProof) {
      images.add(job.afterPhotoPath);
    } else if (job.pendingPreviewPath?.trim().isNotEmpty == true) {
      images.add(job.pendingPreviewPath);
    }
    int page = 0;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? GovColors.cardDark : Colors.white,
          title: Text(
            job.location,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (value) => setState(() => page = value),
                    itemBuilder: (_, index) => _portalEvidenceImage(
                      images[index],
                      width: double.infinity,
                      height: 300,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    width: index == page ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == page ? GovColors.gold : Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                job.hasAfterProof
                    ? (en
                          ? 'Swipe to compare BEFORE and AFTER evidence'
                          : 'पहले और बाद के प्रमाण देखने के लिए स्वाइप करें')
                    : (en
                          ? 'AFTER photo is pending from the field crew'
                          : 'फील्ड क्रू की AFTER तस्वीर लंबित है'),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = store.jobs
        .where((j) => j.status == IncidentLifecycle.onSite)
        .toList();

    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              en ? 'All incidents verified' : 'सभी घटनाएं सत्यापित हैं',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final job = pending[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.location,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showJobEvidence(context, job),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'BEFORE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _portalEvidenceImage(
                              job.beforePhotoPath,
                              height: 160,
                              width: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            job.hasAfterProof ? 'AFTER' : 'AFTER • PENDING',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _portalEvidenceImage(
                              job.hasAfterProof
                                  ? job.afterPhotoPath
                                  : job.pendingPreviewPath,
                              height: 160,
                              width: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        store.updateJobStatus(
                          job.incidentId,
                          IncidentLifecycle.dispatched,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Re-dispatching for rework...'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GovColors.critical,
                        side: const BorderSide(color: GovColors.critical),
                      ),
                      child: Text(en ? 'REJECT' : 'अस्वीकार'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: job.hasAfterProof
                          ? () {
                              store.verifyIncident(job.incidentId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Verified and Closed!'),
                                  backgroundColor: GovColors.ok,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: job.hasAfterProof
                            ? GovColors.ok
                            : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(en ? 'VERIFY' : 'सत्यापित'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeverityDistribution extends StatelessWidget {
  final AppStore store;
  final bool en;
  final bool isDark;

  const _SeverityDistribution({
    required this.store,
    required this.en,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <SeverityBand, int>{
      for (final band in SeverityBand.values)
        band: store.reports.where((report) => report.band == band).length,
    };
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final sections = severityMetas.map((meta) {
      final count = counts[meta.band] ?? 0;
      return PieChartSectionData(
        value: count == 0 ? 0.001 : count.toDouble(),
        color: meta.color,
        radius: 38,
        showTitle: false,
      );
    }).toList();

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 132,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 31,
                      sectionsSpace: 3,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: severityMetas.map((meta) {
                      final count = counts[meta.band] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: meta.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                en ? meta.label : _severityHindi(meta.band),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              en
                  ? '$total active reports in current register'
                  : 'वर्तमान रजिस्टर में $total रिपोर्ट',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _severityHindi(SeverityBand band) {
    switch (band) {
      case SeverityBand.critical:
        return 'गंभीर';
      case SeverityBand.severe:
        return 'अति गंभीर';
      case SeverityBand.moderate:
        return 'मध्यम';
      case SeverityBand.minor:
        return 'कम';
    }
  }
}

class _WeatherStationsPanel extends StatelessWidget {
  final AppStore store;
  final bool en;
  final bool isDark;

  const _WeatherStationsPanel({
    required this.store,
    required this.en,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final observations = store.weatherObservations;
    final current = observations
        .where((item) => item.location.name == store.selectedLocation.name)
        .firstOrNull;
    final lastUpdated =
        store.weatherLastUpdatedAt ?? store.weatherStationsUpdatedAt;
    final summary = current == null
        ? (store.weatherReady
              ? '${store.weatherTemp.toStringAsFixed(1)}°C • ${store.rainRate.toStringAsFixed(1)} mm/h'
              : (en
                    ? 'Live observation unavailable'
                    : 'लाइव ऑब्जर्वेशन उपलब्ध नहीं'))
        : '${current.temperatureC.toStringAsFixed(1)}°C • ${current.rainMmPerHour.toStringAsFixed(1)} mm/h';
    return SizedBox(
      height: 292,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                store.weatherReady ? Icons.cloud_done : Icons.cloud_off,
                color: store.weatherReady ? GovColors.ok : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: en ? 'Refresh weather' : 'मौसम रिफ्रेश करें',
                onPressed: store.weatherStationsLoading
                    ? null
                    : store.refreshWeatherStations,
                icon: store.weatherStationsLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
              ),
            ],
          ),
          if (store.weatherStationsError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                en
                    ? store.weatherStationsError!
                    : 'OpenWeather डेटा अभी उपलब्ध नहीं है — Retry दबाएं',
                style: const TextStyle(color: GovColors.critical, fontSize: 9),
              ),
            ),
          if (lastUpdated != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                en
                    ? 'Last updated ${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}${store.weatherUsingStationFallback ? ' • nearest station' : ''}'
                    : 'अंतिम अपडेट ${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}${store.weatherUsingStationFallback ? ' • नजदीकी स्टेशन' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 9),
              ),
            ),
          if (store.weatherStationsError != null &&
              !store.weatherStationsLoading)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: store.refreshWeatherStations,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(en ? 'Retry now' : 'अभी Retry करें'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          const SizedBox(height: 5),
          Expanded(
            child: observations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          en
                              ? 'No live station data returned'
                              : 'लाइव स्टेशन डेटा नहीं मिला',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: store.weatherStationsLoading
                              ? null
                              : store.refreshWeatherStations,
                          icon: const Icon(Icons.refresh, size: 14),
                          label: Text(en ? 'Retry' : 'फिर कोशिश करें'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: observations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = observations[index];
                      final label = item.location.name.split('—').first.trim();
                      final icon = item.isRaining
                          ? Icons.umbrella
                          : Icons.wb_cloudy;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: item.isRaining
                                  ? GovColors.gold
                                  : Colors.blueGrey,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${item.rainMmPerHour.toStringAsFixed(1)} mm/h rain • ${item.windSpeedMs.toStringAsFixed(1)} m/s wind',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.observedAt.hour.toString().padLeft(2, '0')}:${item.observedAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  final bool en;
  const _ResourcesTab({
    required this.isDark,
    required this.store,
    required this.en,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: store.resources.length,
      itemBuilder: (context, index) {
        final res = store.resources[index];
        final percent = res.active / res.total;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(res.color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory, color: Color(res.color)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      en ? res.nameEn : res.nameHi,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.grey[200],
                      color: Color(res.color),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${res.active}/${res.total}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    en ? 'IN USE' : 'उपयोग में',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _crewAvatar(CrewMember member, {double radius = 24}) {
  final path = member.avatarPath;
  if (path != null && path.isNotEmpty) {
    return ClipOval(
      child: Image.asset(
        path,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _crewInitialsAvatar(member, radius),
      ),
    );
  }
  return _crewInitialsAvatar(member, radius);
}

Widget _crewInitialsAvatar(CrewMember member, double radius) {
  final initials = member.name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
  return CircleAvatar(
    radius: radius,
    backgroundColor: GovColors.navy,
    child: Text(
      initials.isEmpty ? 'MCG' : initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: radius * 0.38,
      ),
    ),
  );
}

class _CrewControlTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  final bool en;

  const _CrewControlTab({
    required this.isDark,
    required this.store,
    required this.en,
  });

  @override
  Widget build(BuildContext context) {
    final activeJobs = store.jobs.where((job) => !job.isDone).toList();
    final assigned = AppStore.crewRoster.where((member) {
      return activeJobs.any((job) => job.crewName == member.id);
    }).length;
    final onSite = activeJobs.where((job) {
      return job.status == IncidentLifecycle.onSite ||
          job.status == IncidentLifecycle.workProgress;
    }).length;
    final available = AppStore.crewRoster.where((member) {
      return !member.offDuty &&
          !activeJobs.any((job) => job.crewName == member.id);
    }).length;
    final offDuty = AppStore.crewRoster
        .where((member) => member.offDuty)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          en ? 'MCG Crew Control' : 'एमसीजी क्रू कंट्रोल',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          en
              ? 'Operational roster, live assignments and response coordination'
              : 'ऑपरेशनल रोस्टर, लाइव असाइनमेंट और प्रतिक्रिया समन्वय',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RosterMetric(
              label: en ? 'TOTAL CREW' : 'कुल क्रू',
              value: '${AppStore.crewRoster.length}',
              color: GovColors.navy,
              isDark: isDark,
            ),
            _RosterMetric(
              label: en ? 'ASSIGNED' : 'असाइन',
              value: '$assigned',
              color: GovColors.severe,
              isDark: isDark,
            ),
            _RosterMetric(
              label: en ? 'ON SITE' : 'साइट पर',
              value: '$onSite',
              color: GovColors.onSite,
              isDark: isDark,
            ),
            _RosterMetric(
              label: en ? 'AVAILABLE' : 'उपलब्ध',
              value: '$available',
              color: GovColors.ok,
              isDark: isDark,
            ),
            _RosterMetric(
              label: en ? 'OFF DUTY' : 'ड्यूटी से बाहर',
              value: '$offDuty',
              color: Colors.grey,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : const Color(0xFFF2F6FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GovColors.navy.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance, color: GovColors.navy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      en ? 'MCG Control Room' : 'एमसीजी कंट्रोल रूम',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      en
                          ? 'Official helpline • ${AppStore.mcgHelpline}'
                          : 'आधिकारिक हेल्पलाइन • ${AppStore.mcgHelpline}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _callMcgControlRoom(context, en),
                icon: const Icon(Icons.call, size: 16),
                label: Text(en ? 'CONTACT' : 'संपर्क'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...AppStore.crewRoster.map((member) {
          final memberJobs = activeJobs
              .where((job) => job.crewName == member.id)
              .toList();
          final currentJob = memberJobs.isEmpty ? null : memberJobs.first;
          final status = member.offDuty
              ? (en ? 'OFF DUTY' : 'ड्यूटी से बाहर')
              : currentJob == null
              ? (en ? 'AVAILABLE' : 'उपलब्ध')
              : currentJob.status.label;
          final statusColor = member.offDuty
              ? Colors.grey
              : currentJob == null
              ? GovColors.ok
              : currentJob.status.color;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? GovColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _showCrewIdentityCard(context, store, member, en),
                      child: _crewAvatar(member, radius: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _showCrewIdentityCard(
                              context,
                              store,
                              member,
                              en,
                            ),
                            child: Text(
                              member.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${member.id} • ${member.role} • ${member.ward}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: en ? 'View identity card' : 'पहचान कार्ड देखें',
                      onPressed: () =>
                          _showCrewIdentityCard(context, store, member, en),
                      icon: const Icon(
                        Icons.badge_outlined,
                        color: GovColors.navy,
                      ),
                    ),
                    IconButton(
                      tooltip: en
                          ? 'Call MCG control room'
                          : 'एमसीजी कंट्रोल रूम कॉल करें',
                      onPressed: () => _callMcgControlRoom(context, en),
                      icon: const Icon(
                        Icons.phone_in_talk,
                        color: GovColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  color: isDark ? Colors.white10 : const Color(0xFFF7F8FB),
                  child: Text(
                    en
                        ? 'Current location: ${currentJob?.location ?? member.currentLocation}'
                        : 'वर्तमान स्थान: ${currentJob?.location ?? member.currentLocation}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (currentJob != null) ...[
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      en
                          ? 'Dispatch ${_elapsedLabel(currentJob.dispatchedAt)} ago • ETA ${member.etaMinutes} min'
                          : '${_elapsedLabel(currentJob.dispatchedAt)} पहले रवाना • ETA ${member.etaMinutes} मिनट',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
                if (!member.offDuty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: currentJob == null
                        ? ElevatedButton.icon(
                            onPressed: () => _showCrewDispatchDialog(
                              context,
                              store,
                              member,
                              en,
                            ),
                            icon: const Icon(Icons.near_me, size: 15),
                            label: Text(
                              en ? 'ASSIGN INCIDENT' : 'घटना असाइन करें',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GovColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _showCrewDispatchDialog(
                              context,
                              store,
                              member,
                              en,
                            ),
                            icon: const Icon(Icons.swap_horiz, size: 15),
                            label: Text(en ? 'VIEW QUEUE' : 'क्यू देखें'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _RosterMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _RosterMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 106,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _elapsedLabel(DateTime when) {
  final minutes = DateTime.now().difference(when).inMinutes.clamp(0, 9999);
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
}

void _showCrewIdentityCard(
  BuildContext context,
  AppStore store,
  CrewMember member,
  bool en,
) {
  CrewJob? activeJob;
  for (final job in store.jobs) {
    if (job.crewName == member.id && !job.isDone) {
      activeJob = job;
      break;
    }
  }
  final shiftStarted = DateTime.now().subtract(
    Duration(minutes: member.shiftStartedMinutesAgo),
  );
  final startedAt = activeJob?.dispatchedAt ?? shiftStarted;
  final status = member.offDuty
      ? (en ? 'OFF DUTY' : 'ड्यूटी से बाहर')
      : activeJob == null
      ? (en ? 'AVAILABLE' : 'उपलब्ध')
      : activeJob.status.label;
  final statusColor = member.offDuty
      ? Colors.grey
      : activeJob == null
      ? GovColors.ok
      : activeJob.status.color;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _crewAvatar(member, radius: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          member.id,
                          style: const TextStyle(
                            color: GovColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  en
                      ? 'MCG FIELD PERSONNEL IDENTITY'
                      : 'एमसीजी फील्ड कर्मी पहचान',
                  style: const TextStyle(
                    color: GovColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _identityRow(en ? 'Role' : 'भूमिका', member.role),
              _identityRow(en ? 'Ward' : 'वार्ड', member.ward),
              _identityRow(
                en ? 'Contact' : 'संपर्क',
                '+91 ${member.contactNumber} (MCG control room)',
              ),
              _identityRow(
                en ? 'Current location' : 'वर्तमान स्थान',
                activeJob?.location ?? member.currentLocation,
              ),
              _identityRow(
                en ? 'On shift since' : 'ड्यूटी शुरू',
                '${shiftStarted.hour.toString().padLeft(2, '0')}:${shiftStarted.minute.toString().padLeft(2, '0')} • ${_elapsedLabel(shiftStarted)} ago',
              ),
              _identityRow(
                en ? 'Dispatch time' : 'रवाना समय',
                activeJob == null
                    ? (en ? 'Not assigned' : 'अभी असाइन नहीं')
                    : '${activeJob.dispatchedAt.hour.toString().padLeft(2, '0')}:${activeJob.dispatchedAt.minute.toString().padLeft(2, '0')} • ${_elapsedLabel(activeJob.dispatchedAt)} ago',
              ),
              _identityRow(
                en ? 'Expected completion' : 'अनुमानित पूरा समय',
                activeJob == null
                    ? (en ? 'After assignment' : 'असाइनमेंट के बाद')
                    : 'ETA ${member.etaMinutes} min',
              ),
              _identityRow(
                en ? 'Assigned incident' : 'असाइन घटना',
                activeJob?.incidentId ??
                    (en ? 'No active incident' : 'कोई सक्रिय घटना नहीं'),
              ),
              _identityRow(
                en ? 'Proof status' : 'प्रमाण स्थिति',
                activeJob == null
                    ? (en ? 'Awaiting dispatch' : 'डिस्पैच की प्रतीक्षा')
                    : activeJob.status.label,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _callMcgControlRoom(context, en);
                    },
                    icon: const Icon(Icons.call, size: 16),
                    label: Text(en ? 'CONTACT MCG' : 'एमसीजी संपर्क'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GovColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(en ? 'CLOSE' : 'बंद करें'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _identityRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

Future<void> _callMcgControlRoom(BuildContext context, bool en) async {
  final uri = Uri(scheme: 'tel', path: AppStore.mcgHelpline);
  final opened = await launchUrl(uri);
  if (!opened && context.mounted) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(en ? 'MCG Control Room' : 'एमसीजी कंट्रोल रूम'),
        content: SelectableText(AppStore.mcgHelpline),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(en ? 'CLOSE' : 'बंद करें'),
          ),
        ],
      ),
    );
  }
}

void _showCrewDispatchDialog(
  BuildContext context,
  AppStore store,
  CrewMember member,
  bool en,
) {
  final openIncidents = store.priorityQueue().where((report) {
    final status = store.statusOf(report.incidentId);
    return status == IncidentLifecycle.submitted ||
        status == IncidentLifecycle.merged;
  }).toList();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(en ? 'Assign ${member.id}' : '${member.id} असाइन करें'),
      content: SizedBox(
        width: double.maxFinite,
        child: openIncidents.isEmpty
            ? Text(
                en
                    ? 'No unassigned incidents in the priority queue.'
                    : 'प्राथमिकता क्यू में कोई अनअसाइन्ड घटना नहीं है।',
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: openIncidents.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final report = openIncidents[index];
                  final score = (report.priorityScore(store.reports) * 100)
                      .round();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      report.locationName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${report.band.name.toUpperCase()} • AI $score%',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: const Icon(
                      Icons.send,
                      color: GovColors.navy,
                      size: 18,
                    ),
                    onTap: () {
                      store.dispatchCrew(report.incidentId, member.id);
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            en
                                ? '${member.id} dispatched to ${report.locationName}'
                                : '${member.id} को ${report.locationName} भेजा गया',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
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

void _showDispatchCrewPicker(
  BuildContext context,
  AppStore store,
  String incidentId,
  bool en,
) {
  final available = AppStore.crewRoster.where((member) {
    final active = store.jobs.any(
      (job) => job.crewName == member.id && !job.isDone,
    );
    return !member.offDuty && !active;
  }).toList();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(en ? 'Select field crew' : 'फील्ड क्रू चुनें'),
      content: SizedBox(
        width: double.maxFinite,
        child: available.isEmpty
            ? Text(
                en
                    ? 'No crew is currently available.'
                    : 'अभी कोई क्रू उपलब्ध नहीं है।',
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: available.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final member = available[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _crewAvatar(member, radius: 22),
                    title: Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${member.id} • ${member.role} • ${member.ward}',
                      style: const TextStyle(fontSize: 9),
                    ),
                    trailing: const Icon(
                      Icons.send,
                      color: GovColors.navy,
                      size: 18,
                    ),
                    onTap: () {
                      store.dispatchCrew(incidentId, member.id);
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            en
                                ? '${member.name} (${member.id}) dispatched'
                                : '${member.name} (${member.id}) को भेजा गया',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
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

class _BroadcastTab extends StatefulWidget {
  final bool isDark;
  final AppStore store;
  final bool en;
  const _BroadcastTab({
    required this.isDark,
    required this.store,
    required this.en,
  });

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _msgController = TextEditingController();
  String _target = 'All Wards';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.en ? 'Send New Broadcast' : 'नया प्रसारण भेजें',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _msgController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: widget.en
                      ? 'Enter emergency message...'
                      : 'आपातकालीन संदेश दर्ज करें...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: widget.isDark ? Colors.black12 : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _target,
                items: ['All Wards', 'Ward 12', 'Ward 14', 'Sector 14']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _target = v!),
                decoration: InputDecoration(
                  labelText: widget.en ? 'Target Area' : 'लक्ष्य क्षेत्र',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_msgController.text.isNotEmpty) {
                    widget.store.addBroadcast(
                      BroadcastMessage(
                        id: 'B${DateTime.now().millisecondsSinceEpoch}',
                        msgEn: _msgController.text,
                        msgHi: _msgController.text,
                        target: _target,
                        time: 'Just now',
                      ),
                    );
                    _msgController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Broadcast Sent Successfully!'),
                        backgroundColor: GovColors.ok,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GovColors.critical,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.en ? 'INITIATE BROADCAST' : 'प्रसारण शुरू करें',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.en ? 'Recent Broadcasts' : 'हाल के प्रसारण',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...widget.store.broadcasts.reversed.map(
          (b) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? GovColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GovColors.critical.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.campaign,
                      color: GovColors.critical,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      b.target,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: GovColors.critical,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      b.time,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.en ? b.msgEn : b.msgHi,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Helper Widgets
class _KpiCard extends StatelessWidget {
  final String label, value, trend;
  final Color color;
  final bool isDark;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            Text(
              trend,
              style: TextStyle(
                fontSize: 8,
                color: trend.contains('+') ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;
  const _ChartContainer({
    required this.title,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
