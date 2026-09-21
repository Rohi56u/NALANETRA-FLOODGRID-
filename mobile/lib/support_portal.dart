import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';
import 'settings_screen.dart';

class SupportPortal extends StatelessWidget {
  const SupportPortal({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : const Color(0xFFF8FAFC),
      appBar: GovHeader(
        title: store.t('Support & Help', 'सहायता और मदद'),
        subtitle: store.t('FAQs & User Guide', 'अक्सर पूछे जाने वाले प्रश्न'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSupportItem(
            context,
            'Frequently Asked Questions',
            'अक्सर पूछे जाने वाले प्रश्न',
            Icons.help_outline,
            isDark,
          ),
          _buildSupportItem(
            context,
            'User Guide & Tutorials',
            'उपयोगकर्ता गाइड और ट्यूटोरियल',
            Icons.menu_book,
            isDark,
          ),
          _buildSupportItem(
            context,
            'Contact Helpline',
            'हेल्पलाइन से संपर्क करें',
            Icons.phone_in_talk,
            isDark,
          ),
          _buildSupportItem(
            context,
            'Report a Technical Bug',
            'तकनीकी बग की रिपोर्ट करें',
            Icons.bug_report,
            isDark,
          ),
          const SizedBox(height: 24),
          _buildPolicyItem(
            context,
            'Terms of Service',
            'सेवा की शर्तें',
            'Standard Terms & Conditions for SIH 2026 FloodGrid platform. This system is for official municipal response and citizen safety.',
            isDark,
          ),
          _buildPolicyItem(
            context,
            'Privacy Policy',
            'गोपनीयता नीति',
            'Your data is encrypted and handled under Municipal Data Privacy Acts. We only collect location and photos for flood mitigation.',
            isDark,
          ),
          _buildPolicyItem(
            context,
            'Data Usage Policy',
            'डेटा उपयोग नीति',
            'Data is used solely for disaster response and mitigation analysis by authorized government officials.',
            isDark,
          ),
          const SizedBox(height: 40),
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
        ],
      ),
    );
  }

