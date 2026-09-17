import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final reports = store.reports;

    return Column(
      children: [
        GovHeader(
          title: en ? 'My Reports' : 'मेरी रिपोर्ट',
          subtitle: en
              ? '${reports.length} reports filed'
              : '${reports.length} रिपोर्ट दर्ज',
        ),
        Expanded(
          child: reports.isEmpty
              ? _buildEmptyState(isDark, en)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportItem(
                      context,
                      report,
                      isDark,
                      en,
                      index == 0,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, bool en) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: isDark ? Colors.white10 : Colors.grey[200],
          ),
          const SizedBox(height: 16),
          Text(
            en ? 'No reports yet' : 'अभी तक कोई रिपोर्ट नहीं',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(
    BuildContext context,
    FloodReport report,
    bool isDark,
    bool en,
    bool isFirst,
  ) {
    final store = context.read<AppStore>();
    final status = store.statusOf(report.incidentId);
    final job = store.jobFor(report.incidentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? GovColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: isFirst,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      report.id,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      report.isSynced
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_queue_rounded,
                      size: 14,
                      color: report.isSynced ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
                _StatusChip(status: status, en: en),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              report.locationName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Text(
          _formatDate(report.at, en),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 16),
                _buildTimeline(context, report, status, job, en, isDark),
                const SizedBox(height: 24),
                if (status == IncidentLifecycle.verified)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            en ? 'Problem resolved and verified by MCG.' : 'समस्या का समाधान हो गया और MCG द्वारा सत्यापित किया गया।',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    FloodReport report,
    IncidentLifecycle status,
    CrewJob? job,
    bool en,
    bool isDark,
  ) {
    final hasProof = job?.hasAfterProof == true;
    return Column(
      children: [
        _TimelineStep(
          title: en ? 'Reported' : 'रिपोर्ट किया गया',
          time: _formatTime(report.at),
          isActive: true,
          isFirst: true,
          isDark: isDark,
          onTap: () => _showTimelineDetail(
            context,
            en ? 'Reported' : 'रिपोर्ट किया गया',
            en
                ? 'Your report was received by the system.'
                : 'आपकी रिपोर्ट सिस्टम द्वारा प्राप्त की गई थी।',
            isDark,
          ),
        ),
        _TimelineStep(
          title: en ? 'Merged' : 'विलय किया गया',
          time: _formatTime(report.at.add(const Duration(minutes: 2))),
          isActive: status != IncidentLifecycle.submitted,
          isDark: isDark,
          onTap: () => _showTimelineDetail(
            context,
            en ? 'Merged' : 'विलय किया गया',
            en
                ? 'AI merged this with 11 other reports in this area.'
                : 'AI ने इसे इस क्षेत्र की 11 अन्य रिपोर्टों के साथ जोड़ दिया।',
            isDark,
          ),
        ),
        _TimelineStep(
          title: en ? 'Dispatched' : 'भेजा गया',
          time: job != null ? _formatTime(job.dispatchedAt) : '--:--',
          isActive: job != null,
          isDark: isDark,
          onTap: () => _showTimelineDetail(
            context,
            en ? 'Dispatched' : 'भेजा गया',
            en
                ? 'Crew-07 has been assigned to this incident.'
                : 'क्रू-07 को इस घटना के लिए नियुक्त किया गया है।',
            isDark,
          ),
        ),
        _TimelineStep(
          title: en ? 'Proof Submitted' : 'प्रमाण जमा किया',
          time: hasProof
              ? _formatTime(job!.afterUploadedAt ?? job.dispatchedAt)
              : '--:--',
          isActive: hasProof,
          isDark: isDark,
          onTap: () => _showTimelineDetail(
            context,
            en ? 'Proof Submitted' : 'प्रमाण जमा किया',
            en
                ? (hasProof
                      ? 'Work completed. Before/After photos uploaded for this incident.'
                      : 'The crew has not uploaded the cleanup photo yet.')
                : (hasProof
                      ? 'इस घटना के लिए काम पूरा हुआ। पहले/बाद की तस्वीरें अपलोड हैं।'
                      : 'क्रू ने अभी सफाई के बाद की तस्वीर अपलोड नहीं की है।'),
            isDark,
            showProof: true,
            beforePath: job?.beforePhotoPath ?? report.photoPath,
            afterPath: hasProof ? job!.afterPhotoPath : null,
          ),
        ),
        _TimelineStep(
          title: en ? 'Verified' : 'सत्यापित',
          time: status == IncidentLifecycle.verified
              ? _formatTime(
                  job?.dispatchedAt.add(const Duration(minutes: 25)) ??
                      DateTime.now(),
                )
              : '--:--',
          isActive: status == IncidentLifecycle.verified,
          isLast: true,
          isDark: isDark,
          onTap: () => _showTimelineDetail(
            context,
            en ? 'Verified' : 'सत्यापित',
            en
                ? 'Officer verified the work. Incident closed.'
                : 'अधिकारी ने काम का सत्यापन किया। इंसिडेंट बंद।',
            isDark,
          ),
        ),
      ],
    );
  }

  void _showTimelineDetail(
    BuildContext context,
    String title,
    String desc,
    bool isDark, {
    bool showProof = false,
    String? beforePath,
    String? afterPath,
  }) {
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
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: GovColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              desc,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (showProof) ...[
              const SizedBox(height: 24),
              const Text(
                'Closure Proof',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (beforePath?.trim().isNotEmpty == true &&
                  afterPath?.trim().isNotEmpty == true)
                Row(
                  children: [
                    Expanded(
                      child: _buildCitizenEvidencePhoto('BEFORE', beforePath!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCitizenEvidencePhoto('AFTER', afterPath!),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'After-cleanup photo pending from field crew.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ),
            ],
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
              child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt, bool en) {
    return '${dt.day} ${en ? "Aug" : "अगस्त"}, ${_formatTime(dt)}';
  }

  Widget _buildCitizenEvidencePhoto(String label, String path) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 110,
            width: double.infinity,
            child: _citizenEvidenceImage(path),
          ),
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: Colors.black54,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _citizenEvidenceImage(String? path) {
    final resolved = path?.trim() ?? '';
    if (resolved.isEmpty) return _missingCitizenEvidence();
    final fallback = _missingCitizenEvidence();
    if (resolved.startsWith('/')) {
      return Image.file(
        File(resolved),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.asset(
      resolved,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _missingCitizenEvidence() {
    return Container(
      color: Colors.blueGrey.withOpacity(0.12),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.blueGrey,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IncidentLifecycle status;
  final bool en;
  const _StatusChip({required this.status, required this.en});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        en ? status.labelEn : status.labelHi,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: status.color,
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String time;
  final bool isActive;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final VoidCallback? onTap;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.isActive,
    required this.isDark,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? GovColors.gold : GovColors.navy;
    final inactiveColor = isDark
        ? Colors.white12
        : Colors.grey.withOpacity(0.3);

    return InkWell(
      onTap: isActive ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : inactiveColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: isActive ? activeColor : inactiveColor,
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? (isDark ? Colors.white : GovColors.navy)
                        : Colors.grey,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
