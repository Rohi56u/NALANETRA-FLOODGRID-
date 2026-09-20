import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';
import 'citizen_home.dart';
import 'analytics_portal.dart';
import 'emergency_portal.dart';
import 'support_portal.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _subTab = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;

    // Deep Integration: Remove nested Scaffold/BottomNav to fit into Citizen Shell
    return Column(
      children: [
        // Sub-navigation header for Admin - Added explicit height and padding to avoid overlap
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _subTabBtn(0, Icons.dashboard, store.t('Stats', 'आंकड़े')),
              _subTabBtn(1, Icons.people, store.t('Users', 'उपयोगकर्ता')),
              _subTabBtn(2, Icons.map, store.t('Wards', 'वार्ड')),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _subTab,
            children: [
              _AdminMainTab(onSetTab: (i) => setState(() => _subTab = i)),
              const _UserManagementTab(),
              const _WardManagementTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subTabBtn(int index, IconData icon, String label) {
    final active = _subTab == index;
    final isDark = context.read<AppStore>().themeMode == AppThemeMode.dark;
    return InkWell(
      onTap: () => setState(() => _subTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active
                ? GovColors.gold
                : (isDark ? Colors.white54 : Colors.grey),
            size: 20,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? GovColors.gold
                  : (isDark ? Colors.white54 : Colors.grey),
            ),
          ),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 20,
              color: GovColors.gold,
            ),
        ],
      ),
    );
  }
}

