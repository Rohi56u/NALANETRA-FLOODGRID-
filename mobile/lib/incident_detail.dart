import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';
import 'evidence_image.dart';
import 'models.dart';

class IncidentDetail extends StatefulWidget {
  final String id;
  const IncidentDetail({super.key, required this.id});
  @override
  State<IncidentDetail> createState() => _DetailState();
}

class _DetailState extends State<IncidentDetail> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Position> _gps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Enable location services');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if ([
      LocationPermission.denied,
      LocationPermission.deniedForever,
    ].contains(permission)) {
      throw Exception('Location permission unavailable');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (p.accuracy > 50) {
      throw Exception('Wait for GPS accuracy of 50 metres or better');
    }
    return p;
  }

  Future<void> _review(AppStore store, Map<String, dynamic> incident) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReviewDialog(severity: incident['severity'] as String),
    );
    if (data != null) {
      await store.act('/api/v1/incidents/${widget.id}/review', data);
    }
  }

  Future<void> _dispatch(AppStore store) async {
    if (store.crew.isEmpty) {
      throw Exception('No issued crew accounts in this snapshot');
    }
    String crew = store.crew.first['id'] as String;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Dispatch issued crew'),
          content: DropdownButtonFormField<String>(
            initialValue: crew,
            items: store.crew
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text('${c['name']} · ${c['id']}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setLocal(() => crew = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, crew),
              child: const Text('Dispatch'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await store.act('/api/v1/incidents/${widget.id}/dispatch', {
        'crew_id': chosen,
      });
    }
  }

  Future<String?> _note(String title) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            maxLength: 1200,
            decoration: const InputDecoration(
              labelText: 'Decision / work note',
            ),
            validator: (v) => (v?.trim().length ?? 0) >= 5
                ? null
                : 'Describe the decision (at least 5 characters)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Record decision'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _closure(AppStore store, bool approved) async {
    final note = await _note(
      approved
          ? 'Verify closure after comparing field proof'
          : 'Request further field work',
    );
    if (note != null) {
      await store.act('/api/v1/incidents/${widget.id}/closure', {
        'approved': approved,
        'note': note,
      });
    }
  }

  Future<void> _status(AppStore store, String status) async {
    final p = await _gps();
    await store.act('/api/v1/jobs/${widget.id}/status', {
      'status': status,
      'lat': p.latitude,
      'lon': p.longitude,
      'accuracy_m': p.accuracy,
      'capture_source': 'gps',
    });
  }

  Future<void> _proof(AppStore store, String kind) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (photo == null) return;
    final at = DateTime.now().toUtc();
    final bytes = await photo.readAsBytes();
    final p = await _gps();
    if (!mounted) return;
    final note = await _note(
      kind == 'before'
          ? 'Record before-work capture'
          : 'Describe cleanup with after-work capture',
    );
    if (note == null) return;
    await store.api.upload('/api/v1/jobs/${widget.id}/evidence', bytes, {
      'kind': kind,
      'lat': '${p.latitude}',
      'lon': '${p.longitude}',
      'accuracy_m': '${p.accuracy}',
      'capture_source': 'gps',
      'captured_at': at.toIso8601String(),
      'note': note,
    });
    await store.refresh();
  }

  Future<void> _audit(AppStore store) async {
    final events = records(
      await store.api.get('/api/v1/incidents/${widget.id}/audit'),
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Text(
                'Actor / action audit history',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              for (final e in events)
                ListTile(
                  title: Text(e['action'] as String),
                  subtitle: Text('${e['actor_role']} · ${e['at']}'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _merge(AppStore store, Map<String, dynamic> incident) async {
    final ids = records(store.snapshot['reports'])
        .where((r) => r['incident_id'] == widget.id)
        .expand((r) => records(r['grouping_candidates']))
        .map((r) => r['incident_id'])
        .toSet();
    final candidates = store.incidents
        .where(
          (i) =>
              ids.contains(i['id']) &&
              ['SUBMITTED', 'VERIFIED'].contains(i['status']),
        )
        .toList();
    if (candidates.isEmpty) {
      throw Exception('No open grouping candidates in this snapshot');
    }
    String target = candidates.first['id'] as String;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Review grouping candidate'),
          content: DropdownButtonFormField<String>(
            initialValue: target,
            items: candidates
                .map(
                  (i) => DropdownMenuItem(
                    value: i['id'] as String,
                    child: Text(i['location'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) => setLocal(() => target = v!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, target),
              child: const Text('Same obstruction'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final note = await _note(
      'Explain why these reports describe one obstruction',
    );
    if (note != null) {
      await store.act('/api/v1/incidents/${widget.id}/merge', {
        'target_incident_id': selected,
        'note': note,
      });
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _route(AppStore store, Map<String, dynamic> incident) async {
    final p = await _gps();
    final result = await store.api.post('/api/v1/routes', {
      'origin_lat': p.latitude,
      'origin_lon': p.longitude,
      'dest_lat': incident['lat'],
      'dest_lon': incident['lon'],
    });
    if (!mounted) return;
    if (result['status'] != 'RECOMMENDED') {
      throw Exception(
        '${result['status']}: ${result['reason'] ?? "Routing provider is not configured"}',
      );
    }
    final route = (result['route'] as Map).cast<String, dynamic>();
    final points = (route['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Risk-aware route recommendation')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${((route['distance'] as num) / 1000).toStringAsFixed(1)} km · ${((route['duration'] as num) / 60).round()} min\nKnown-closure screening only; no flood-free guarantee.',
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'in.nalanetra.nalanetra_floodgrid',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: GovColors.navy,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final incident = store.incidents
        .where((i) => i['id'] == widget.id)
        .firstOrNull;
    if (incident == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incident')),
        body: const Center(
          child: Text('This incident is not in your current account snapshot.'),
        ),
      );
    }
    final proofs = store.evidence
        .where((e) => e['incident_id'] == widget.id)
        .toList();
    final job = store.jobs
        .where((j) => j['incident_id'] == widget.id)
        .firstOrNull;
    final status = incident['status'] as String;
    Widget button(String label, IconData icon, Future<void> Function() fn) =>
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(fn),
          icon: Icon(icon),
          label: Text(label),
        );
    return Scaffold(
      appBar: AppBar(title: Text(incident['location'] as String)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.replaceAll('_', ' '),
                        style: TextStyle(
                          color: bandColor(incident['band'] as String),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'P ${incident['priority_score']}/100',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: GovColors.navy,
                        ),
                      ),
                      Text(
                        '${incident['band']} · ${incident['report_count']} report(s) · ${incident['action_sla_minutes']} min response threshold',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        incident['policy_note'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final key in ['S', 'R', 'W', 'D', 'E', 'A'])
                            Chip(
                              label: Text(
                                '$key ${((incident['factor_breakdown'][key]) as num).toStringAsFixed(2)}',
                              ),
                            ),
                        ],
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          store.t('Factor provenance', 'स्कोर डेटा स्रोत'),
                        ),
                        children: [
                          for (final entry
                              in (incident['factor_sources'] as Map).entries)
                            ListTile(
                              dense: true,
                              title: Text('${entry.key}: ${entry.value}'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                store.t('Incident and field evidence', 'घटना और फील्ड प्रमाण'),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final proof in proofs)
                      SizedBox(
                        width: c.maxWidth > 700
                            ? (c.maxWidth - 24) / 3
                            : c.maxWidth,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EvidenceImage(path: proof['url'] as String),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (proof['kind'] as String).toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: GovColors.gold,
                                      ),
                                    ),
                                    Text(
                                      '${proof['capture_source']} · ${proof['captured_at']}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      'SHA-256 ${proof['sha256']}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: GovColors.critical),
                  ),
                ),
              if (store.role == AppRole.officer)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (['SUBMITTED', 'VERIFIED'].contains(status))
                      button(
                        'Review photo and depth',
                        Icons.fact_check_outlined,
                        () => _review(store, incident),
                      ),
                    if (['SUBMITTED', 'VERIFIED'].contains(status))
                      button(
                        'Review grouping',
                        Icons.merge_outlined,
                        () => _merge(store, incident),
                      ),
                    if (status == 'VERIFIED')
                      button(
                        'Dispatch issued crew',
                        Icons.engineering_outlined,
                        () => _dispatch(store),
                      ),
                    if (status == 'AWAITING_REVIEW') ...[
                      button(
                        'Verify and close',
                        Icons.task_alt,
                        () => _closure(store, true),
                      ),
                      button(
                        'Request rework',
                        Icons.history,
                        () => _closure(store, false),
                      ),
                    ],
                    button(
                      'Inspect audit history',
                      Icons.history_edu_outlined,
                      () => _audit(store),
                    ),
                  ],
                ),
              if (store.role == AppRole.crew && job != null)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (status == 'DISPATCHED')
                      button(
                        'Confirm GPS arrival',
                        Icons.my_location,
                        () => _status(store, 'ON_SITE'),
                      ),
                    if (status == 'ON_SITE')
                      button(
                        'Start field work',
                        Icons.construction,
                        () => _status(store, 'WORK_IN_PROGRESS'),
                      ),
                    if (['ON_SITE', 'WORK_IN_PROGRESS'].contains(status))
                      button(
                        job['before_id'] == null
                            ? 'Capture before-work proof'
                            : 'Capture after-work proof',
                        Icons.camera_alt_outlined,
                        () => _proof(
                          store,
                          job['before_id'] == null ? 'before' : 'after',
                        ),
                      ),
                    if (!['CLOSED', 'AWAITING_REVIEW'].contains(status))
                      button(
                        'Request risk-aware route',
                        Icons.route_outlined,
                        () => _route(store, incident),
                      ),
                  ],
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 18),
              Text(
                store.t(
                  'Photo proof and device metadata require officer judgement. SHA-256 checks stored bytes; it does not prove scene truth.',
                  'फोटो और डिवाइस डेटा की अधिकारी समीक्षा जरूरी है। SHA-256 संग्रहीत बाइट जांचता है; दृश्य की सच्चाई साबित नहीं करता।',
                ),
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final String severity;
  const _ReviewDialog({required this.severity});
  @override
  State<_ReviewDialog> createState() => _ReviewState();
}

class _ReviewState extends State<_ReviewDialog> {
  final _form = GlobalKey<FormState>();
  final _rain = TextEditingController(),
      _ward = TextEditingController(),
      _block = TextEditingController(),
      _note = TextEditingController();
  late String _severity;
  bool _emergency = false, _checked = false;
  @override
  void initState() {
    super.initState();
    _severity = widget.severity;
  }

  @override
  void dispose() {
    for (final c in [_rain, _ward, _block, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save(bool approved) {
    if (!_form.currentState!.validate()) return;
    if (approved && !_checked) return;
    Navigator.pop(context, {
      'approved': approved,
      'severity': _severity,
      'note': _note.text.trim(),
      'emergency_route': _emergency,
      if (_rain.text.isNotEmpty) 'rain_mm_hr': double.parse(_rain.text),
      if (_ward.text.isNotEmpty) 'ward_criticality': double.parse(_ward.text),
      if (_block.text.isNotEmpty) 'blockage': double.parse(_block.text),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Officer evidence review'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Inspect the actual photo. Enter available context and its source in the note. Unavailable inputs remain labelled.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Reviewed depth'),
                items: ['sidewalk', 'ankle', 'knee', 'waist', 'submerged']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _severity = v!),
              ),
              const SizedBox(height: 12),
              for (final entry in [
                (_rain, 'Rainfall (mm/h)', 500.0),
                (_ward, 'Ward importance (0–1)', 1.0),
                (_block, 'Drain blockage (0–1)', 1.0),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.$1,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = double.tryParse(v);
                      return n != null && n.isFinite && n >= 0 && n <= entry.$3
                          ? null
                          : 'Out of range';
                    },
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Emergency-route importance'),
                value: _emergency,
                onChanged: (v) => setState(() => _emergency = v!),
              ),
              TextFormField(
                controller: _note,
                maxLines: 3,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Evidence decision / source note',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 5 ? null : 'Add a review note',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I compared the photo and depth claim'),
                value: _checked,
                onChanged: (v) => setState(() => _checked = v!),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: () => _save(false), child: const Text('Reject')),
      FilledButton(
        onPressed: _checked ? () => _save(true) : null,
        child: const Text('Approve'),
      ),
    ],
  );
}
