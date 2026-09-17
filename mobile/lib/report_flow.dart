import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'config.dart';
import 'store.dart';
import 'widgets_v4.dart';
import 'ai_triage_service.dart';

class ReportFlowScreen extends StatefulWidget {
  const ReportFlowScreen({super.key});

  @override
  State<ReportFlowScreen> createState() => _ReportFlowScreenState();
}

class _ReportFlowScreenState extends State<ReportFlowScreen> {
  final _picker = ImagePicker();
  int _step = 1; // 1 location, 2 photo, 3 result
  GurugramLocation? _selected;
  File? _photo;
  String _waterLevel = 'Sidewalk';
  bool _analyzing = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _selected = store.selectedLocation;
    _searchController.text = _selected?.name ?? '';
    _searchQuery = _searchController.text;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? GovColors.bgDark : Colors.white,
      appBar: AppBar(
        backgroundColor: GovColors.navy,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.shield, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NalaNetra FloodGrid',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Step $_step of 3',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _step / 3,
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
            color: GovColors.gold,
            minHeight: 6,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(isDark, store),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark, AppStore store) {
    if (_step == 1) return _buildLocationStep(isDark, store);
    if (_step == 2) return _buildPhotoStep(isDark, store);
    return _buildResultStep(isDark, store);
  }