class _AdminMainTab extends StatelessWidget {
  final Function(int) onSetTab;
  const _AdminMainTab({required this.onSetTab});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemHealth(context, isDark, en),
          const SizedBox(height: 24),
          Text(
            store.t('Quick Management', 'त्वरित प्रबंधन'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : GovColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(context, isDark, en),
          const SizedBox(height: 24),
          Text(
            store.t('Real-time Metrics', 'रियल-टाइम मेट्रिक्स'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : GovColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsGrid(context, isDark),
          const SizedBox(height: 24),
          Text(
            store.t('System Audit Log', 'सिस्टम ऑडिट लॉग'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : GovColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentActivity(context, isDark, en),
        ],
      ),
    );
  }

  Widget _buildSystemHealth(BuildContext context, bool isDark, bool en) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [GovColors.navyDeep, GovColors.navy],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: GovColors.gold, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NALANETRA CORE GRID',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      en
                          ? 'Infrastructure Status: OPTIMAL'
                          : 'इन्फ्रास्ट्रक्चर स्थिति: इष्टतम',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, color: Colors.greenAccent, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArchNode(
                label: 'Citizen App',
                status: 'Active',
                icon: Icons.smartphone,
              ),
              _ArchConnector(),
              _ArchNode(
                label: 'AI Core',
                status: '98.4%',
                icon: Icons.psychology,
              ),
              _ArchConnector(),
              _ArchNode(label: 'Command', status: '14ms', icon: Icons.dns),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _ArchSmallNode(label: 'MySQL DB', status: 'Connected'),
              _ArchSmallNode(label: 'S3 Storage', status: 'Healthy'),
              _ArchSmallNode(label: 'SMS Gateway', status: 'Ready'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark, bool en) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildActionBtn(
          context,
          en ? 'Analytics' : 'एनालिटिक्स',
          Icons.analytics,
          Colors.blue,
          isDark,
          () {
            final parentState = context
                .findAncestorStateOfType<CitizenPortalState>();
            if (parentState != null) parentState.tab = 2;
          },
        ),
        _buildActionBtn(
          context,
          en ? 'Emergency' : 'इमरजेंसी',
          Icons.campaign,
          GovColors.critical,
          isDark,
          () {
            final parentState = context
                .findAncestorStateOfType<CitizenPortalState>();
            if (parentState != null) parentState.tab = 3;
          },
        ),
        _buildActionBtn(
          context,
          en ? 'Support' : 'सपोर्ट',
          Icons.help_center,
          Colors.blueGrey,
          isDark,
          () {
            final parentState = context
                .findAncestorStateOfType<CitizenPortalState>();
            if (parentState != null) parentState.tab = 4;
          },
        ),
        _buildActionBtn(
          context,
          en ? 'Wards' : 'वार्ड',
          Icons.map,
          Colors.teal,
          isDark,
          () => onSetTab(2),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : GovColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isDark) {
    final store = context.watch<AppStore>();
    final en = store.lang == AppLang.en;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          en ? 'Active Reports' : 'सक्रिय रिपोर्ट',
          store.reports.length.toString(),
          Icons.report_problem,
          GovColors.orange,
          isDark,
        ),
        _buildStatCard(
          context,
          en ? 'Crew Online' : 'क्रू ऑनलाइन',
          '${store.jobs.where((j) => j.status == IncidentLifecycle.dispatched).length + 40}/60',
          Icons.engineering,
          Colors.blue,
          isDark,
        ),
        _buildStatCard(
          context,
          en ? 'Avg Response' : 'औसत प्रतिक्रिया',
          '14m',
          Icons.timer,
          Colors.green,
          isDark,
        ),
        _buildStatCard(
          context,
          en ? 'Escalations' : 'एस्केलेशन',
          store.reports
              .where((r) => r.severityScore > 0.8)
              .length
              .toString()
              .padLeft(2, '0'),
          Icons.warning,
          GovColors.critical,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _showStatDetail(context, label, value, color, isDark),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : GovColors.navy,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDark, bool en) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          _auditItem(
            en ? 'Admin Login' : 'एडमिन लॉगिन',
            'SuperUser-01',
            '2m ago',
            isDark,
          ),
          const Divider(),
          _auditItem(
            en ? 'Ward Updated' : 'वार्ड अपडेट',
            'Sector 14 Hotspot',
            '15m ago',
            isDark,
          ),
          const Divider(),
          _auditItem(
            en ? 'Mass Broadcast' : 'मास ब्रॉडकास्ट',
            'Red Alert Issued',
            '1h ago',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _auditItem(String title, String sub, String time, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: GovColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showStatDetail(
    BuildContext context,
    String label,
    String val,
    Color col,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? GovColors.bgDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: col),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: GovColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Current Value: $val',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: col,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Real-time monitoring enabled. This data is synced with the municipal command centre every 15 seconds.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: GovColors.navy,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'VIEW FULL REPORT',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ArchNode extends StatelessWidget {
  final String label;
  final String status;
  final IconData icon;
  const _ArchNode({
    required this.label,
    required this.status,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          status,
          style: const TextStyle(color: Colors.greenAccent, fontSize: 8),
        ),
      ],
    );
  }
}

class _ArchConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 1,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ArchSmallNode extends StatelessWidget {
  final String label;
  final String status;
  const _ArchSmallNode({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          status,
          style: const TextStyle(color: Colors.greenAccent, fontSize: 8),
        ),
      ],
    );
  }
}

class _UserManagementTab extends StatelessWidget {
  const _UserManagementTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _userItem('Arjun Sharma', 'MCG-OFFICER-001', 'Officer', true),
        _userItem('Vikram Singh', 'MCG-CREW-772', 'Crew', true),
        _userItem('Neha Gupta', 'MCG-OFFICER-004', 'Officer', false),
        _userItem('Rahul Verma', 'MCG-CREW-102', 'Crew', true),
      ],
    );
  }

  Widget _userItem(String name, String id, String role, bool active) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: GovColors.navy,
          child: Text(name[0], style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$id • $role'),
        trailing: Switch(
          value: active,
          onChanged: (v) {
            // Mock toggle for demo
          },
        ),
      ),
    );
  }
}

class _WardManagementTab extends StatelessWidget {
  const _WardManagementTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _wardItem('Ward 14', 'Sector 14, 15, 17', 'Active', Colors.red),
        _wardItem('Ward 26', 'Sector 26, 27, 28', 'Normal', Colors.green),
        _wardItem('Ward 08', 'Sector 8, 9, 10', 'Alert', Colors.orange),
      ],
    );
  }

  Widget _wardItem(String name, String areas, String status, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.map, color: color),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(areas),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
