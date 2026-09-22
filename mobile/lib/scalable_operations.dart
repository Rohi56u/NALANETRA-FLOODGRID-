import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

/// First scalable feature surface added to the existing Flutter app.
/// Provider data is intentionally labelled as prototype/demo until connected
/// to verified radar, DEM, incident, and routing APIs.
class ScalableOperationsScreen extends StatefulWidget {
  const ScalableOperationsScreen({super.key});

  @override
  State<ScalableOperationsScreen> createState() =>
      _ScalableOperationsScreenState();
}

class _ScalableOperationsScreenState extends State<ScalableOperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _groundTruthUpgraded = false;
  bool _routeRecomputed = false;
  bool _closureVerified = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final ink = isDark ? Colors.white : GovColors.navy;

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF6F8FC),
      appBar: GovHeader(
        title: en ? 'Advanced Operations' : 'उन्नत संचालन',
        subtitle: en
            ? 'Scalable flood intelligence · Prototype data'
            : 'स्केलेबल बाढ़ इंटेलिजेंस · प्रोटोटाइप डेटा',
        bottom: TabBar(
          controller: _tabs,
          isScrollable: false,
          indicatorColor: GovColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: en ? 'Forecast' : 'पूर्वानुमान'),
            Tab(text: en ? 'Ground Truth' : 'ग्राउंड ट्रुथ'),
            Tab(text: en ? 'Closure' : 'क्लोज़र'),
            Tab(text: en ? 'Reroute' : 'रीरूट'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ForecastTab(isDark: isDark, ink: ink, en: en),
          _GroundTruthTab(
            isDark: isDark,
            ink: ink,
            en: en,
            upgraded: _groundTruthUpgraded,
            onUpgrade: () => setState(() => _groundTruthUpgraded = true),
          ),
          _ClosureTab(
            isDark: isDark,
            ink: ink,
            en: en,
            verified: _closureVerified,
            onVerify: () {
              setState(() => _closureVerified = true);
              _notice(
                en
                    ? 'Closure verification recorded.'
                    : 'क्लोज़र सत्यापन दर्ज हुआ।',
              );
            },
          ),
          _RerouteTab(
            isDark: isDark,
            ink: ink,
            en: en,
            recomputed: _routeRecomputed,
            onRecompute: () {
              setState(() => _routeRecomputed = true);
              _notice(
                en ? 'Alternate route prepared.' : 'वैकल्पिक मार्ग तैयार है।',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ForecastTab extends StatelessWidget {
  final bool isDark;
  final Color ink;
  final bool en;
  const _ForecastTab({
    required this.isDark,
    required this.ink,
    required this.en,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PrototypeBanner(en: en),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/operations/catalogue'),
            icon: const Icon(Icons.grid_view_outlined, size: 18),
            label: Text(
              en ? 'Browse all scalable surfaces' : 'सभी स्केलेबल सतह देखें',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: GovColors.navy,
              side: const BorderSide(color: GovColors.navy),
            ),
          ),
        ),
        _SectionTitle(
          icon: Icons.query_stats,
          title: en
              ? 'Next 3-hour flood outlook'
              : 'अगले 3 घंटे का बाढ़ पूर्वानुमान',
          subtitle: en
              ? 'Radar rainfall + DEM terrain inputs will appear here when connected.'
              : 'कनेक्शन के बाद रडार वर्षा और DEM भू-भाग डेटा यहां दिखेगा।',
          ink: ink,
        ),
        const SizedBox(height: 12),
        _MetricGrid(
          isDark: isDark,
          items: [
            ('Horizon', '03:00 h', Icons.schedule),
            ('Rainfall', 'Unavailable', Icons.water_drop),
            ('Terrain', 'DEM pending', Icons.terrain),
            ('Confidence', 'Unknown', Icons.help_outline),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                en ? 'Forecast layer' : 'पूर्वानुमान लेयर',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 210,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFE7EEF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFD3DFEF),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 42,
                        color: GovColors.navy.withValues(alpha: .65),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        en
                            ? 'Radar + DEM preview unavailable'
                            : 'रडार + DEM प्रीव्यू उपलब्ध नहीं',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        en
                            ? 'Connect verified data feeds to activate this layer.'
                            : 'सत्यापित डेटा फीड जोड़कर यह लेयर सक्रिय करें।',
                        style: TextStyle(
                          color: ink.withValues(alpha: .65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroundTruthTab extends StatelessWidget {
  final bool isDark;
  final Color ink;
  final bool en;
  final bool upgraded;
  final VoidCallback onUpgrade;
  const _GroundTruthTab({
    required this.isDark,
    required this.ink,
    required this.en,
    required this.upgraded,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PrototypeBanner(en: en),
        _SectionTitle(
          icon: Icons.fact_check_outlined,
          title: en ? 'Citizen ground truth' : 'नागरिक ग्राउंड ट्रुथ',
          subtitle: en
              ? 'Hyper-local evidence can upgrade a forecast priority.'
              : 'हाइपर-लोकल प्रमाण पूर्वानुमान की प्राथमिकता बढ़ा सकता है।',
          ink: ink,
        ),
        const SizedBox(height: 12),
        _Panel(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: GovColors.critical),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FG-2048 · Sector 14 Underpass',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LabelValue(
                      label: 'AI forecast',
                      value: 'Moderate',
                      color: GovColors.gold,
                      ink: ink,
                    ),
                  ),
                  Expanded(
                    child: _LabelValue(
                      label: 'Citizen depth',
                      value: 'Waist-deep',
                      color: GovColors.critical,
                      ink: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                en
                    ? 'A citizen photo/GPS report is awaiting verification. Do not treat demo imagery as a live incident.'
                    : 'नागरिक फोटो/GPS रिपोर्ट सत्यापन की प्रतीक्षा में है। डेमो इमेज को लाइव घटना न मानें।',
                style: TextStyle(
                  color: ink.withValues(alpha: .7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: upgraded ? null : onUpgrade,
                  icon: Icon(upgraded ? Icons.check : Icons.priority_high),
                  label: Text(
                    upgraded
                        ? (en
                              ? 'Priority upgrade recorded'
                              : 'प्राथमिकता अपग्रेड दर्ज')
                        : (en
                              ? 'Upgrade priority after evidence review'
                              : 'प्रमाण समीक्षा के बाद प्राथमिकता बढ़ाएं'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: GovColors.navy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClosureTab extends StatelessWidget {
  final bool isDark;
  final Color ink;
  final bool en;
  final bool verified;
  final VoidCallback onVerify;
  const _ClosureTab({
    required this.isDark,
    required this.ink,
    required this.en,
    required this.verified,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PrototypeBanner(en: en),
        _SectionTitle(
          icon: Icons.verified_outlined,
          title: en ? 'Closure loop' : 'क्लोज़र लूप',
          subtitle: en
              ? 'Before-after evidence moves an incident to flood-safe.'
              : 'पहले-बाद के प्रमाण से घटना Flood-safe स्थिति में जाती है।',
          ink: ink,
        ),
        const SizedBox(height: 12),
        _Panel(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FG-2048 · Sector 14 Underpass',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _EvidenceBox(
                      title: en ? 'BEFORE' : 'पहले',
                      icon: Icons.flood,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EvidenceBox(
                      title: en ? 'AFTER' : 'बाद',
                      icon: Icons.photo_camera_back_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                verified
                    ? (en
                          ? 'Verified · Flood-safe status recorded'
                          : 'सत्यापित · Flood-safe स्थिति दर्ज')
                    : (en
                          ? 'Awaiting supervisor review. Evidence source must be attached before approval.'
                          : 'सुपरवाइज़र समीक्षा की प्रतीक्षा। अनुमोदन से पहले प्रमाण जोड़ना जरूरी है।'),
                style: TextStyle(
                  color: verified ? GovColors.ok : ink.withValues(alpha: .7),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: verified ? null : onVerify,
                  icon: Icon(verified ? Icons.check_circle : Icons.fact_check),
                  label: Text(
                    verified
                        ? (en ? 'Flood-safe verified' : 'Flood-safe सत्यापित')
                        : (en ? 'Verify closure' : 'क्लोज़र सत्यापित करें'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: GovColors.navy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RerouteTab extends StatelessWidget {
  final bool isDark;
  final Color ink;
  final bool en;
  final bool recomputed;
  final VoidCallback onRecompute;
  const _RerouteTab({
    required this.isDark,
    required this.ink,
    required this.en,
    required this.recomputed,
    required this.onRecompute,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PrototypeBanner(en: en),
        _SectionTitle(
          icon: Icons.alt_route,
          title: en ? 'Flood-aware rerouting' : 'बाढ़-सुरक्षित रीरूटिंग',
          subtitle: en
              ? 'Avoid a blocked road and explain why the alternate is safer.'
              : 'अवरुद्ध सड़क से बचें और सुरक्षित वैकल्पिक मार्ग का कारण देखें।',
          ink: ink,
        ),
        const SizedBox(height: 12),
        _Panel(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteRow(
                icon: Icons.block,
                label: en ? 'Blocked' : 'अवरुद्ध',
                value: 'Old Railway Road',
                color: GovColors.critical,
                ink: ink,
              ),
              const Divider(height: 24),
              _RouteRow(
                icon: Icons.alt_route,
                label: en ? 'Alternate' : 'वैकल्पिक',
                value: recomputed
                    ? 'NH-48 service road'
                    : 'Awaiting route calculation',
                color: recomputed ? GovColors.ok : GovColors.gold,
                ink: ink,
              ),
              const SizedBox(height: 12),
              Text(
                recomputed
                    ? (en
                          ? 'Route safety check complete · ETA requires a connected routing provider.'
                          : 'मार्ग सुरक्षा जांच पूरी · ETA के लिए routing provider जोड़ें।')
                    : (en
                          ? 'Prototype state: route provider not connected.'
                          : 'प्रोटोटाइप स्थिति: route provider कनेक्ट नहीं है।'),
                style: TextStyle(
                  color: ink.withValues(alpha: .7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: recomputed ? null : onRecompute,
                  icon: Icon(recomputed ? Icons.check : Icons.route),
                  label: Text(
                    recomputed
                        ? (en
                              ? 'Alternate route ready'
                              : 'वैकल्पिक मार्ग तैयार')
                        : (en
                              ? 'Calculate safer alternate'
                              : 'सुरक्षित वैकल्पिक निकालें'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: GovColors.navy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrototypeBanner extends StatelessWidget {
  final bool en;
  const _PrototypeBanner({required this.en});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: GovColors.gold.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: GovColors.gold.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: GovColors.navy),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            en
                ? 'Prototype / Demo data — connect verified providers before operational use.'
                : 'प्रोटोटाइप / डेमो डेटा — संचालन से पहले सत्यापित provider जोड़ें।',
            style: const TextStyle(
              color: GovColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color ink;
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ink,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: GovColors.navy, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: ink.withValues(alpha: .68),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Panel({required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: .06) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFE0E6EF),
      ),
      boxShadow: isDark
          ? null
          : [
              const BoxShadow(
                color: Color(0x120A2E6B),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
    ),
    child: child,
  );
}

class _MetricGrid extends StatelessWidget {
  final bool isDark;
  final List<(String, String, IconData)> items;
  const _MetricGrid({required this.isDark, required this.items});
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisExtent: 92,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemBuilder: (context, index) {
      final item = items[index];
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: .06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE0E6EF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.$3, color: GovColors.navy, size: 20),
            const Spacer(),
            Text(
              item.$1,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 11,
              ),
            ),
            Text(
              item.$2,
              style: TextStyle(
                color: isDark ? Colors.white : GovColors.navy,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color ink;
  const _LabelValue({
    required this.label,
    required this.value,
    required this.color,
    required this.ink,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: ink.withValues(alpha: .58), fontSize: 11),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    ],
  );
}

class _EvidenceBox extends StatelessWidget {
  final String title;
  final IconData icon;
  const _EvidenceBox({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    height: 126,
    decoration: BoxDecoration(
      color: const Color(0xFFE7EEF8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD0DCEC)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34, color: GovColors.navy.withValues(alpha: .7)),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: GovColors.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Evidence unavailable',
          style: TextStyle(color: Colors.black54, fontSize: 11),
        ),
      ],
    ),
  );
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color ink;
  const _RouteRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.ink,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(color: ink.withValues(alpha: .62), fontSize: 12),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    ],
  );
}

/// Consolidates the supplied 72 visual references into navigable Flutter
/// surface variants. These are not screenshots: each item opens a truthful
/// prototype/data-availability state and can later be bound to a repository.
class ScalableCatalogueScreen extends StatelessWidget {
  const ScalableCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final ink = isDark ? Colors.white : GovColors.navy;

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF6F8FC),
      appBar: GovHeader(
        title: en ? 'Scalable operations catalogue' : 'स्केलेबल संचालन कैटलॉग',
        subtitle: en
            ? '72 references consolidated into functional surface states'
            : '72 संदर्भों को कार्यात्मक सतह स्थितियों में समेकित किया गया है',
        showBack: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _scalableSurfaces.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _PrototypeBanner(en: en);
          }
          final surface = _scalableSurfaces[index - 1];
          return _SurfaceTile(
            surface: surface,
            ink: ink,
            isDark: isDark,
            en: en,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ScalableSurfaceDetailScreen(surface: surface),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ScalableSurfaceDetailScreen extends StatelessWidget {
  final _ScalableSurface surface;
  const ScalableSurfaceDetailScreen({super.key, required this.surface});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final ink = isDark ? Colors.white : GovColors.navy;
    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF6F8FC),
      appBar: GovHeader(
        title: en ? surface.title : surface.hindiTitle,
        subtitle: en ? surface.family : surface.hindiFamily,
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PrototypeBanner(en: en),
          const SizedBox(height: 14),
          _Panel(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(surface.icon, color: GovColors.navy, size: 34),
                const SizedBox(height: 10),
                Text(
                  en ? surface.title : surface.hindiTitle,
                  style: TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  en ? surface.description : surface.hindiDescription,
                  style: TextStyle(
                    color: ink.withValues(alpha: .75),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _RouteRow(
                  icon: Icons.dataset_outlined,
                  label: en ? 'Data state' : 'डेटा स्थिति',
                  value: en
                      ? 'Prototype / unavailable'
                      : 'प्रोटोटाइप / उपलब्ध नहीं',
                  color: GovColors.gold,
                  ink: ink,
                ),
                const SizedBox(height: 12),
                _RouteRow(
                  icon: Icons.touch_app_outlined,
                  label: en ? 'Interaction' : 'इंटरैक्शन',
                  value: en
                      ? 'Review, retry, and back are active'
                      : 'समीक्षा, पुनः प्रयास और वापस सक्रिय हैं',
                  color: GovColors.ok,
                  ink: ink,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            en
                                ? 'This surface is ready for a verified provider connection.'
                                : 'यह सतह सत्यापित provider connection के लिए तैयार है।',
                          ),
                        ),
                      ),
                    icon: const Icon(Icons.link_outlined),
                    label: Text(
                      en
                          ? 'Review integration state'
                          : 'इंटीग्रेशन स्थिति देखें',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: GovColors.navy,
                      foregroundColor: Colors.white,
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

class _SurfaceTile extends StatelessWidget {
  final _ScalableSurface surface;
  final Color ink;
  final bool isDark;
  final bool en;
  final VoidCallback onTap;
  const _SurfaceTile({
    required this.surface,
    required this.ink,
    required this.isDark,
    required this.en,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: isDark ? Colors.white.withValues(alpha: .06) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(surface.icon, color: GovColors.navy, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? surface.title : surface.hindiTitle,
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    en ? surface.family : surface.hindiFamily,
                    style: TextStyle(
                      color: ink.withValues(alpha: .62),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: ink.withValues(alpha: .55)),
          ],
        ),
      ),
    ),
  );
}

class _ScalableSurface {
  final String title;
  final String hindiTitle;
  final String family;
  final String hindiFamily;
  final String description;
  final String hindiDescription;
  final IconData icon;
  const _ScalableSurface({
    required this.title,
    required this.hindiTitle,
    required this.family,
    required this.hindiFamily,
    required this.description,
    required this.hindiDescription,
    required this.icon,
  });
}

const _scalableSurfaces = <_ScalableSurface>[
  _ScalableSurface(
    title: 'Predictive Flood Layer',
    hindiTitle: 'पूर्वानुमान बाढ़ लेयर',
    family: 'Forecast · rainfall · radar · DEM',
    hindiFamily: 'पूर्वानुमान · वर्षा · रडार · डीईएम',
    description: 'Forecast horizon, source, timestamp, zones, confidence, and data-unavailable state.',
    hindiDescription:
        'पूर्वानुमान अवधि, स्रोत, समय, क्षेत्र, भरोसा और डेटा-अनुपलब्ध स्थिति।',
    icon: Icons.layers_outlined,
  ),
  _ScalableSurface(
    title: 'Ground Truth Validation',
    hindiTitle: 'ग्राउंड ट्रुथ सत्यापन',
    family: 'Citizen evidence · contradiction · priority upgrade',
    hindiFamily: 'नागरिक प्रमाण · विरोधाभास · प्राथमिकता अपग्रेड',
    description: 'Compare model output with citizen photo/GPS evidence and record the review reason.',
    hindiDescription: 'मॉडल परिणाम की नागरिक फोटो/GPS प्रमाण से तुलना और समीक्षा कारण दर्ज करें।',
    icon: Icons.fact_check_outlined,
  ),
  _ScalableSurface(
    title: 'Explainable Priority Score',
    hindiTitle: 'व्याख्यात्मक प्राथमिकता स्कोर',
    family: 'Rainfall · drainage capacity · criticality',
    hindiFamily: 'वर्षा · जलनिकासी क्षमता · महत्वपूर्णता',
    description: 'Show the component breakdown behind a flood priority score instead of a black-box label.',
    hindiDescription:
        'बाढ़ प्राथमिकता स्कोर के घटक दिखाएं, केवल ब्लैक-बॉक्स लेबल नहीं।',
    icon: Icons.analytics_outlined,
  ),
  _ScalableSurface(
    title: 'Incident Dispatch',
    hindiTitle: 'घटना डिस्पैच',
    family: 'Queue · evidence · duplicate count · escalation',
    hindiFamily: 'कतार · प्रमाण · डुप्लिकेट संख्या · एस्केलेशन',
    description: 'Review an incident, its evidence and score, then move to dispatch or escalation.',
    hindiDescription:
        'घटना, प्रमाण और स्कोर की समीक्षा कर डिस्पैच या एस्केलेशन करें।',
    icon: Icons.assignment_turned_in_outlined,
  ),
  _ScalableSurface(
    title: 'Crew Deployment',
    hindiTitle: 'क्रू तैनाती',
    family: 'Availability · distance · skills · assignment',
    hindiFamily: 'उपलब्धता · दूरी · कौशल · असाइनमेंट',
    description: 'Select eligible field crew and show assignment confirmation or retry state.',
    hindiDescription: 'योग्य फील्ड क्रू चुनें और असाइनमेंट पुष्टि या पुनः प्रयास स्थिति दिखाएं।',
    icon: Icons.groups_outlined,
  ),
  _ScalableSurface(
    title: 'Closure Loop',
    hindiTitle: 'क्लोज़र लूप',
    family: 'Before/after proof · supervisor review · flood-safe',
    hindiFamily: 'पहले/बाद प्रमाण · पर्यवेक्षक समीक्षा · बाढ़-सुरक्षित',
    description: 'Move a job from work completed to verified closure only after proof review.',
    hindiDescription: 'प्रमाण समीक्षा के बाद ही कार्य को पूर्ण से सत्यापित क्लोज़र में ले जाएं।',
    icon: Icons.verified_outlined,
  ),
  _ScalableSurface(
    title: 'City Flood Map',
    hindiTitle: 'शहर बाढ़ मानचित्र',
    family: 'Heatmap · verified layer · predictive layer · markers',
    hindiFamily: 'हीटमैप · सत्यापित लेयर · पूर्वानुमान लेयर · मार्कर',
    description: 'Keep map layers, severity legend, filters, and incident detail in one map surface.',
    hindiDescription:
        'मानचित्र लेयर, गंभीरता संकेत, फिल्टर और घटना विवरण एक सतह पर रखें।',
    icon: Icons.map_outlined,
  ),
  _ScalableSurface(
    title: 'Weather and Response Analytics',
    hindiTitle: 'मौसम और प्रतिक्रिया एनालिटिक्स',
    family: 'Rainfall trends · KPIs · ward comparison · SLA',
    hindiFamily: 'वर्षा रुझान · KPI · वार्ड तुलना · SLA',
    description: 'Consolidate weather, response, ward, and SLA views with truthful no-data states.',
    hindiDescription: 'मौसम, प्रतिक्रिया, वार्ड और SLA दृश्य को डेटा-अनुपलब्ध स्थिति सहित समेकित करें।',
    icon: Icons.query_stats,
  ),
  _ScalableSurface(
    title: 'Inventory and Broadcast',
    hindiTitle: 'इन्वेंटरी और प्रसारण',
    family: 'Pumps · vehicles · sandbags · bilingual alerts',
    hindiFamily: 'पंप · वाहन · सैंडबैग · द्विभाषी अलर्ट',
    description: 'Track response resources and prepare approval-gated emergency broadcasts.',
    hindiDescription: 'प्रतिक्रिया संसाधन ट्रैक करें और अनुमोदन-आधारित आपात प्रसारण तैयार करें।',
    icon: Icons.inventory_2_outlined,
  ),
  _ScalableSurface(
    title: 'Crew Mission and Proof',
    hindiTitle: 'क्रू मिशन और प्रमाण',
    family: 'Jobs · navigation · movement · before/after upload',
    hindiFamily: 'कार्य · नेविगेशन · मूवमेंट · पहले/बाद अपलोड',
    description: 'Represent the crew state machine from assigned job through proof submission.',
    hindiDescription:
        'असाइन किए गए कार्य से प्रमाण जमा करने तक क्रू स्थिति मशीन दिखाएं।',
    icon: Icons.engineering_outlined,
  ),
  _ScalableSurface(
    title: 'API and Integration Console',
    hindiTitle: 'API और इंटीग्रेशन कंसोल',
    family: 'Navigation API · data feeds · keys · webhooks',
    hindiFamily: 'नेविगेशन API · डेटा फीड · कुंजी · वेबहुक',
    description: 'Reserve a governed surface for provider connections, API health, and webhook status.',
    hindiDescription: 'provider connection, API health और webhook स्थिति के लिए नियंत्रित सतह।',
    icon: Icons.api_outlined,
  ),
  _ScalableSurface(
    title: 'Governance, Support and Observability',
    hindiTitle: 'गवर्नेंस, सहायता और ऑब्जर्वेबिलिटी',
    family: 'Users · wards · policies · audit · FAQ · system health',
    hindiFamily: 'उपयोगकर्ता · वार्ड · नीतियां · ऑडिट · FAQ · सिस्टम स्वास्थ्य',
    description: 'Keep access policy, audit, support, FAQs, and system health discoverable and role-safe.',
    hindiDescription: 'एक्सेस नीति, ऑडिट, सहायता, FAQ और सिस्टम स्वास्थ्य को भूमिका-सुरक्षित रखें।',
    icon: Icons.admin_panel_settings_outlined,
  ),
];
