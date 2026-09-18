import 'package:flutter/material.dart';

import 'dart:io';

import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'store.dart';
import 'widgets_v4.dart';
import 'config.dart';
import 'citizen_home.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  IconData _icon(NotifKind kind) {
    switch (kind) {
      case NotifKind.verified:
        return Icons.check_circle;
      case NotifKind.merge:
        return Icons.merge_type;
      case NotifKind.weather:
        return Icons.warning_amber_rounded;
      case NotifKind.crewAssigned:
        return Icons.local_shipping;
      case NotifKind.escalation:
        return Icons.trending_up;
      case NotifKind.rejected:
        return Icons.cancel;
      case NotifKind.info:
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  Color _iconColor(NotifKind kind) {
    switch (kind) {
      case NotifKind.verified:
        return Colors.green;
      case NotifKind.merge:
        return Colors.blue;
      case NotifKind.weather:
        return Colors.orange;
      case NotifKind.crewAssigned:
        return Colors.blue;
      case NotifKind.escalation:
        return Colors.purple;
      case NotifKind.rejected:
        return Colors.red;
      case NotifKind.info:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    final en = store.lang == AppLang.en;
    final activePortal = store.portal ?? Portal.citizen;
    final isMunicipal =
        activePortal == Portal.officer || activePortal == Portal.admin;
    final notifs = store.notificationsFor(activePortal);

    return Column(
      children: [
        GovHeader(
          title: en ? 'Notifications' : 'सूचनाएं',
          subtitle: en
              ? '${notifs.length} alerts active'
              : '${notifs.length} अलर्ट सक्रिय',
          trailing: GestureDetector(
            onTap: () => store.setLang(en ? AppLang.hi : AppLang.en),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                en ? 'HIN' : 'ENG',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: notifs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_off_outlined,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        en ? 'No alerts yet' : 'अभी कोई अलर्ट नहीं',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == notifs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.coffee_outlined,
                              color: Colors.brown,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              en
                                  ? 'Aur notifications nahi — shanti se piye chai ☕'
                                  : 'और सूचनाएं नहीं — शांति से पिएं चाय ☕',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final n = notifs[index] as Notif;
                    final isHighFi =
                        n.kind == NotifKind.verified ||
                        n.kind == NotifKind.emergency ||
                        n.kind == NotifKind.weather;
                    final pairedJob = n.incidentId == null
                        ? null
                        : store.jobFor(n.incidentId!);
                    final hasProofPair =
                        !isMunicipal &&
                        n.kind == NotifKind.verified &&
                        pairedJob != null &&
                        pairedJob.hasAfterProof &&
                        n.beforeImagePath == pairedJob.beforePhotoPath &&
                        n.afterImagePath == pairedJob.afterPhotoPath;

                    if (isHighFi) {
                      return _buildHighFidelityAlert(
                        context,
                        store,
                        en ? n.titleEn : n.titleHi,
                        n.kind == NotifKind.verified
                            ? (hasProofPair
                                  ? (en
                                        ? 'Report closed — proof attached'
                                        : 'रिपोर्ट बंद — प्रमाण संलग्न')
                                  : (en
                                        ? 'Closure recorded — proof pending'
                                        : 'समापन दर्ज — प्रमाण लंबित'))
                            : (n.kind == NotifKind.emergency
                                  ? (en
                                        ? 'Immediate action required'
                                        : 'तत्काल कार्रवाई आवश्यक')
                                  : (en ? 'Weather advisory' : 'मौसम परामर्श')),
                        _fmt(n.at),
                        n.kind,
                        hasProofPair,
                        n,
                        isMunicipal,
                      );
                    }
                    return InkWell(
                      onTap: () => _showNotificationDetail(
                        context,
                        en ? n.titleEn : n.titleHi,
                        '',
                        _fmt(n.at),
                        n.kind,
                        false,
                        store,
                        store.themeMode == AppThemeMode.dark,
                        notification: n,
                        municipalFeed: isMunicipal,
                      ),
                      child: _buildAlertCard(
                        context,
                        store,
                        en ? n.titleEn : n.titleHi,
                        _fmt(n.at),
                        n.kind,
                        n,
                        isMunicipal,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHighFidelityAlert(
    BuildContext context,
    AppStore store,
    String title,
    String subtitle,
    String time,
    NotifKind kind,
    bool hasPhotos,
    Notif notification,
    bool isMunicipal,
  ) {
    final isDark = store.themeMode == AppThemeMode.dark;
    final incidentId = notification.incidentId;
    final job = incidentId == null ? null : store.jobFor(incidentId);
    final beforePath = job?.beforePhotoPath.trim().isNotEmpty == true
        ? job!.beforePhotoPath
        : (notification.beforeImagePath ?? notification.imagePath ?? '');
    final afterPath = job?.hasAfterProof == true
        ? job!.afterPhotoPath
        : (notification.afterImagePath ?? '');
    return InkWell(
      onTap: () => _showNotificationDetail(
        context,
        title,
        subtitle,
        time,
        kind,
        hasPhotos,
        store,
        isDark,
        notification: notification,
        municipalFeed: isMunicipal,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2B4E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_icon(kind), color: _iconColor(kind), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeText.colorOf(context),
                ),
              ),
            ),
            if (isMunicipal) _buildMunicipalMetadata(context, notification),
            if (hasPhotos)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: _buildAlertPhoto('BEFORE', beforePath)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildAlertPhoto('AFTER', afterPath)),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 155,
                    width: double.infinity,
                    child: _evidenceImage(
                      notification.imageFor(NotifAudience.municipal),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isMunicipal)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildMunicipalAssignButton(
                  context,
                  store,
                  notification,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertPhoto(String label, String path) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 155,
            width: double.infinity,
            child: _evidenceImage(path),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    AppStore store,
    String title,
    String time,
    NotifKind kind,
    Notif notification,
    bool isMunicipal,
  ) {
    final isDark = store.themeMode == AppThemeMode.dark;
    return InkWell(
      onTap: () => _showNotificationDetail(
        context,
        title,
        "",
        time,
        kind,
        false,
        store,
        isDark,
        notification: notification,
        municipalFeed: isMunicipal,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2B4E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon(kind), color: _iconColor(kind), size: 24),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 80,
                height: 64,
                child: _evidenceImage(
                  notification.imageFor(
                    isMunicipal
                        ? NotifAudience.municipal
                        : NotifAudience.citizen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ThemeText.colorOf(context),
                    ),
                  ),
                  if (isMunicipal)
                    _buildMunicipalMetadata(context, notification),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (isMunicipal) ...[
                    const SizedBox(height: 8),
                    _buildMunicipalAssignButton(context, store, notification),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMunicipalMetadata(BuildContext context, Notif notification) {
    final location = notification.locationName?.trim();
    final band = notification.severityBand;
    final score = notification.severityScore;
    if ((location == null || location.isEmpty) &&
        band == null &&
        score == null) {
      return const SizedBox.shrink();
    }
    final severityLabel = band == null
        ? 'Severity pending'
        : severityOf(band).label;
    final severityPercent = score == null
        ? '—'
        : '${(score.clamp(0.0, 1.0) * 100).round()}%';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = band == null ? Colors.blueGrey : severityOf(band).color;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _municipalMetaChip(
            context,
            Icons.place_outlined,
            location?.isNotEmpty == true ? location! : 'Gurugram',
            isDark,
          ),
          _municipalMetaChip(
            context,
            Icons.speed_outlined,
            '$severityLabel • AI $severityPercent',
            isDark,
            accent: chipColor,
          ),
          if (notification.reporterName?.trim().isNotEmpty == true)
            _municipalMetaChip(
              context,
              Icons.person_outline,
              notification.reporterName!.trim(),
              isDark,
            ),
          if (notification.reportCount != null)
            _municipalMetaChip(
              context,
              Icons.groups_outlined,
              '${notification.reportCount} reports merged',
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _municipalMetaChip(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark, {
    Color? accent,
  }) {
    final color = accent ?? (isDark ? Colors.white70 : GovColors.navy);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : GovColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _crewAvatar(CrewMember member, {double radius = 24}) {
    final path = member.avatarPath;
    if (path != null && path.isNotEmpty) {
      return ClipOval(
        child: Image.asset(
          path,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _crewInitialsAvatar(member, radius),
        ),
      );
    }
    return _crewInitialsAvatar(member, radius);
  }

  Widget _crewInitialsAvatar(CrewMember member, double radius) {
    final initials = member.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: GovColors.navy,
      child: Text(
        initials.isEmpty ? 'MCG' : initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.38,
        ),
      ),
    );
  }

  Widget _buildMunicipalAssignButton(
    BuildContext context,
    AppStore store,
    Notif notification,
  ) {
    final targetId =
        notification.assignmentIncidentId ?? notification.incidentId;
    final job = targetId == null ? null : store.jobFor(targetId);
    final alreadyAssigned = job != null && !job.isDone;
    final enabled = targetId != null && targetId.isNotEmpty && !alreadyAssigned;
    final en = store.lang == AppLang.en;
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: enabled
            ? () => _showCrewAssignmentPicker(context, store, notification)
            : null,
        icon: Icon(
          alreadyAssigned ? Icons.check_circle_outline : Icons.groups_outlined,
          size: 16,
        ),
        label: Text(
          alreadyAssigned
              ? (en ? 'CREW ASSIGNED' : 'क्रू असाइन है')
              : (en ? 'ASSIGN CREW' : 'क्रू असाइन करें'),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: alreadyAssigned ? GovColors.ok : GovColors.navy,
          side: BorderSide(
            color: alreadyAssigned ? GovColors.ok : GovColors.navy,
          ),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  void _showCrewAssignmentPicker(
    BuildContext context,
    AppStore store,
    Notif notification,
  ) {
    final targetId =
        notification.assignmentIncidentId ?? notification.incidentId;
    final en = store.lang == AppLang.en;
    final available = AppStore.crewRoster
        .where((member) {
          final active = store.jobs.any(
            (job) => job.crewName == member.id && !job.isDone,
          );
          return !member.offDuty && !active;
        })
        .toList(growable: false);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(en ? 'Assign field crew' : 'फील्ड क्रू असाइन करें'),
        content: SizedBox(
          width: double.maxFinite,
          child: targetId == null
              ? Text(
                  en
                      ? 'This notification has no active incident target.'
                      : 'इस नोटिफिकेशन के लिए सक्रिय घटना उपलब्ध नहीं है।',
                )
              : available.isEmpty
              ? Text(
                  en
                      ? 'No crew is currently available.'
                      : 'अभी कोई क्रू उपलब्ध नहीं है।',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final member = available[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _crewAvatar(member, radius: 21),
                      title: Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${member.id} • ${member.role} • ${member.ward}',
                        style: const TextStyle(fontSize: 9),
                      ),
                      trailing: const Icon(
                        Icons.send,
                        color: GovColors.navy,
                        size: 18,
                      ),
                      onTap: () {
                        final assigned = store.assignCrewForNotification(
                          targetId,
                          member.id,
                        );
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              assigned
                                  ? (en
                                        ? '${member.name} assigned to ${notification.locationName ?? 'incident'}'
                                        : '${member.name} को ${notification.locationName ?? 'घटना'} पर भेजा गया')
                                  : (en
                                        ? 'This incident is already assigned or unavailable.'
                                        : 'यह घटना पहले से असाइन है या उपलब्ध नहीं है।'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(en ? 'CLOSE' : 'बंद करें'),
          ),
        ],
      ),
    );
  }

  Widget _evidenceImage(String? path) {
    final resolved = path?.trim() ?? '';
    if (resolved.isEmpty) return _missingEvidence();
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _missingEvidence(),
      );
    }
    if (resolved.startsWith('/')) {
      return Image.file(
        File(resolved),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _missingEvidence(),
      );
    }
    return Image.asset(
      resolved,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _missingEvidence(),
    );
  }

  Widget _missingEvidence() {
    return Container(
      color: Colors.blueGrey.withOpacity(0.12),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.blueGrey),
          SizedBox(height: 4),
          Text(
            'No field photo attached',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inHours > 24) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  void _showNotificationDetail(
    BuildContext context,
    String title,
    String subtitle,
    String time,
    NotifKind kind,
    bool hasPhotos,
    AppStore store,
    bool isDark, {
    Notif? notification,
    bool municipalFeed = false,
  }) {
    final incidentId = notification?.incidentId;
    final job = incidentId == null ? null : store.jobFor(incidentId);
    final beforePath = job?.beforePhotoPath.trim().isNotEmpty == true
        ? job!.beforePhotoPath
        : (notification?.beforeImagePath ?? notification?.imagePath ?? '');
    final afterPath = job?.hasAfterProof == true
        ? job!.afterPhotoPath
        : (notification?.afterImagePath ?? '');
    final attachedPath = municipalFeed
        ? notification?.imageFor(NotifAudience.municipal)
        : notification?.imagePath ?? notification?.beforeImagePath;
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
                Icon(_icon(kind), color: _iconColor(kind)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: GovColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (municipalFeed && notification != null)
              _buildMunicipalMetadata(context, notification),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            Text(
              'Received: $time',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (hasPhotos) ...[
              const Text(
                'Verification Proof',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildAlertPhoto('BEFORE', beforePath)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAlertPhoto('AFTER', afterPath)),
                ],
              ),
            ] else ...[
              const Text(
                'Attached field evidence',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: _evidenceImage(attachedPath),
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
              child: const Text(
                'DISMISS',
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