  Widget _buildLocationStep(bool isDark, AppStore store) {
    final filtered = gurugramLocations.where((l) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return l.name.toLowerCase().contains(query) ||
          l.category.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          store.t('Location चुनो', 'Choose Location'),
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : GovColors.navy,
          ),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search sector, road, landmark...',
                    prefixIcon: Icon(Icons.search, color: GovColors.navy),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? GovColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GurugramLocation>(
              value:
                  _selected != null &&
                      gurugramLocations.any((l) => l.name == _selected!.name)
                  ? gurugramLocations.firstWhere(
                      (l) => l.name == _selected!.name,
                    )
                  : null,
              isExpanded: true,
              hint: Text(
                store.t('सेक्टर चुनें', 'Select Sector'),
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              dropdownColor: isDark ? GovColors.bgDark : Colors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: GovColors.navy,
              ),
              items: gurugramLocations.map((loc) {
                return DropdownMenuItem(
                  value: loc,
                  child: Text(
                    "${loc.name} (${loc.category})",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : GovColors.navy,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (loc) {
                if (loc != null) {
                  setState(() {
                    _selected = loc;
                    _searchController.text = loc.name;
                    _searchQuery = loc.name;
                  });
                  store.setLocation(loc);
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          store.t('Search Results', 'खोज के परिणाम'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : GovColors.navyDeep,
          ),
        ),
        const SizedBox(height: 12),

        ...filtered.map((loc) {
          final isSelected = _selected?.name == loc.name;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selected = loc;
                _searchController.text = loc.name;
                _searchQuery = loc.name;
              });
              store.setLocation(loc);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? GovColors.navy.withOpacity(0.05)
                    : (isDark ? GovColors.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? GovColors.navy
                      : (isDark
                            ? Colors.white12
                            : Colors.black.withOpacity(0.05)),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: isSelected ? GovColors.navy : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${loc.lat.toStringAsFixed(4)}, ${loc.lon.toStringAsFixed(4)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: GovColors.navy,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _selected == null ? null : () => setState(() => _step = 2),
          style: ElevatedButton.styleFrom(
            backgroundColor: GovColors.navy,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: Text(
            store.t('Next: Photo लें', 'Next: Take Photo'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoStep(bool isDark, AppStore store) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          store.t('Photo भेजो', 'Send Photo'),
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : GovColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          store.t(
            'AI severity check करेगा',
            'AI will check severity automatically',
          ),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),

        GestureDetector(
          onTap: () async {
            final x = await _picker.pickImage(source: ImageSource.camera);
            if (x != null) setState(() => _photo = File(x.path));
          },
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              color: isDark ? GovColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 2,
                style: BorderStyle.solid,
              ),
              image: _photo != null
                  ? DecorationImage(
                      image: FileImage(_photo!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _photo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_rounded,
                        size: 64,
                        color: GovColors.navy,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        store.t('Click Photo', 'Click Photo'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: GovColors.navy,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),

        const SizedBox(height: 32),
        Text(
          store.t('Water Level kitna hai?', 'What is the Water Level?'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: ['Ankle', 'Sidewalk', 'Knee', 'Waist'].map((level) {
            final isSel = _waterLevel == level;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _waterLevel = level),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? GovColors.navy
                        : (isDark ? GovColors.cardDark : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? GovColors.navy : Colors.black12,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      level,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSel
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _photo == null ? null : _analyze,
          style: ElevatedButton.styleFrom(
            backgroundColor: GovColors.navy,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _analyzing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  store.t('Analyze & Report', 'Analyze & Report'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  void _analyze() async {
    setState(() => _analyzing = true);
    final store = context.read<AppStore>();

    final triageResult = await AiTriageService.analyzeReport(
      locationName: _selected!.name,
      lat: _selected!.lat,
      lon: _selected!.lon,
      waterLevel: _waterLevel,
      currentRainRateMmHr: store.rainRate,
      photo: _photo,
      existingIncidentLocations:
          store.reports.map((r) => r.locationName).toSet().toList(),
    );

    if (!mounted) return;

    if (!triageResult.isLegitimate) {
      setState(() => _analyzing = false);
      final proceedAnyway = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: store.themeMode == AppThemeMode.dark
              ? GovColors.cardDark
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: GovColors.critical,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  store.t(
                    'फ़र्ज़ी/अमान्य रिपोर्ट चेतावनी',
                    'Potential Invalid Report',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: GovColors.critical,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            triageResult.rejectionReason ??
                store.t(
                  'AI ने इस रिपोर्ट में जलभराव की पुष्टि नहीं की है। क्या आप फिर भी जमा करना चाहते हैं?',
                  'AI could not verify waterlogging in this report. Do you still want to proceed?',
                ),
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                store.t('Photo दोबारा लें', 'Retake Photo'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: GovColors.navy,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GovColors.critical,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                store.t('फिर भी भेजें', 'Submit Anyway'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (proceedAnyway != true) return;
      setState(() => _analyzing = true);
    }

    final isHindi = store.lang == AppLang.hi;
    final summary = isHindi ? triageResult.summaryHi : triageResult.summaryEn;

    final report = FloodReport(
      id: 'R-${DateTime.now().millisecondsSinceEpoch % 10000}',
      lat: _selected!.lat,
      lon: _selected!.lon,
      locationName: _selected!.name,
      photoPath: _photo?.path,
      severitySummary: summary,
      band: triageResult.band,
      severityScore: triageResult.score,
      rainfallScore: (store.rainRate / 50.0).clamp(0.1, 1.0),
      criticality: _selected!.name.contains('Hospital') ? 0.9 : 0.5,
      at: DateTime.now(),
      reporterName: store.userName,
      incidentId: assignIncident(
        _selected!.lat,
        _selected!.lon,
        DateTime.now(),
        store.reports,
      ),
      isSynced: false,
    );

    store.addReport(report);
    store.setLocation(_selected!);

    setState(() {
      _analyzing = false;
      _step = 3;
    });
  }

  String assignIncident(
    double lat,
    double lon,
    DateTime at,
    List<FloodReport> existing,
  ) {
    // 150m radius merge logic
    for (final r in existing) {
      final dx = (r.lon - lon) * 111.0 * 0.85;
      final dy = (r.lat - lat) * 110.5;
      final dist = (dx * dx + dy * dy);
      if (dist < 0.0225) {
        // ~150m squared
        return r.incidentId;
      }
    }
    return 'INC-${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Widget _buildResultStep(bool isDark, AppStore store) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          Text(
            store.t('Report Successful!', 'Report Successful!'),
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : GovColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            store.t(
              'Aapki report submit ho gayi hai. MCG team ko notify kar diya gaya hai.',
              'Your report has been submitted. MCG team has been notified.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                store.setStartTab(2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GovColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                store.t('View My Reports', 'मेरे रिपोर्ट देखें'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
