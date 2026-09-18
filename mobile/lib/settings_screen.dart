import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final ink = dark ? Colors.white : GovColors.navy;
    final secondary = dark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: dark ? GovColors.bgDark : GovColors.bgLight,
      appBar: GovHeader(
        title: en ? 'Settings & Preferences' : 'सेटिंग्स और प्राथमिकताएं',
        subtitle: en
            ? 'Accessibility, privacy and service controls'
            : 'सुगमता, गोपनीयता और सेवा नियंत्रण',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(
            en ? 'Display & Accessibility' : 'डिस्प्ले और सुगमता',
            ink,
          ),
          _settingTile(
            context,
            icon: dark ? Icons.dark_mode : Icons.light_mode,
            title: en ? 'Appearance' : 'दिखावट',
            subtitle: dark
                ? (en ? 'Dark mode' : 'डार्क मोड')
                : (en ? 'Light mode' : 'लाइट मोड'),
            trailing: Switch(
              value: dark,
              activeColor: GovColors.gold,
              onChanged: (value) => store.setTheme(
                value ? AppThemeMode.dark : AppThemeMode.light,
              ),
            ),
            ink: ink,
            secondary: secondary,
          ),
          _settingTile(
            context,
            icon: Icons.language,
            title: en ? 'Language' : 'भाषा',
            subtitle: en ? 'English / हिंदी' : 'हिंदी / English',
            trailing: SegmentedButton<AppLang>(
              segments: const [
                ButtonSegment(value: AppLang.en, label: Text('EN')),
                ButtonSegment(value: AppLang.hi, label: Text('हिंदी')),
              ],
              selected: {store.lang},
              onSelectionChanged: (values) => store.setLang(values.first),
            ),
            ink: ink,
            secondary: secondary,
          ),
          const SizedBox(height: 18),
          _sectionTitle(
            en ? 'Service Configuration' : 'सेवा कॉन्फ़िगरेशन',
            ink,
          ),
          _settingTile(
            context,
            icon: Icons.cloud_done,
            title: en ? 'Live weather service' : 'लाइव मौसम सेवा',
            subtitle: store.weatherReady
                ? (en
                      ? 'Connected observations are updating'
                      : 'कनेक्टेड ऑब्जर्वेशन अपडेट हो रहे हैं')
                : (en
                      ? 'Waiting for a valid observation'
                      : 'मान्य ऑब्जर्वेशन की प्रतीक्षा'),
            trailing: Icon(
              store.weatherReady ? Icons.check_circle : Icons.info_outline,
              color: store.weatherReady ? GovColors.ok : GovColors.gold,
            ),
            ink: ink,
            secondary: secondary,
          ),
          _settingTile(
            context,
            icon: Icons.dns_outlined,
            title: en
                ? 'FloodGrid service endpoint'
                : 'फ्लडग्रिड सेवा एंडपॉइंट',
            subtitle: store.backendStatus == 'Not checked'
                ? nalanetraBackendBaseUrl
                : '${store.backendStatus} • $nalanetraBackendBaseUrl',
            trailing: IconButton(
              tooltip: en ? 'Check connection' : 'कनेक्शन जांचें',
              onPressed: store.backendChecking
                  ? null
                  : store.checkBackendConnection,
              icon: store.backendChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      store.backendReachable ? Icons.cloud_done : Icons.refresh,
                      size: 19,
                    ),
            ),
            ink: ink,
            secondary: secondary,
          ),
          _settingTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: en ? 'Operational notifications' : 'ऑपरेशनल नोटिफिकेशन',
            subtitle: en
                ? 'Incident and weather updates remain enabled'
                : 'इंसिडेंट और मौसम अपडेट चालू हैं',
            trailing: const Icon(
              Icons.notifications_active,
              color: GovColors.ok,
            ),
            ink: ink,
            secondary: secondary,
          ),
          const SizedBox(height: 18),
          _sectionTitle(en ? 'Data & Policies' : 'डेटा और नीतियां', ink),
          _actionTile(
            context,
            icon: Icons.policy_outlined,
            title: en
                ? 'Terms, Privacy & Data Usage'
                : 'शर्तें, गोपनीयता और डेटा उपयोग',
            subtitle: en
                ? 'Read the prototype policy document'
                : 'प्रोटोटाइप नीति दस्तावेज़ पढ़ें',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
            ),
            ink: ink,
            secondary: secondary,
          ),
          _actionTile(
            context,
            icon: Icons.help_outline,
            title: en ? 'Help & Support' : 'सहायता और समर्थन',
            subtitle: en
                ? 'FAQs, user guide and helpline'
                : 'प्रश्न, उपयोगकर्ता गाइड और हेल्पलाइन',
            onTap: () => Navigator.pushNamed(context, '/support'),
            ink: ink,
            secondary: secondary,
          ),
          const SizedBox(height: 18),
          Text(
            en
                ? 'NalaNetra FloodGrid • SIH 2026 prototype'
                : 'नालनेत्र फ्लडग्रिड • SIH 2026 प्रोटोटाइप',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
    ),
  );

  Widget _settingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required Color ink,
    required Color secondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: secondary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: GovColors.gold, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: secondary, fontSize: 10.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color ink,
    required Color secondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: _settingTile(
        context,
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: const Icon(Icons.chevron_right),
        ink: ink,
        secondary: secondary,
      ),
    );
  }
}

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final dark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final ink = dark ? Colors.white : GovColors.navy;
    final secondary = dark ? Colors.white70 : Colors.black87;
    return Scaffold(
      backgroundColor: dark ? GovColors.bgDark : GovColors.bgLight,
      appBar: GovHeader(
        title: en ? 'Terms & Privacy' : 'शर्तें और गोपनीयता',
        subtitle: en
            ? 'NalaNetra FloodGrid policy document'
            : 'नालनेत्र फ्लडग्रिड नीति दस्तावेज़',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _policyBlock(
            context,
            en ? '1. Purpose and scope' : '1. उद्देश्य और दायरा',
            en
                ? 'NalaNetra FloodGrid is an SIH 2026 prototype for coordinating citizen waterlogging reports, municipal response, and proof-based closure. It is not a substitute for emergency services.'
                : 'नालनेत्र फ्लडग्रिड SIH 2026 का प्रोटोटाइप है जो नागरिक जलभराव रिपोर्ट, नगर निगम प्रतिक्रिया और प्रमाण-आधारित समाधान को समन्वित करता है। यह आपातकालीन सेवाओं का विकल्प नहीं है।',
            ink,
            secondary,
          ),
          _policyBlock(
            context,
            en ? '2. Information collected' : '2. एकत्र की जाने वाली जानकारी',
            en
                ? 'A report may contain a name, phone number, location, timestamp, flood-level selection, and submitted photographs. Staff accounts use issued role identifiers.'
                : 'रिपोर्ट में नाम, मोबाइल नंबर, स्थान, समय, जल-स्तर चयन और भेजी गई तस्वीरें हो सकती हैं। स्टाफ खाते जारी किए गए भूमिका पहचान-पत्र का उपयोग करते हैं।',
            ink,
            secondary,
          ),
          _policyBlock(
            context,
            en ? '3. Use and retention' : '3. उपयोग और संरक्षण',
            en
                ? 'Information is used for incident triage, crew dispatch, public safety alerts, analytics, and closure verification. Access should be limited to authorized response personnel and retained only for the approved municipal purpose.'
                : 'जानकारी का उपयोग इंसिडेंट प्राथमिकता, क्रू डिस्पैच, जन-सुरक्षा अलर्ट, एनालिटिक्स और समाधान सत्यापन के लिए किया जाता है। पहुंच अधिकृत प्रतिक्रिया कर्मियों तक सीमित होनी चाहिए और स्वीकृत नगर निगम उद्देश्य के लिए ही रखी जानी चाहिए।',
            ink,
            secondary,
          ),
          _policyBlock(
            context,
            en ? '4. Evidence and transparency' : '4. प्रमाण और पारदर्शिता',
            en
                ? 'Incident status and before/after evidence are shown to support accountable municipal action. Demo records in this prototype are not official civic records.'
                : 'जवाबदेह नगर निगम कार्रवाई के लिए इंसिडेंट स्थिति और पहले/बाद के प्रमाण दिखाए जाते हैं। इस प्रोटोटाइप के डेमो रिकॉर्ड आधिकारिक नागरिक रिकॉर्ड नहीं हैं।',
            ink,
            secondary,
          ),
          _policyBlock(
            context,
            en ? '5. Emergency disclaimer' : '5. आपातकालीन अस्वीकरण',
            en
                ? 'For immediate danger, contact the appropriate local emergency service. Do not wait for an app notification or crew assignment.'
                : 'तत्काल खतरे में उचित स्थानीय आपातकालीन सेवा से संपर्क करें। ऐप नोटिफिकेशन या क्रू असाइनमेंट की प्रतीक्षा न करें।',
            ink,
            secondary,
          ),
          const SizedBox(height: 12),
          Text(
            en
                ? 'Prototype policy • Review with the responsible municipal authority before public deployment.'
                : 'प्रोटोटाइप नीति • सार्वजनिक उपयोग से पहले जिम्मेदार नगर निगम प्राधिकरण से समीक्षा कराएं।',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondary.withValues(alpha: 0.7),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyBlock(
    BuildContext context,
    String heading,
    String body,
    Color ink,
    Color secondary,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: secondary.withValues(alpha: 0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          style: TextStyle(color: secondary, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}
