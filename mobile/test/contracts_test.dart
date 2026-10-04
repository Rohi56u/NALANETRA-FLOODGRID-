import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nalanetra_floodgrid/backend_api.dart';
import 'package:nalanetra_floodgrid/app_store.dart';
import 'package:nalanetra_floodgrid/models.dart';

class MemoryStore implements LocalStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Map<String, dynamic> emptyState(String role) => {
  'role': role,
  'incidents': [],
  'reports': [],
  'evidence': [],
  'jobs': [],
  'crew': [],
  'notifications': [],
};
void main() {
  test('app starts without invented incidents or privileged role', () {
    final store = AppStore(liveUpdates: false, storage: MemoryStore());
    expect(store.role, isNull);
    expect(store.incidents, isEmpty);
    expect(store.pending, isEmpty);
    store.dispose();
  });
  test(
    'REST authentication uses actual service contract and explicit role',
    () async {
      final api = BackendApi(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/login');
          expect(request.url.query, isEmpty);
          expect(jsonDecode(request.body)['role'], 'citizen');
          return http.Response(
            '{"accessToken":"fixture","refreshToken":"fixture","user":{"id":1,"role":"citizen","name":"Fixture"}}',
            200,
          );
        }),
      );
      expect(
        (await api.post('/api/v1/auth/login', {
          'role': 'citizen',
        }))['user']['role'],
        'citizen',
      );
      api.client.close();
    },
  );
  test('non-JSON and rejected responses are not treated as success', () {
    final api = BackendApi();
    expect(
      () => api.decode(http.Response('<html>error</html>', 502)),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => api.decode(http.Response('{"detail":"Wrong role"}', 403)),
      throwsA(isA<ApiException>()),
    );
    api.client.close();
  });
  test(
    'multipart includes protected account, original bytes and retry key',
    () async {
      final api = BackendApi(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fixture-access');
          expect(request.body, contains('stable-fixture-key'));
          expect(request.bodyBytes, containsAllInOrder([71, 80, 83]));
          return http.Response(
            '{"success":true,"incident_id":"INC-1","report_id":"RPT-1"}',
            201,
          );
        }),
      );
      api.accessToken = 'fixture-access';
      await api.upload(
        '/api/v1/incidents/report',
        Uint8List.fromList([71, 80, 83]),
        {'client_id': 'stable-fixture-key'},
      );
      api.client.close();
    },
  );
  test(
    'queued capture retains bytes, original timestamp, retry ID and owner',
    () {
      final report = QueuedReport(
        clientId: 'same-id',
        ownerId: '1',
        fields: {'captured_at': '2026-10-04T10:00:00Z'},
        photo: Uint8List.fromList([1, 2, 3]),
      );
      final restored = QueuedReport.fromJson(
        jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>,
      );
      expect(restored.photo, report.photo);
      expect(restored.fields['captured_at'], report.fields['captured_at']);
      expect(restored.clientId, 'same-id');
      expect(restored.ownerId, '1');
    },
  );
  test('snapshots replace previous data and must match the issued role', () {
    final store = AppStore(liveUpdates: false, storage: MemoryStore());
    store.session = {
      'user': {'id': 1, 'role': 'citizen'},
    };
    store.applySnapshot({
      ...emptyState('citizen'),
      'incidents': [
        {'id': 'INC-1'},
      ],
    });
    expect(store.incidents.length, 1);
    store.applySnapshot(emptyState('citizen'));
    expect(store.incidents, isEmpty);
    expect(
      () => store.applySnapshot(emptyState('officer')),
      throwsA(isA<ApiException>()),
    );
    store.dispose();
  });
  test(
    'offline report from another account cannot enter current queue',
    () async {
      final store = AppStore(liveUpdates: false, storage: MemoryStore());
      store.session = {
        'user': {'id': 1, 'role': 'citizen'},
      };
      final report = QueuedReport(
        clientId: 'other',
        ownerId: '2',
        fields: {},
        photo: Uint8List.fromList([1]),
      );
      expect(() => store.submit(report), throwsA(isA<ApiException>()));
      expect(store.pending, isEmpty);
      store.dispose();
    },
  );
  test(
    'incomplete acknowledgement keeps queued report until canonical receipt',
    () async {
      var uploads = 0;
      final storage = MemoryStore();
      final api = BackendApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/snapshot') {
            return http.Response(jsonEncode(emptyState('citizen')), 200);
          }
          uploads++;
          return http.Response(
            uploads <= 2
                ? '{"success":true}'
                : '{"success":true,"incident_id":"INC-1","report_id":"RPT-1"}',
            201,
          );
        }),
      );
      final store = AppStore(liveUpdates: false, storage: storage, api: api);
      store.session = {
        'user': {'id': 1, 'role': 'citizen'},
      };
      api.accessToken = 'fixture';
      final report = QueuedReport(
        clientId: 'stable',
        ownerId: '1',
        fields: {'captured_at': '2026-10-04T10:00:00Z'},
        photo: Uint8List.fromList([1, 2]),
      );
      expect(await store.submit(report), false);
      expect(store.pending.single.clientId, 'stable');
      await store.syncPending();
      expect(store.pending, isEmpty);
      store.dispose();
    },
  );
  test(
    'queued storage limit fails explicitly without losing existing work',
    () async {
      final store = AppStore(liveUpdates: false, storage: MemoryStore());
      store.session = {
        'user': {'id': 1, 'role': 'citizen'},
      };
      final report = QueuedReport(
        clientId: 'large',
        ownerId: '1',
        fields: {},
        photo: Uint8List(3 * 1024 * 1024),
      );
      expect(() => store.submit(report), throwsA(isA<ApiException>()));
      expect(store.pending, isEmpty);
      store.dispose();
    },
  );
  test('logout clears active account data and token', () async {
    final store = AppStore(
      liveUpdates: false,
      storage: MemoryStore(),
      api: BackendApi(
        client: MockClient((_) async => http.Response('{"success":true}', 200)),
      ),
    );
    store.session = {
      'user': {'id': 1, 'role': 'officer'},
    };
    store.api.accessToken = 'fixture';
    store.applySnapshot({
      ...emptyState('officer'),
      'incidents': [
        {'id': 'INC-1'},
      ],
    });
    await store.logout();
    expect(store.role, isNull);
    expect(store.snapshot, isEmpty);
    expect(store.api.accessToken, isNull);
    store.dispose();
  });
}
