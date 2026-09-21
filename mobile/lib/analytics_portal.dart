import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

class AnalyticsPortal extends StatefulWidget {
  const AnalyticsPortal({super.key});

  @override
  State<AnalyticsPortal> createState() => _AnalyticsPortalState();
}

class _AnalyticsPortalState extends State<AnalyticsPortal> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;

    final List<Widget> tabs = [
      _HeatmapTab(isDark: isDark, store: store),
      _WeatherTrendsTab(isDark: isDark, store: store),
      _PerformanceTab(isDark: isDark, store: store),
    ];

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: GovColors.navy,
            child: TabBar(
              onTap: (i) => setState(() => _currentIndex = i),
              indicatorColor: GovColors.gold,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: store.t('Heatmap', 'हीटमैप')),
                Tab(text: store.t('Weather', 'मौसम')),
                Tab(text: store.t('Performance', 'प्रदर्शन')),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: tabs),
          ),
        ],
      ),
    );
  }
}

class _HeatmapTab extends StatefulWidget {
  final bool isDark;
  final AppStore store;
  const _HeatmapTab({required this.isDark, required this.store});

  @override
  State<_HeatmapTab> createState() => _HeatmapTabState();
}

class _HeatmapTabState extends State<_HeatmapTab> {
  final MapController _mapCtrl = MapController();

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final isDark = widget.isDark;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: const MapOptions(
            initialCenter: LatLng(28.4595, 77.0262),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                  : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nalanetra.floodgrid',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            CircleLayer(
              circles: gurugramLocations.take(30).map((loc) {
                final color = loc.criticality > 0.8
                    ? GovColors.critical
                    : (loc.criticality > 0.6 ? Colors.orange : Colors.yellow);
                return CircleMarker(
                  point: LatLng(loc.lat, loc.lon),
                  color: color.withValues(alpha: 0.4),
                  borderStrokeWidth: 0,
                  useRadiusInMeter: true,
                  radius: 400 * loc.criticality,
                );
              }).toList(),
            ),
          ],
        ),
        // Heatmap Legend
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1F2B4E)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.t('Intensity Legend', 'तीव्रता लीजेंड'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: ThemeText.colorOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildLegendItem(
                      store.t('Critical', 'गंभीर'),
                      GovColors.critical,
                      context,
                    ),
                    _buildLegendItem(
                      store.t('High', 'उच्च'),
                      Colors.orange,
                      context,
                    ),
                    _buildLegendItem(
                      store.t('Medium', 'मध्यम'),
                      Colors.yellow,
                      context,
                    ),
                    _buildLegendItem(
                      store.t('Low', 'कम'),
                      Colors.green,
                      context,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Floating Controls
        Positioned(
          top: 20,
          right: 20,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'zoom_in_heatmap',
                onPressed: () => _mapCtrl.move(
                  _mapCtrl.camera.center,
                  _mapCtrl.camera.zoom + 1,
                ),
                backgroundColor: isDark
                    ? const Color(0xFF1F2B4E)
                    : Colors.white,
                child: Icon(
                  Icons.add,
                  color: isDark ? Colors.white : GovColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoom_out_heatmap',
                onPressed: () => _mapCtrl.move(
                  _mapCtrl.camera.center,
                  _mapCtrl.camera.zoom - 1,
                ),
                backgroundColor: isDark
                    ? const Color(0xFF1F2B4E)
                    : Colors.white,
                child: Icon(
                  Icons.remove,
                  color: isDark ? Colors.white : GovColors.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: ThemeText.colorOf(context)),
          ),
        ],
      ),
    );
  }
}

class _WeatherTrendsTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  const _WeatherTrendsTab({required this.isDark, required this.store});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartCard(context, 'Weekly Rainfall (mm)', 'Average: 42mm'),
          const SizedBox(height: 16),
          _buildChartCard(context, 'Predictive Flood Risk', 'Next 48 Hours'),
          const SizedBox(height: 16),
          _buildStatSummary(context),
        ],
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeText.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeText.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ThemeText.colorOf(context),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: ThemeText.secondaryOf(context),
            ),
          ),
          const SizedBox(height: 20),
          // Mock Chart Area
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: GovColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.show_chart, color: GovColors.navy, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummary(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(context, 'Humidity', '82%', Icons.water_drop),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniStat(context, 'Wind Speed', '14 km/h', Icons.air),
        ),
      ],
    );
  }

  Widget _buildMiniStat(
    BuildContext context,
    String label,
    String val,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeText.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeText.dividerOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: GovColors.gold, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                val,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ThemeText.colorOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  final bool isDark;
  final AppStore store;
  const _PerformanceTab({required this.isDark, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return _buildPerformanceRow(context, index + 1);
      },
    );
  }

  Widget _buildPerformanceRow(BuildContext context, int rank) {
    final score = 100 - (rank * 3);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeText.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeText.dividerOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: rank <= 3 ? GovColors.gold : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ward ${rank + 10}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ThemeText.colorOf(context),
                  ),
                ),
                Text(
                  'Avg Response: ${10 + rank}m',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                'Efficiency',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
