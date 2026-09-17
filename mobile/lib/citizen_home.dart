import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';
import 'live_map_screen.dart';
import 'my_reports_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import 'report_flow.dart';
import 'officer_portal.dart';
import 'crew_portal.dart';
import 'admin_portal.dart';
import 'analytics_portal.dart';
import 'support_portal.dart';
import 'emergency_portal.dart';

// ---------------------------------------------------------------------------
// ALL-IN-ONE PORTAL WRAPPER
// Handles role-based switching and portal navigation.
// ---------------------------------------------------------------------------

class CitizenPortal extends StatefulWidget {
  const CitizenPortal({super.key});
  @override
  State<CitizenPortal> createState() => CitizenPortalState();
}

class CitizenPortalState extends State<CitizenPortal> {
  int _tab = 0;

  set tab(int value) => setState(() => _tab = value);

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final maxTab = store.portal == Portal.admin ? 6 : 4;
    final t = store.startTab == -1 ? 0 : store.startTab.clamp(0, maxTab);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => setState(() => _tab = t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;

    // React to startTab if set
    if (store.startTab != -1) {
      final t = store.startTab;
      final maxTab = store.portal == Portal.admin ? 6 : 4;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = t.clamp(0, maxTab));
        store.setStartTab(-1); // Reset
      });
    }

    // Determine screens and destinations based on role
    List<Widget> screens;
    List<GovNavDestination> destinations;

    // Deep Integration: For Admin, we natively merge Admin Portal screens into the Citizen Shell
    // Also include Officer/Crew portal integration if they log in via this shell
    if (store.portal == Portal.admin) {
      screens = [
        _HomeTab(),
        const LiveMapScreen(),
        const AdminDashboard(),
        const AnalyticsPortal(),
        const AlertsScreen(),
        const SupportPortal(),
        const ProfileScreen(),
      ];
      destinations = [
        GovNavDestination(icon: Icons.home, label: store.t('Home', 'होम')),
        GovNavDestination(icon: Icons.map, label: store.t('Map', 'मैप')),
        GovNavDestination(
          icon: Icons.admin_panel_settings,
          label: store.t('Admin', 'एडमिन'),
        ),
        GovNavDestination(
          icon: Icons.bar_chart,
          label: store.t('Analytics', 'एनालिटिक्स'),
        ),
        GovNavDestination(
          icon: Icons.notifications,
          label: store.t('Alerts', 'अलर्ट्स'),
        ),
        GovNavDestination(
          icon: Icons.support_agent,
          label: store.t('Support', 'सपोर्ट'),
        ),
        GovNavDestination(
          icon: Icons.person,
          label: store.t('Profile', 'प्रोफ़ाइल'),
        ),
      ];
    } else if (store.portal == Portal.officer) {
      screens = [
        const OfficerPortal(),
        const LiveMapScreen(),
        const AlertsScreen(),
        const SupportPortal(),
        const ProfileScreen(),
      ];
      destinations = [
        GovNavDestination(
          icon: Icons.account_balance,
          label: store.t('Command', 'कमांड'),
        ),
        GovNavDestination(icon: Icons.map, label: store.t('Map', 'मैप')),
        GovNavDestination(
          icon: Icons.notifications,
          label: store.t('Alerts', 'अलर्ट्स'),
        ),
        GovNavDestination(
          icon: Icons.support_agent,
          label: store.t('Support', 'सपोर्ट'),
        ),
        GovNavDestination(
          icon: Icons.person,
          label: store.t('Profile', 'प्रोफ़ाइल'),
        ),
      ];
    } else if (store.portal == Portal.crew) {
      screens = [
        const CrewPortal(),
        const LiveMapScreen(),
        const AlertsScreen(),
        const SupportPortal(),
        const ProfileScreen(),
      ];
      destinations = [
        GovNavDestination(
          icon: Icons.engineering,
          label: store.t('Jobs', 'कार्य'),
        ),
        GovNavDestination(icon: Icons.map, label: store.t('Map', 'मैप')),
        GovNavDestination(
          icon: Icons.notifications,
          label: store.t('Alerts', 'अलर्ट्स'),
        ),
        GovNavDestination(
          icon: Icons.support_agent,
          label: store.t('Support', 'सपोर्ट'),
        ),
        GovNavDestination(
          icon: Icons.person,
          label: store.t('Profile', 'प्रोफ़ाइल'),
        ),
      ];
    } else {
      screens = [
        _HomeTab(),
        const LiveMapScreen(),
        const MyReportsScreen(),
        const AlertsScreen(),
        const ProfileScreen(),
      ];
      destinations = [
        GovNavDestination(icon: Icons.home, label: store.t('Home', 'होम')),
        GovNavDestination(icon: Icons.map, label: store.t('Map', 'मैप')),
        GovNavDestination(
          icon: Icons.assignment,
          label: store.t('Reports', 'रिपोर्ट्स'),
        ),
        GovNavDestination(
          icon: Icons.notifications,
          label: store.t('Alerts', 'अलर्ट्स'),
        ),
        GovNavDestination(
          icon: Icons.person,
          label: store.t('Profile', 'प्रोफ़ाइल'),
        ),
      ];
    }

    // If Admin/Officer/Crew, we inject specialized tabs into the HomeTab or provide access via Profile
    // But for this final fix, let's keep the Citizen structure but allow role-based navigation via a "Portal Hub" in Home
    if (store.portal != Portal.citizen) {
      // For Admin/Officer/Crew, we might want to swap some tabs if needed,
      // but user requested "Admin screens in Citizen dashboard"
    }

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : GovColors.bgLight,
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: GovBottomNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final _selectedLocation = store.selectedLocation;
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;

    return Column(
      children: [
        GovHeader(
          title: 'NalaNetra FloodGrid',
          subtitle: en
              ? 'जन सुरक्षा, हमारी प्राथमिकता | Govt. of India Initiative'
              : 'जन सुरक्षा, हमारी प्राथमिकता | भारत सरकार की पहल',
          showBack: false,
          trailing: GestureDetector(
            onTap: () {
              final parentState = context
                  .findAncestorStateOfType<CitizenPortalState>();
              parentState?.tab = store.portal == Portal.admin ? 6 : 4;
            },
            child: Hero(
              tag: 'profile_avatar',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Icon(
                  store.portal == Portal.officer
                      ? Icons.account_balance
                      : (store.portal == Portal.crew
                            ? Icons.engineering
                            : (store.portal == Portal.admin
                                  ? Icons.admin_panel_settings
                                  : Icons.person)),
                  color: isDark ? GovColors.gold : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Greeting & Location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        en
                            ? 'Namaste, ${store.userName} 👋'
                            : 'नमस्ते, ${store.userName} 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : GovColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openLocationPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: GovColors.navy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: GovColors.navy.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: GovColors.navy,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedLocation.name.split('—').first.trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: GovColors.navy,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: GovColors.navy,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => store.setLang(en ? AppLang.hi : AppLang.en),
                    child: Text(
                      en ? 'हिंदी' : 'English',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Municipal Access Hub removed as per user request (integrated into Tab 3)
              const SizedBox(height: 12),

              // 3. Weather Card (Interactive & Dynamic)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: isDark ? GovColors.bgDark : Colors.white,
                      title: Text(
                        store.t('मौसम का विवरण', 'Weather Details'),
                        style: TextStyle(
                          color: isDark ? Colors.white : GovColors.navy,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wb_cloudy,
                            size: 64,
                            color: GovColors.gold,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            store.weatherReady
                                ? '${store.weatherTemp.toStringAsFixed(1)}°C'
                                : '--°C',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            store.weatherReady
                                ? store.weatherMain
                                : store.t('डेटा उपलब्ध नहीं', 'Unavailable'),
                            style: const TextStyle(fontSize: 18),
                          ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(store.t('बारिश की दर:', 'Rain Rate:')),
                              Text(
                                store.weatherReady
                                    ? '${store.rainRate.toStringAsFixed(1)} mm/h'
                                    : '-- mm/h',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            store.t(store.weatherDescHi, store.weatherDescEn),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A2235)
                        : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        store.weatherMain.toLowerCase().contains('rain')
                            ? Icons.umbrella
                            : Icons.cloud,
                        size: 40,
                        color: isDark ? GovColors.gold : GovColors.navy,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.weatherReady
                                  ? store.t(
                                      '${store.weatherMain == 'Rain' ? 'भारी बारिश' : store.weatherMain} • ${store.rainRate.toStringAsFixed(1)} mm/घंटा',
                                      '${store.weatherMain} • ${store.rainRate.toStringAsFixed(1)} mm/h',
                                    )
                                  : store.t(
                                      'मौसम डेटा उपलब्ध नहीं',
                                      'Live weather unavailable',
                                    ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              store.weatherError ??
                                  store.t(
                                    store.weatherDescHi,
                                    store.weatherDescEn,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: store.weatherError != null
                                    ? GovColors.critical
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black45),
                              ),
                            ),
                            if (store.weatherLastUpdatedAt != null)
                              Text(
                                store.t(
                                  'अंतिम अपडेट ${store.weatherLastUpdatedAt!.hour.toString().padLeft(2, '0')}:${store.weatherLastUpdatedAt!.minute.toString().padLeft(2, '0')}',
                                  'Updated ${store.weatherLastUpdatedAt!.hour.toString().padLeft(2, '0')}:${store.weatherLastUpdatedAt!.minute.toString().padLeft(2, '0')}${store.weatherUsingStationFallback ? ' • nearest station' : ''}',
                                ),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Mega REPORT CTA
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportFlowScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF96816),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF96816).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'पानी भरी समस्या रिपोर्ट करें /',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Report Waterlogging',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Photo + GPS — 1 Tap mein',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (store.weatherError != null || !store.weatherReady)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.weatherError ??
                              store.t(
                                'लाइव मौसम डेटा लोड हो रहा है',
                                'Live weather data is loading',
                              ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: GovColors.critical,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: store.weatherLoading
                            ? null
                            : store.fetchWeather,
                        icon: store.weatherLoading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: Text(
                          store.t('फिर कोशिश', 'Retry'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // 4. Red Alert Banner (Dynamic from Notifications)
              if (store
                  .notificationsFor(Portal.citizen)
                  .any((n) => n.kind == NotifKind.emergency))
                Builder(
                  builder: (context) {
                    final latestAlert = store
                        .notificationsFor(Portal.citizen)
                        .firstWhere((n) => n.kind == NotifKind.emergency);
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: GovColors.critical,
                            title: Text(
                              store.t('आपातकालीन चेतावनी', 'Emergency Alert'),
                              style: const TextStyle(color: Colors.white),
                            ),
                            content: Text(
                              store.t(latestAlert.titleHi, latestAlert.titleEn),
                              style: const TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'DISMISS',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: GovColors.critical,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: GovColors.critical.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.t(
                                      latestAlert.titleHi,
                                      latestAlert.titleEn,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    store.t(
                                      'बाढ़ का स्तर बढ़ रहा है। कृपया सुरक्षित रहें।',
                                      'Flood levels rising. Please stay safe.',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // 5. Area Map Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    store.t('आपका क्षेत्र', 'Your Area'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final parentState = context
                          .findAncestorStateOfType<CitizenPortalState>();
                      // For Admin, index 2 is Analytics (which has map).
                      parentState?.tab = store.portal == Portal.admin ? 2 : 1;
                    },
                    child: Text(
                      store.t('विवरण देखें >', 'View details >'),
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  final parentState = context
                      .findAncestorStateOfType<CitizenPortalState>();
                  parentState?.tab = store.portal == Portal.admin ? 2 : 1;
                },
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark ? GovColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.map,
                          color: isDark
                              ? Colors.white24
                              : Colors.blue.withOpacity(0.2),
                          size: 60,
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.selectedLocation.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              store.t(
                                'Live intensity: Low',
                                'लाइव तीव्रता: कम',
                              ),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: Icon(
                          Icons.gps_fixed,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 6. Stats Grid
              Row(
                children: [
                  _StatCard(
                    label: store.t('Resolved', 'सुलझाए गए'),
                    value: store.verifiedIncidents.length.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () {
                      final parentState = context
                          .findAncestorStateOfType<State<CitizenPortal>>();
                      if (parentState is CitizenPortalState) {
                        // Admin: Index 1 is Admin Dashboard (where reports are verified/dispatched)
                        // Citizen: Index 2 is My Reports
                        parentState.tab = store.portal == Portal.admin ? 1 : 2;
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: store.t('Avg Time', 'औसत समय'),
                    value: '4.2h',
                    icon: Icons.access_time_filled,
                    color: Colors.blue,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? GovColors.bgDark : Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                store.t(
                                  'Response Time Analytics',
                                  'प्रतिक्रिया समय विश्लेषण',
                                ),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Our average response time has improved by 15% this week due to AI-based priority routing.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GovColors.navy,
                                ),
                                child: const Text(
                                  'OK',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: store.t('Merged', 'विलय किए गए'),
                    value: store.reports
                        .where((r) => r.incidentId.isNotEmpty)
                        .length
                        .toString(),
                    icon: Icons.merge_type,
                    color: Colors.purple,
                    onTap: () {
                      final parentState = context
                          .findAncestorStateOfType<State<CitizenPortal>>();
                      if (parentState is CitizenPortalState) {
                        // Admin: Index 2 is Analytics
                        // Citizen: Index 2 is My Reports
                        parentState.tab = store.portal == Portal.admin ? 2 : 2;
                      }
                    },
                  ),
                ],
              ),

              // Always show Portal Hub if user is not a plain citizen, or for demo
              // Municipal Response Hub removed from Home as per user request (moved to Profile/Integrated)
              const SizedBox(height: 24),

              const SizedBox(height: 24),

              // Quick Support Links
              Text(
                store.t('Quick Support', 'त्वरित सहायता'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              _PortalActionCard(
                title: en
                    ? 'FAQs & Help'
                    : 'अक्सर पूछे जाने वाले प्रश्न और सहायता',
                subtitle: en
                    ? 'Learn how to use NalaNetra'
                    : 'जानें कि नालनेत्र का उपयोग कैसे करें',
                icon: Icons.help_center,
                color: Colors.blueGrey,
                onTap: () {
                  final parentState = context
                      .findAncestorStateOfType<CitizenPortalState>();
                  if (parentState != null) {
                    // Admin: Support is index 4
                    // Citizen: Support is not a main tab, but let's navigate to Alerts (index 3) or open as screen
                    if (store.portal == Portal.admin) {
                      parentState.tab = 4;
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportPortal(),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  void _openLocationPicker(BuildContext context) {
    final store = context.read<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = store.pendingOtp.toLowerCase().trim();
          final results = gurugramLocations
              .where(
                (l) =>
                    query.isEmpty ||
                    l.name.toLowerCase().contains(query) ||
                    l.category.toLowerCase().contains(query),
              )
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? GovColors.bgDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  store.t('Choose Location', 'स्थान चुनें'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : GovColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setModalState(() => store.pendingOtp = v),
                  decoration: InputDecoration(
                    hintText: en
                        ? 'Search sector, road, landmark...'
                        : 'सेक्टर, सड़क, लैंडमार्क खोजें...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (ctx, i) {
                      final l = results[i];
                      return ListTile(
                        title: Text(
                          l.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          l.category,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        onTap: () {
                          store.setLocation(l);
                          store.pendingOtp = ''; // Clear temp search
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => store.pendingOtp = '');
  }
}

class _PortalActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PortalActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDark ? Colors.white : GovColors.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
            ],
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
