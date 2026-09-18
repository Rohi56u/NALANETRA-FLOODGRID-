import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';
import 'citizen_home.dart';

// ---------------------------------------------------------------------------
// PIXEL-PERFECT LIVE MAP — reference WA0011:
// High-fidelity map UI with floating search bar, severity pins,
// and ward-wise summary chart.
// ---------------------------------------------------------------------------

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapCtrl = MapController();
  GurugramLocation? _selectedPin;
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final en = store.lang == AppLang.en;
    final isDark = store.themeMode == AppThemeMode.dark;

    // Fix: Filter logic actually updates the markers
    List<GurugramLocation> filteredLocations = gurugramLocations.toList();
    if (_filter == 'Critical only') {
      filteredLocations = filteredLocations
          .where((l) => l.criticality > 0.7)
          .toList();
    } else if (_filter == 'Near me') {
      filteredLocations = filteredLocations
          .where(
            (l) =>
                l.name.contains('Sector 14') ||
                l.name.contains('Sector 15') ||
                l.name.contains('Old Gurugram'),
          )
          .toList();
    } else if (_filter == 'Verified') {
      // Show locations where reports are verified
      final verifiedIncidentIds = store.reports
          .where(
            (r) => store.statusOf(r.incidentId) == IncidentLifecycle.verified,
          )
          .map((r) => r.incidentId)
          .toSet();
      filteredLocations = filteredLocations
          .where(
            (l) => store.reports.any(
              (r) =>
                  r.locationName == l.name &&
                  verifiedIncidentIds.contains(r.incidentId),
            ),
          )
          .toList();
      // If empty, show low criticality as fallback for demo
      if (filteredLocations.isEmpty) {
        filteredLocations = gurugramLocations
            .where((l) => l.criticality < 0.3)
            .take(10)
            .toList();
      }
    }

    return Column(
      children: [
        GovHeader(
          title: en ? 'Live Flood Map — Gurugram' : 'लाइव बाढ़ मैप — गुड़गांव',
          subtitle: en
              ? 'Real-time waterlogging & crew status'
              : 'Real-time waterlogging & crew status',
          trailing: Row(
            children: [
              GestureDetector(
                onTap: () => store.setLang(
                  store.lang == AppLang.en ? AppLang.hi : AppLang.en,
                ),
                child: Text(
                  en ? 'EN | हिंदी' : 'हिंदी | EN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: const LatLng(28.4595, 77.0262),
                  initialZoom: 14,
                  onTap: (_, __) => setState(() => _selectedPin = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                        : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nalanetra.floodgrid',
                    subdomains: const ['a', 'b', 'c', 'd'],
                  ),
                  MarkerLayer(
                    markers: filteredLocations.map((h) {
                      final active = _selectedPin?.name == h.name;
                      return Marker(
                        point: LatLng(h.lat, h.lon),
                        width: active ? 220 : 60,
                        height: active ? 160 : 60,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPin = h),
                          child: active
                              ? _buildPinPopover(h, isDark)
                              : _buildPinMarker(h),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Floating Search & Filters
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2B4E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              onChanged: (val) {
                                if (val.isEmpty) return;
                                setState(() {
                                  final match = gurugramLocations
                                      .where(
                                        (l) => l.name.toLowerCase().contains(
                                          val.toLowerCase(),
                                        ),
                                      )
                                      .firstOrNull;
                                  if (match != null) {
                                    _mapCtrl.move(
                                      LatLng(match.lat, match.lon),
                                      15,
                                    );
                                  }
                                });
                              },
                              decoration: InputDecoration(
                                hintText: store.t(
                                  'Search sectors, wards...',
                                  'सेक्टर, वार्ड खोजें...',
                                ),
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.search,
                            color: isDark ? Colors.white70 : Colors.black45,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: en ? 'All' : 'सभी',
                            active: _filter == 'All',
                            onTap: () => setState(() => _filter = 'All'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: en ? 'Near me' : 'मेरे पास',
                            active: _filter == 'Near me',
                            onTap: () => setState(() => _filter = 'Near me'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: en ? 'Critical only' : 'केवल गंभीर',
                            active: _filter == 'Critical only',
                            onTap: () =>
                                setState(() => _filter = 'Critical only'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: en ? 'Verified' : 'सत्यापित',
                            active: _filter == 'Verified',
                            onTap: () => setState(() => _filter = 'Verified'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Zoom Controls
              Positioned(
                right: 12,
                bottom: 240,
                child: Column(
                  children: [
                    _MapActionBtn(
                      icon: Icons.my_location,
                      onTap: () =>
                          _mapCtrl.move(const LatLng(28.4595, 77.0262), 14),
                    ),
                    const SizedBox(height: 8),
                    _MapActionBtn(
                      icon: Icons.add,
                      onTap: () => _mapCtrl.move(
                        _mapCtrl.camera.center,
                        _mapCtrl.camera.zoom + 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _MapActionBtn(
                      icon: Icons.remove,
                      onTap: () => _mapCtrl.move(
                        _mapCtrl.camera.center,
                        _mapCtrl.camera.zoom - 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Ward Summary Bottom Sheet (Fixed Overflow)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2B4E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            en ? 'Ward-wise summary' : 'वार्ड-वार सारांश',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : GovColors.navy,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showWardDetails(context, store, isDark),
                            child: Text(
                              en ? 'View all >' : 'सभी देखें >',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GovColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _LegendItem(
                              color: Colors.red,
                              label: en ? 'Critical' : 'गंभीर',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 12),
                            _LegendItem(
                              color: Colors.orange,
                              label: en ? 'Moderate' : 'मध्यम',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 12),
                            _LegendItem(
                              color: Colors.green,
                              label: en ? 'Low' : 'कम',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Fixed Overflow with LayoutBuilder or just proper spacing
                      SizedBox(
                        height: 120,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _Bar(
                                label: 'Sector 14',
                                value: 5,
                                color: Colors.red,
                                height: 80,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 20),
                              _Bar(
                                label: 'Sector 30',
                                value: 3,
                                color: Colors.orange,
                                height: 50,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 20),
                              _Bar(
                                label: 'Sohna Rd',
                                value: 2,
                                color: Colors.green,
                                height: 40,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 20),
                              _Bar(
                                label: 'Sector 56',
                                value: 4,
                                color: Colors.orange,
                                height: 60,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 20),
                              _Bar(
                                label: 'MG Road',
                                value: 6,
                                color: Colors.red,
                                height: 90,
                                isDark: isDark,
                              ),
                            ],
                          ),
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

  Widget _buildPinMarker(GurugramLocation h) {
    final color = h.criticality > 0.8
        ? Colors.red
        : (h.criticality > 0.6 ? Colors.orange : Colors.green);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        ),
        Icon(Icons.location_on, color: color, size: 28),
      ],
    );
  }

  Widget _buildPinPopover(GurugramLocation h, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A33) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
        ],
        border: Border.all(color: GovColors.navy.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            h.name.split('—').first,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : GovColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• 14 reports',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          Text(
            '• Severity ${(h.criticality * 100).toInt()}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            '• Crew on site',
            style: TextStyle(fontSize: 11, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            'ETA 25 min',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? GovColors.gold : GovColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  void _showWardDetails(BuildContext context, AppStore store, bool isDark) {
    // Check if we can switch to Admin tab directly if user is Admin
    final parentState = context.findAncestorStateOfType<CitizenPortalState>();
    if (store.portal == Portal.admin && parentState != null) {
      parentState.tab = 2; // Admin Dashboard index
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? GovColors.bgDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              store.t('Ward-wise Flood Metrics', 'वार्ड-वार बाढ़ मेट्रिक्स'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : GovColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _wardItem('Ward 14', 'Sector 14, 15, 17', 0.95, isDark),
                  _wardItem('Ward 26', 'Sector 26, 27, 28', 0.20, isDark),
                  _wardItem('Ward 08', 'Sector 8, 9, 10', 0.65, isDark),
                  _wardItem('Ward 56', 'Sector 56, 57', 0.45, isDark),
                  _wardItem('Ward 31', 'MG Road, DLF Ph 2', 0.88, isDark),
                  _wardItem('Ward 02', 'Sector 4, 5, 7', 0.55, isDark),
                  _wardItem('Ward 10', 'Sector 10A, 10B', 0.35, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wardItem(String name, String sectors, double crit, bool isDark) {
    final color = crit > 0.8
        ? Colors.red
        : (crit > 0.5 ? Colors.orange : Colors.green);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  sectors,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(crit * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Text(
                'Severity',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapActionBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppStore>().themeMode == AppThemeMode.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2B4E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : Colors.black54,
          size: 20,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppStore>().themeMode == AppThemeMode.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? GovColors.navy
              : (isDark ? const Color(0xFF1F2B4E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (isDark ? Colors.white70 : GovColors.navy),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final double height;
  final bool isDark;
  const _Bar({
    required this.label,
    required this.value,
    required this.color,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
      ],
    );
  }
}
