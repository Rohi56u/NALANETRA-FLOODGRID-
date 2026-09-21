import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

class EmergencyPortal extends StatefulWidget {
  const EmergencyPortal({super.key});

  @override
  State<EmergencyPortal> createState() => _EmergencyPortalState();
}

class _EmergencyPortalState extends State<EmergencyPortal> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF8FAFC),
      appBar: GovHeader(
        title: en ? 'Emergency Center' : 'आपातकालीन केंद्र',
        subtitle: en
            ? 'Broadcast & Resource Management'
            : 'प्रसारण और संसाधन प्रबंधन',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBroadcastSection(context, store, en, isDark),
          const SizedBox(height: 24),
          _buildInventorySection(context, store, en, isDark),
          const SizedBox(height: 24),
          _buildQuickAlerts(context, store, en, isDark),
        ],
      ),
    );
  }

  Widget _buildBroadcastSection(
    BuildContext context,
    AppStore store,
    bool en,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _showBroadcastDialog(context, store, en),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [GovColors.critical, GovColors.critical.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: GovColors.critical.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.campaign, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              en ? 'EMERGENCY BROADCAST' : 'आपातकालीन प्रसारण',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              en
                  ? 'Send mass alerts to all citizens in specific wards.'
                  : 'विशिष्ट वार्डों के सभी नागरिकों को मास अलर्ट भेजें।',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showBroadcastDialog(context, store, en),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: GovColors.critical,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                en ? 'INITIATE BROADCAST' : 'प्रसारण शुरू करें',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context, AppStore store, bool en) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: store.themeMode == AppThemeMode.dark
              ? GovColors.bgDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Text(
              en ? 'Initiate Mass Broadcast' : 'मास ब्रॉडकास्ट शुरू करें',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: GovColors.critical,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: en ? 'Alert Message' : 'अलर्ट संदेश',
                hintText: en
                    ? 'e.g. Heavy rainfall expected in Sector 14...'
                    : 'उदा. सेक्टर 14 में भारी बारिश की संभावना...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: en ? 'Target Area' : 'लक्ष्य क्षेत्र',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                'All Gurugram',
                'Sector 14',
                'Sector 26',
                'NH-48',
                'Civil Hospital Zone',
              ].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
              onChanged: (_) {},
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                store.addNotification(
                  Notif(
                    kind: NotifKind.weather,
                    titleEn: en
                        ? 'EMERGENCY: Heavy rainfall alert issued'
                        : 'आपातकालीन: भारी बारिश का अलर्ट जारी',
                    titleHi: 'गुरुग्राम के चयनित क्षेत्रों में भारी बारिश का अलर्ट जारी किया गया है।',
                    imagePath: AppStore.municipalNotificationImages.first,
                    municipalImagePath:
                        AppStore.municipalNotificationImages.first,
                    locationName: store.selectedLocation.name,
                    severityBand: SeverityBand.severe,
                    severityScore: 0.82,
                    audiences: const {NotifAudience.municipal},
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      en
                          ? 'Broadcast sent to all devices!'
                          : 'सभी उपकरणों को प्रसारण भेजा गया!',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GovColors.critical,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                en ? 'SEND BROADCAST NOW' : 'अभी ब्रॉडकास्ट भेजें',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showResourceDetail(
    BuildContext context,
    String name,
    String total,
    String active,
    String dept,
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
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: GovColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Department: $dept',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _detailStat('TOTAL UNITS', total, Colors.blue),
                const SizedBox(width: 24),
                _detailStat('OPERATIONAL', active, Colors.green),
              ],
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
                'MANAGE INVENTORY',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(String label, String val, Color col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          val,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: col,
          ),
        ),
      ],
    );
  }

  Widget _buildInventorySection(
    BuildContext context,
    AppStore store,
    bool en,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          en ? 'Resource Inventory' : 'संसाधन सूची',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : GovColors.navy,
          ),
        ),
        const SizedBox(height: 16),
        _InventoryItem(
          label: en ? 'High-Power Pumps' : 'हाई-पावर पंप',
          total: '12 Units',
          active: '8 Active',
          icon: Icons.waves,
          color: Colors.blue,
          isDark: isDark,
          onTap: () => _showResourceDetail(
            context,
            en ? 'High-Power Pumps' : 'हाई-पावर पंप',
            '12',
            '8',
            'Drainage Wing',
            isDark,
          ),
        ),
        _InventoryItem(
          label: en ? 'Rescue Boats' : 'बचाव नौकाएं',
          total: '04 Units',
          active: '2 Ready',
          icon: Icons.sailing,
          color: Colors.orange,
          isDark: isDark,
          onTap: () => _showResourceDetail(
            context,
            en ? 'Rescue Boats' : 'बचाव नौकाएं',
            '04',
            '2',
            'NDRF Support',
            isDark,
          ),
        ),
        _InventoryItem(
          label: en ? 'Sandbags' : 'रेत की बोरियां',
          total: '2,500 Units',
          active: '1.2k Stock',
          icon: Icons.inventory_2,
          color: Colors.brown,
          isDark: isDark,
          onTap: () => _showResourceDetail(
            context,
            en ? 'Sandbags' : 'रेत की बोरियां',
            '2,500',
            '1.2k',
            'Civil Defense',
            isDark,
          ),
        ),
        _InventoryItem(
          label: en ? 'Emergency Vehicles' : 'आपातकालीन वाहन',
          total: '08 Units',
          active: '6 Deployed',
          icon: Icons.local_shipping,
          color: Colors.red,
          isDark: isDark,
          onTap: () => _showResourceDetail(
            context,
            en ? 'Emergency Vehicles' : 'आपातकालीन वाहन',
            '08',
            '6',
            'Traffic Police',
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAlerts(
    BuildContext context,
    AppStore store,
    bool en,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: GovColors.gold),
              const SizedBox(width: 8),
              Text(
                en ? 'Active Weather Alerts' : 'सक्रिय मौसम अलर्ट',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AlertItem(
            msg: 'Orange Alert: Heavy Rain in 2 hours',
            time: '10m ago',
            isDark: isDark,
          ),
          _AlertItem(
            msg: 'Flood Risk: Sector 14 water level rising',
            time: '25m ago',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  final String label;
  final String total;
  final String active;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _InventoryItem({
    required this.label,
    required this.total,
    required this.active,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    active,
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  total.split(' ')[0],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: GovColors.navy,
                  ),
                ),
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final String msg;
  final String time;
  final bool isDark;
  const _AlertItem({
    required this.msg,
    required this.time,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
