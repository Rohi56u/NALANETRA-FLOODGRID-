import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'backend_api.dart';
import 'config.dart';
import 'models.dart';

abstract class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class DeviceStore implements LocalStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class AppStore extends ChangeNotifier {
  final BackendApi api;
  final LocalStore storage;
  Map<String, dynamic>? session;
  Map<String, dynamic> snapshot = {};
  List<QueuedReport> pending = [];
  bool ready = false, busy = false, hindi = false;
  String? error;
  DateTime? lastSync;
  Timer? _timer;
  bool _refreshing = false, _syncing = false, _disposed = false;
  AppStore({BackendApi? api, LocalStore? storage, bool liveUpdates = true})
    : api = api ?? BackendApi(),
      storage = storage ?? DeviceStore() {
    if (liveUpdates) {
      unawaited(_restore());
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(refresh());
      });
    } else {
      ready = true;
    }
  }
  Map<String, dynamic>? get user =>
      (session?['user'] as Map?)?.cast<String, dynamic>();
  String? get ownerId => user?['id'].toString();
  AppRole? get role => switch (user?['role']) {
    'citizen' => AppRole.citizen,
    'officer' => AppRole.officer,
    'crew' => AppRole.crew,
    _ => null,
  };
  List<Map<String, dynamic>> get incidents => records(snapshot['incidents']);
  List<Map<String, dynamic>> get evidence => records(snapshot['evidence']);
  List<Map<String, dynamic>> get jobs => records(snapshot['jobs']);
  List<Map<String, dynamic>> get crew => records(snapshot['crew']);
  List<Map<String, dynamic>> get notifications =>
      records(snapshot['notifications']);
  String t(String en, String hi) => hindi ? hi : en;
  void language() {
    hindi = !hindi;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String get _queueKey => 'nalanetra.offline.${ownerId ?? "none"}';

  Future<void> _restore() async {
    try {
      final value = await storage.read('nalanetra.session');
      if (value != null) {
        session = (jsonDecode(value) as Map).cast<String, dynamic>();
        await _rotate();
        await _loadQueue();
        await refresh();
      }
    } catch (_) {
      session = null;
      api.accessToken = null;
      snapshot = {};
      pending = [];
    }
    ready = true;
    _notify();
  }

  Future<void> _rotate() async {
    final current = session;
    if (current == null) return;
    session = await api.post('/api/v1/auth/refresh', {
      'role': current['user']['role'],
      'refreshToken': current['refreshToken'],
    });
    api.accessToken = session!['accessToken'] as String;
    await storage.write('nalanetra.session', jsonEncode(session));
  }

  Future<void> signIn(Map<String, dynamic> fields) async {
    snapshot = {};
    pending = [];
    session = null;
    error = null;
    api.accessToken = null;
    session = await api.post('/api/v1/auth/login', fields);
    api.accessToken = session!['accessToken'] as String;
    await storage.write('nalanetra.session', jsonEncode(session));
    await _loadQueue();
    await refresh();
    _notify();
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> fields) =>
      api.post('/api/v1/auth/register', {...fields, 'role': 'citizen'});
  Future<void> verify(int challenge, String code) async {
    session = await api.post('/api/v1/auth/verify', {
      'role': 'citizen',
      'challengeId': challenge,
      'emailCode': code,
    });
    api.accessToken = session!['accessToken'] as String;
    await storage.write('nalanetra.session', jsonEncode(session));
    snapshot = {};
    pending = [];
    await _loadQueue();
    await refresh();
    _notify();
  }

  Future<void> logout() async {
    try {
      if (session != null) await api.post('/api/v1/auth-logout', {});
    } catch (_) {}
    await storage.delete('nalanetra.session');
    session = null;
    api.accessToken = null;
    snapshot = {};
    pending = [];
    lastSync = null;
    error = null;
    _notify();
  }

  void applySnapshot(Map<String, dynamic> state) {
    if (user != null && state['role'] != user!['role']) {
      throw const ApiException('Session role and snapshot do not match.');
    }
    snapshot = state;
    lastSync = DateTime.now();
    _notify();
  }

  Future<void> refresh() async {
    if (session == null || _refreshing || _disposed) return;
    _refreshing = true;
    try {
      Map<String, dynamic> state;
      try {
        state = (await api.get('/api/v1/snapshot') as Map)
            .cast<String, dynamic>();
      } on ApiException catch (e) {
        if (e.statusCode != 401) rethrow;
        await _rotate();
        state = (await api.get('/api/v1/snapshot') as Map)
            .cast<String, dynamic>();
      }
      applySnapshot(state);
      error = null;
      await syncPending();
    } catch (e) {
      error = 'Sync unavailable: $e';
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> _loadQueue() async {
    pending = [];
    if (role != AppRole.citizen) return;
    final value = await storage.read(_queueKey);
    if (value != null) {
      pending = (jsonDecode(value) as List)
          .map((e) => QueuedReport.fromJson((e as Map).cast<String, dynamic>()))
          .where((r) => r.ownerId == ownerId)
          .toList();
    }
  }

  Future<void> _saveQueue() => storage.write(
    _queueKey,
    jsonEncode(pending.map((e) => e.toJson()).toList()),
  );
  Future<bool> submit(QueuedReport report) async {
    if (role != AppRole.citizen || report.ownerId != ownerId) {
      throw const ApiException('Sign in to the report owner account.');
    }
    // A bounded encrypted queue avoids silently exhausting browser storage.
    if (pending.length >= 3 ||
        pending.fold<int>(0, (n, r) => n + r.photo.length) +
                report.photo.length >
            2 * 1024 * 1024) {
      throw const ApiException(
        'Offline queue limit reached (3 photos / 2 MiB). Sync existing reports or capture a smaller image.',
      );
    }
    pending.add(report);
    try {
      await _saveQueue();
    } catch (_) {
      pending.remove(report);
      throw const ApiException(
        'Could not securely save this report. It is not queued; retry with a smaller image.',
      );
    }
    await syncPending();
    await refresh();
    _notify();
    return !pending.any((r) => r.clientId == report.clientId);
  }

  Future<void> syncPending() async {
    if (_syncing || role != AppRole.citizen || _disposed) return;
    _syncing = true;
    try {
      for (final report in [...pending]) {
        if (report.ownerId != ownerId) continue;
        try {
          final result = await api.upload(
            '/api/v1/incidents/report',
            report.photo,
            {...report.fields, 'client_id': report.clientId},
          );
          if (result['success'] != true ||
              result['incident_id'] == null ||
              result['report_id'] == null) {
            throw const ApiException(
              'Server acknowledgement is incomplete. Report remains queued.',
            );
          }
          pending.removeWhere((r) => r.clientId == report.clientId);
          await _saveQueue();
        } catch (e) {
          error = 'Report stays queued: $e';
          break;
        }
      }
    } finally {
      _syncing = false;
      _notify();
    }
  }

  Future<void> act(String path, Map<String, dynamic> body) async {
    await api.post(path, body);
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    api.client.close();
    super.dispose();
  }
}