  Widget _buildSupportItem(
    BuildContext context,
    String titleEn,
    String titleHi,
    IconData icon,
    bool isDark,
  ) {
    final store = context.read<AppStore>();
    return InkWell(
      onTap: () {
        if (titleEn.toLowerCase().contains('faq') ||
            titleEn.toLowerCase().contains('frequently')) {
          _showFAQDialog(context, store, isDark);
        } else if (titleEn.toLowerCase().contains('guide')) {
          _showGuideDialog(context, store, isDark);
        } else if (titleEn.toLowerCase().contains('helpline')) {
          _showHelplineDialog(context, store, isDark);
        } else if (titleEn.toLowerCase().contains('bug')) {
          _showBugReportDialog(context, store, isDark);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 8),
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
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GovColors.navy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: GovColors.navy, size: 22),
          ),
          title: Text(
            store.t(titleEn, titleHi),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : GovColors.navy,
              fontSize: 14,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  void _showFAQDialog(BuildContext context, AppStore store, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? GovColors.bgDark : Colors.white,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    store.t(
                      'Frequently Asked Questions',
                      'अक्सर पूछे जाने वाले प्रश्न',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : GovColors.navy,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _faqItem(
                      context,
                      store.t(
                        'How does NalaNetra predict floods?',
                        'NalaNetra बाढ़ की भविष्यवाणी कैसे करता है?',
                      ),
                      store.t(
                        'We use Doppler Radar data and Digital Elevation Models (DEM) to simulate water flow across the city terrain in real-time. The system calculates surface runoff and drainage surcharge to predict inundation 3 hours in advance.',
                        'हम वास्तविक समय में शहर के इलाके में पानी के प्रवाह को अनुकरण करने के लिए डॉपलर रडार डेटा और डिजिटल एलीवेशन मॉडल (DEM) का उपयोग करते हैं। सिस्टम 3 घंटे पहले जलभराव की भविष्यवाणी करने के लिए सतह अपवाह और जल निकासी अधिभार की गणना करता है।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'What is the Priority Score?',
                        'प्राथमिकता स्कोर (Priority Score) क्या है?',
                      ),
                      store.t(
                        'It is an AI-calculated value (0 to 1) based on a weighted formula: P = 0.30(Severity) + 0.20(Rainfall) + 0.15(Ward Criticality) + 0.15(Drainage Capacity) + 0.10(Emergency Proximity) + 0.10(Alert History).',
                        'यह एक भारित सूत्र के आधार पर AI-गणना की गई वैल्यू (0 से 1) है: P = 0.30(Severity) + 0.20(Rainfall) + 0.15(Ward Criticality) + 0.15(Drainage Capacity) + 0.10(Emergency Proximity) + 0.10(Alert History)।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'Why should I report if the system is automated?',
                        'यदि सिस्टम स्वचालित है तो मुझे रिपोर्ट क्यों करनी चाहिए?',
                      ),
                      store.t(
                        'Citizen reports provide "Ground Truth". Your photos help re-calibrate our AI models to ensure 100% accuracy in specific street-level blockages that sensors might miss.',
                        'नागरिक रिपोर्ट "ग्राउंड ट्रुथ" प्रदान करती हैं। आपकी तस्वीरें विशिष्ट सड़क-स्तर के अवरोधों में 100% सटीकता सुनिश्चित करने के लिए हमारे AI मॉडल को फिर से कैलिब्रेट करने में मदद करती हैं जिन्हें सेंसर मिस कर सकते हैं।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'How do I know my complaint is resolved?',
                        'मुझे कैसे पता चलेगा कि मेरी शिकायत का समाधान हो गया है?',
                      ),
                      store.t(
                        'Once the crew fixes the issue, they upload a mandatory "Before-After" photo proof verified by the Zonal Officer. You can view this proof in the "My Reports" timeline.',
                        'एक बार जब क्रू समस्या को ठीक कर देता है, तो वे जोनल ऑफिसर द्वारा सत्यापित एक अनिवार्य "पहले-बाद" फोटो प्रमाण अपलोड करते हैं। आप इस प्रमाण को "मेरी रिपोर्ट" टाइमलाइन में देख सकते हैं।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'Can I report without an internet connection?',
                        'क्या मैं बिना इंटरनेट कनेक्शन के रिपोर्ट कर सकता हूँ?',
                      ),
                      store.t(
                        'Yes, the app supports offline reporting. Your report will be automatically synced as soon as you are back in network coverage.',
                        'हाँ, ऐप ऑफ़लाइन रिपोर्टिंग का समर्थन करता है। जैसे ही आप नेटवर्क कवरेज में वापस आएंगे, आपकी रिपोर्ट स्वचालित रूप से सिंक हो जाएगी।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'Is my data safe with the government?',
                        'क्या मेरा डेटा सरकार के पास सुरक्षित है?',
                      ),
                      store.t(
                        'Absolutely. We follow strict Data Usage Policies. Your location is only used for flood response and is never shared with third parties.',
                        'बिल्कुल। हम सख्त डेटा उपयोग नीतियों का पालन करते हैं। आपके स्थान का उपयोग केवल बाढ़ प्रतिक्रिया के लिए किया जाता है और इसे कभी भी तीसरे पक्ष के साथ साझा नहीं किया जाता है।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'What is Doppler Radar integration?',
                        'डॉपलर रडार एकीकरण क्या है?',
                      ),
                      store.t(
                        'NalaNetra pulls real-time reflectivity data from IMD Doppler Radars to calculate precise rainfall intensity (mm/hr) before it even hits the ground.',
                        'NalaNetra जमीन पर गिरने से पहले सटीक वर्षा की तीव्रता (मिमी/घंटा) की गणना करने के लिए IMD डॉपलर रडार से वास्तविक समय के परावर्तन डेटा को खींचता है।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'What happens if I report a duplicate?',
                        'यदि मैं डुप्लिकेट रिपोर्ट करता हूँ तो क्या होगा?',
                      ),
                      store.t(
                        'Our engine automatically merges reports within 150 meters and a 6-hour window into a single "Incident ID" to prevent municipal resource wastage.',
                        'हमारा इंजन नगरपालिका संसाधनों की बर्बादी को रोकने के लिए 150 मीटर और 6 घंटे की खिड़की के भीतर की रिपोर्टों को स्वचालित रूप से एक ही "इंसिडेंट आईडी" में मर्ज कर देता है।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'How do I contact the Municipal Control Room?',
                        'मैं नगर निगम कंट्रोल रूम से कैसे संपर्क करूं?',
                      ),
                      store.t(
                        'You can use the "Contact Helpline" option in the Support tab or dial 155304 directly for Gurugram Municipal Corporation.',
                        'आप सपोर्ट टैब में "हेल्पलाइन से संपर्क करें" विकल्प का उपयोग कर सकते हैं या गुरुग्राम नगर निगम के लिए सीधे 155304 डायल कर सकते हैं।',
                      ),
                      isDark,
                    ),
                    _faqItem(
                      context,
                      store.t(
                        'What is the "Admin" portal for?',
                        ' "एडमिन" पोर्टल किस लिए है?',
                      ),
                      store.t(
                        'The Admin portal is for Zonal Officers to monitor ward-level metrics, dispatch crews, and verify proof of work submitted by field teams.',
                        'एडमिन पोर्टल जोनल अधिकारियों के लिए वार्ड-स्तरीय मेट्रिक्स की निगरानी करने, क्रू भेजने और फील्ड टीमों द्वारा प्रस्तुत कार्य के प्रमाण को सत्यापित करने के लिए है।',
                      ),
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqItem(BuildContext context, String q, String a, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: PageStorageKey(q),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            q,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white : GovColors.navy,
            ),
          ),
          iconColor: GovColors.gold,
          collapsedIconColor: isDark ? Colors.white54 : GovColors.navy,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedAlignment: Alignment.topLeft,
          children: [
            Text(
              a,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuideDialog(BuildContext context, AppStore store, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? GovColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          store.t('User Guide', 'उपयोगकर्ता गाइड'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _guideStep('1', store.t('Snap Photo', 'फोटो खींचें'), isDark),
              _guideStep('2', store.t('AI Analysis', 'AI विश्लेषण'), isDark),
              _guideStep(
                '3',
                store.t('Submit Report', 'रिपोर्ट सबमिट करें'),
                isDark,
              ),
              _guideStep('4', store.t('Track Status', 'ट्रैक स्टेटस'), isDark),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(store.t('GOT IT', 'समझ गया')),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String num, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: GovColors.navy,
            child: Text(
              num,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelplineDialog(BuildContext context, AppStore store, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? GovColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          store.t('Emergency Helpline', 'आपातकालीन हेल्पलाइन'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helplineItem(
              context,
              '1070',
              'State Disaster Relief',
              GovColors.critical,
            ),
            _helplineItem(context, '100', 'Police', Colors.blue),
            _helplineItem(context, '101', 'Fire Brigade', Colors.orange),
            _helplineItem(
              context,
              '0124-2322877',
              'MCG Control Room',
              Colors.green,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(store.t('CLOSE', 'बंद करें')),
          ),
        ],
      ),
    );
  }

  Widget _helplineItem(
    BuildContext context,
    String num,
    String label,
    Color color,
  ) {
    return ListTile(
      leading: Icon(Icons.phone, color: color),
      title: Text(num, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(label, style: const TextStyle(fontSize: 10)),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling $label: $num...'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: GovColors.navy,
          ),
        );
      },
    );
  }

  void _showBugReportDialog(BuildContext context, AppStore store, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? GovColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          store.t('Report Technical Bug', 'तकनीकी बग रिपोर्ट करें'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: store.t(
                  'Describe the issue...',
                  'समस्या का वर्णन करें...',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(store.t('CANCEL', 'रद्द करें')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    store.t(
                      'Bug report submitted!',
                      'बग रिपोर्ट सबमिट कर दी गई!',
                    ),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: GovColors.navy),
            child: Text(
              store.t('SUBMIT', 'सबमिट करें'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyItem(
    BuildContext context,
    String titleEn,
    String titleHi,
    String content,
    bool isDark,
  ) {
    final store = context.read<AppStore>();
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              store.t(titleEn, titleHi),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showPolicyDialog(
    BuildContext context,
    AppStore store,
    String title,
    String content,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? GovColors.cardDark : Colors.white,
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w900),
        ),
        content: Text(content, style: GoogleFonts.hind()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(store.t('CLOSE', 'बंद करें')),
          ),
        ],
      ),
    );
  }
}
