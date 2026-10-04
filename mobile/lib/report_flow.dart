import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';
import 'models.dart';

class ReportFlowScreen extends StatefulWidget {
  const ReportFlowScreen({super.key});
  @override
  State<ReportFlowScreen> createState() => _ReportState();
}

class _ReportState extends State<ReportFlowScreen> {
  final _form = GlobalKey<FormState>();
  final _location = TextEditingController(),
      _lat = TextEditingController(),
      _lon = TextEditingController(),
      _note = TextEditingController();
  Uint8List? _photo;
  DateTime? _captured;
  double? _accuracy;
  String _source = 'selected-map', _depth = 'ankle';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_location, _lat, _lon, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _captured = DateTime.now().toUtc();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _gps() async {
    try {
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
        throw Exception('Location permission is unavailable');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat.text = '${p.latitude}';
        _lon.text = '${p.longitude}';
        _accuracy = p.accuracy;
        _source = 'gps';
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _photo == null) {
      setState(
        () => _error = 'Capture a scene photo and complete the location.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = context.read<AppStore>();
      final id =
          '${DateTime.now().microsecondsSinceEpoch}-${List.generate(12, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, "0")).join()}';
      final received = await store.submit(
        QueuedReport(
          clientId: id,
          ownerId: store.ownerId!,
          photo: _photo!,
          fields: {
            'location': _location.text.trim(),
            'lat': _lat.text.trim(),
            'lon': _lon.text.trim(),
            'depth_tag': _depth,
            'notes': _note.text.trim(),
            'captured_at': _captured!.toIso8601String(),
            'capture_source': _source,
            if (_accuracy != null) 'accuracy_m': '$_accuracy',
          },
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            received
                ? store.t(
                    'Report received. Officer review pending.',
                    'रिपोर्ट प्राप्त हुई। अधिकारी समीक्षा बाकी है।',
                  )
                : store.t(
                    'Securely queued; receipt will appear after sync.',
                    'सुरक्षित कतार में है; सिंक के बाद प्राप्ति दिखेगी।',
                  ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(store.t('Report waterlogging', 'जलभराव रिपोर्ट करें')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  store.t(
                    'Your observation helps response teams',
                    'आपका अवलोकन प्रतिक्रिया टीम की मदद करता है',
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.t(
                    'Photo screening assists review. It does not automatically verify a report.',
                    'फोटो स्क्रीनिंग समीक्षा में मदद करती है। रिपोर्ट अपने आप सत्यापित नहीं होती।',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _location,
                  decoration: InputDecoration(
                    labelText: store.t('Location / landmark', 'स्थान / पहचान'),
                  ),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Required',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _gps,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    store.t(
                      'Use current GPS location',
                      'वर्तमान GPS स्थान लें',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: store.t('Latitude', 'अक्षांश'),
                        ),
                        validator: (v) => _coordinate(v, 90),
                        onChanged: (_) {
                          _source = 'selected-map';
                          _accuracy = null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lon,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: store.t('Longitude', 'देशांतर'),
                        ),
                        validator: (v) => _coordinate(v, 180),
                        onChanged: (_) {
                          _source = 'selected-map';
                          _accuracy = null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _depth,
                  decoration: InputDecoration(
                    labelText: store.t(
                      'Observed water level',
                      'पानी का देखा गया स्तर',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'sidewalk',
                      child: Text(store.t('Sidewalk', 'फुटपाथ')),
                    ),
                    DropdownMenuItem(
                      value: 'ankle',
                      child: Text(store.t('Ankle', 'टखना')),
                    ),
                    DropdownMenuItem(
                      value: 'knee',
                      child: Text(store.t('Knee', 'घुटना')),
                    ),
                    DropdownMenuItem(
                      value: 'waist',
                      child: Text(store.t('Waist', 'कमर')),
                    ),
                    DropdownMenuItem(
                      value: 'submerged',
                      child: Text(store.t('Submerged', 'डूबा हुआ')),
                    ),
                  ],
                  onChanged: (v) => setState(() => _depth = v!),
                ),
                const SizedBox(height: 16),
                if (_photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _photo!,
                      height: 210,
                      fit: BoxFit.cover,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    store.t('Capture scene photo', 'दृश्य की फोटो लें'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 1200,
                  decoration: InputDecoration(
                    labelText: store.t('Scene note', 'दृश्य का विवरण'),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: GovColors.critical),
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      _busy
                          ? store.t('Sending…', 'भेज रहे हैं…')
                          : store.t(
                              'Submit for officer review',
                              'अधिकारी समीक्षा के लिए भेजें',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _coordinate(String? value, double max) {
    final n = double.tryParse(value ?? '');
    return n != null && n.isFinite && n.abs() <= max
        ? null
        : 'Invalid coordinate';
  }
}
