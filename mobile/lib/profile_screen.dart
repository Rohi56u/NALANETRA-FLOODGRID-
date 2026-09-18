import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';
import 'citizen_home.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    return Column(
      children: [
        GovHeader(
          title: 'NalaNetra FloodGrid',
          subtitle: en
              ? 'User Profile & Settings'
              : 'उपयोगकर्ता प्रोफ़ाइल और सेटिंग्स',
          trailing: const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            children: [
              // Profile card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2238) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: GovColors.navy,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        store.userName.isNotEmpty ? store.userName[0] : 'W',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.userName.isNotEmpty
                                ? store.userName
                                : 'WhatsApp User',
                            style: TextStyle(
                              color: isDark ? Colors.white : GovColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            store.portal == Portal.officer
                                ? 'Municipal Officer'
                                : (store.portal == Portal.crew
                                      ? 'Field Crew'
                                      : (store.portal == Portal.admin
                                            ? 'Super Admin'
                                            : 'Citizen portal')),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black45,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Language
              _settingRow(
                context,
                isDark,
                icon: Icons.language,
                title: en ? 'Language / भाषा' : 'भाषा / Language',
                subtitle: store.lang == AppLang.en ? 'English' : 'हिंदी',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _langChip(
                      context,
                      'EN',
                      store.lang == AppLang.en,
                      () => store.setLang(AppLang.en),
                      isDark,
                    ),
                    const SizedBox(width: 5),
                    _langChip(
                      context,
                      'हिंदी',
                      store.lang == AppLang.hi,
                      () => store.setLang(AppLang.hi),
                      isDark,
                    ),
                  ],
                ),
              ),

              // Theme
              _settingRow(
                context,
                isDark,
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: en ? 'Theme' : 'थीम',
                subtitle: isDark ? 'Dark mode' : 'Light mode',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _themeChip(
                      context,
                      Icons.light_mode,
                      !isDark,
                      () => store.setTheme(AppThemeMode.light),
                      isDark,
                    ),
                    const SizedBox(width: 5),
                    _themeChip(
                      context,
                      Icons.dark_mode,
                      isDark,
                      () => store.setTheme(AppThemeMode.dark),
                      isDark,
                    ),
                  ],
                ),
              ),

              // Login Info
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GovColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GovColors.gold.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: GovColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          en
                              ? 'Installation & Login Info'
                              : 'स्थापना और लॉगिन जानकारी',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : GovColors.navy,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      en
                          ? '• Demo Login: No password required for SIH evaluation.\n• Installation: Tap "Add to Home Screen" in browser for full PWA experience.'
                          : '• डेमो लॉगिन: SIH मूल्यांकन के लिए पासवर्ड की आवश्यकता नहीं है।\n• स्थापना: पूर्ण PWA अनुभव के लिए ब्राउज़र में "होम स्क्रीन पर जोड़ें" पर टैप करें।',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Dedicated settings and policy surfaces
              _settingRow(
                context,
                isDark,
                icon: Icons.settings_outlined,
                title: en
                    ? 'Settings & Preferences'
                    : 'सेटिंग्स और प्राथमिकताएं',
                subtitle: en
                    ? 'Accessibility, service and data controls'
                    : 'सुगमता, सेवा और डेटा नियंत्रण',
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ),
              _settingRow(
                context,
                isDark,
                icon: Icons.policy_outlined,
                title: en ? 'Terms & Privacy' : 'शर्तें और गोपनीयता',
                subtitle: en
                    ? 'Read the FloodGrid policy document'
                    : 'फ्लडग्रिड नीति दस्तावेज़ पढ़ें',
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () => Navigator.pushNamed(context, '/terms'),
                ),
              ),

              // Help & Support
              _settingRow(
                context,
                isDark,
                icon: Icons.help_outline,
                title: en ? 'Help & Support' : 'सहायता और मदद',
                subtitle: en
                    ? 'FAQs & User Guide'
                    : 'अक्सर पूछे जाने वाले प्रश्न',
                trailing: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () => Navigator.pushNamed(context, '/support'),
                ),
              ),

              if (store.portal == Portal.admin)
                _settingRow(
                  context,
                  isDark,
                  icon: Icons.admin_panel_settings,
                  title: en ? 'Admin Command Center' : 'एडमिन कमांड सेंटर',
                  subtitle: en
                      ? 'Ward Analytics & Crew Dispatch'
                      : 'वार्ड एनालिटिक्स और क्रू डिस्पैच',
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: () {
                      final parentState = context
                          .findAncestorStateOfType<CitizenPortalState>();
                      if (parentState != null) {
                        parentState.tab = 1; // Tab 1 is Admin in CitizenPortal
                      }
                    },
                  ),
                ),

              const SizedBox(height: 10),

              // Emergency
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2238) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emergency,
                          color: GovColors.critical,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          en ? 'Emergency Contacts' : 'आपातकालीन संपर्क',
                          style: TextStyle(
                            color: isDark ? Colors.white : GovColors.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _emergency(context, 'MCG Control Room', '155304', isDark),
                    const SizedBox(height: 6),
                    _emergency(
                      context,
                      'Water Board Helpline',
                      '1800-180-3004',
                      isDark,
                    ),
                    const SizedBox(height: 6),
                    _emergency(context, 'Police', '100', isDark),
                    const SizedBox(height: 6),
                    _emergency(context, 'Ambulance', '108', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Logout
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    store.logout();
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text(en ? 'Logout' : 'लॉगआउट'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GovColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'App Version 4.2.0 (SIH 2026 Edition)',
                  style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emergency(
    BuildContext ctx,
    String label,
    String number,
    bool isDark,
  ) {
    return Row(
      children: [
        const Icon(Icons.phone, size: 13, color: GovColors.navy),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF3A4460),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: GovColors.navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: GovColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingRow(
    BuildContext ctx,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2238) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: isDark ? GovColors.gold : GovColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : GovColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black45,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _langChip(
    BuildContext ctx,
    String label,
    bool active,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? GovColors.navy
              : (isDark ? Colors.white12 : const Color(0xFFF0F2F8)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? GovColors.navy : Colors.black12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF3A4460)),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _themeChip(
    BuildContext ctx,
    IconData icon,
    bool active,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active
              ? GovColors.navy
              : (isDark ? Colors.white12 : const Color(0xFFF0F2F8)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? GovColors.navy : Colors.black12),
        ),
        child: Icon(
          icon,
          size: 15,
          color: active
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF3A4460)),
        ),
      ),
    );
  }

  Widget _hubIcon(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GovColors.navy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: GovColors.navy, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : GovColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
