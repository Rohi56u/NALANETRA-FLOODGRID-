import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'trpc_envelope.dart';

class StaffAuthSession {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String staffId;
  final Portal role;

  const StaffAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.staffId,
    required this.role,
  });

  factory StaffAuthSession.fromJson(Map<String, dynamic> json, Portal role) {
    final user =
        (json['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return StaffAuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: (user['id'] as num).toInt(),
      name:
          (user['name'] as String?) ??
          (role == Portal.officer ? 'MCG Officer' : 'Field Crew'),
      email: user['email'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
      staffId: user['staffId'] as String? ?? '',
      role: role,
    );
  }
}

class StaffChallenge {
  final int challengeId;
  final int userId;
  final int expiresInSeconds;
  final Portal portal;
  final List<String> channels;

  const StaffChallenge({
    required this.challengeId,
    required this.userId,
    required this.expiresInSeconds,
    required this.portal,
    this.channels = const ['email'],
  });
}

class StaffAuthService {
  static const _storage = FlutterSecureStorage();
  static const _officerAccessKey = 'nalanetra.staff.officer.access_token';
  static const _officerRefreshKey = 'nalanetra.staff.officer.refresh_token';
  static const _officerUserKey = 'nalanetra.staff.officer.user_json';
  static const _crewAccessKey = 'nalanetra.staff.crew.access_token';
  static const _crewRefreshKey = 'nalanetra.staff.crew.refresh_token';
  static const _crewUserKey = 'nalanetra.staff.crew.user_json';

  static String _apiRole(Portal role) {
    if (role == Portal.officer) return 'officer';
    if (role == Portal.crew) return 'crew';
    throw const StaffAuthException('Select MCG Officer or Field Crew.');
  }

  static Future<Map<String, dynamic>> _call(
    String procedure,
    Map<String, dynamic> input,
  ) async {
    final uri = Uri.parse(
      '$nalanetraBackendBaseUrl/api/trpc/staffAuth.$procedure?batch=1',
    );
    final response = await http
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            '0': {'json': input},
          }),
        )
        .timeout(const Duration(seconds: 25));
    try {
      return decodeTrpcBatchResponse(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Staff authentication failed.',
      );
    } on TrpcEnvelopeException catch (e) {
      throw StaffAuthException(e.message);
    }
  }

  static Future<StaffChallenge> register({
    required Portal role,
    required String staffId,
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final data = await _call('register', {
      'role': _apiRole(role),
      'staffId': staffId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'password': password,
    });
    return _challenge(data, role);
  }

  static Future<StaffAuthSession> verify({
    required Portal role,
    required int challengeId,
    required String emailCode,
  }) async {
    final data = await _call('verify', {
      'role': _apiRole(role),
      'challengeId': challengeId,
      'emailCode': emailCode,
    });
    final session = StaffAuthSession.fromJson(data, role);
    await _save(session);
    return session;
  }

  static Future<StaffAuthSession> login({
    required Portal role,
    required String staffId,
    required String email,
    required String password,
  }) async {
    final data = await _call('login', {
      'role': _apiRole(role),
      'staffId': staffId,
      'email': email,
      'password': password,
    });
    final session = StaffAuthSession.fromJson(data, role);
    await _save(session);
    return session;
  }

  static Future<StaffChallenge> resendByEmail({
    required Portal role,
    required String staffId,
    required String email,
  }) async {
    final data = await _call('resendByEmail', {
      'role': _apiRole(role),
      'staffId': staffId,
      'email': email,
    });
    return _challenge(data, role);
  }

  static StaffChallenge _challenge(Map<String, dynamic> data, Portal role) {
    return StaffChallenge(
      challengeId: (data['challengeId'] as num).toInt(),
      userId: (data['userId'] as num?)?.toInt() ?? 0,
      expiresInSeconds: (data['expiresInSeconds'] as num).toInt(),
      portal: role,
      channels:
          ((data['channels'] as List?)?.whereType<String>().toList()) ??
          const ['email'],
    );
  }

  static Future<StaffAuthSession?> restore(Portal role) async {
    try {
      final access = await _storage.read(key: _accessKey(role));
      final refresh = await _storage.read(key: _refreshKey(role));
      final userJson = await _storage.read(key: _userKey(role));
      if (access == null || refresh == null || userJson == null) return null;
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      return StaffAuthSession(
        accessToken: access,
        refreshToken: refresh,
        userId: (user['userId'] as num).toInt(),
        name: user['name'] as String,
        email: user['email'] as String,
        phone: user['phone'] as String,
        staffId: user['staffId'] as String,
        role: role,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<StaffAuthSession?> refresh(
    Portal role,
    String refreshToken,
  ) async {
    try {
      final data = await _call('refresh', {
        'role': _apiRole(role),
        'refreshToken': refreshToken,
      });
      final previous = await restore(role);
      if (previous == null) return null;
      final session = StaffAuthSession(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: previous.userId,
        name: previous.name,
        email: previous.email,
        phone: previous.phone,
        staffId: previous.staffId,
        role: role,
      );
      await _save(session);
      return session;
    } catch (_) {
      await clear(role);
      return null;
    }
  }

  static Future<void> _save(StaffAuthSession session) async {
    try {
      await _storage.write(
        key: _accessKey(session.role),
        value: session.accessToken,
      );
      await _storage.write(
        key: _refreshKey(session.role),
        value: session.refreshToken,
      );
      await _storage.write(
        key: _userKey(session.role),
        value: jsonEncode({
          'userId': session.userId,
          'name': session.name,
          'email': session.email,
          'phone': session.phone,
          'staffId': session.staffId,
        }),
      );
    } catch (_) {}
  }

  static Future<void> clear(Portal role) async {
    try {
      await _storage.delete(key: _accessKey(role));
      await _storage.delete(key: _refreshKey(role));
      await _storage.delete(key: _userKey(role));
    } catch (_) {}
  }

  static String _accessKey(Portal role) =>
      role == Portal.officer ? _officerAccessKey : _crewAccessKey;
  static String _refreshKey(Portal role) =>
      role == Portal.officer ? _officerRefreshKey : _crewRefreshKey;
  static String _userKey(Portal role) =>
      role == Portal.officer ? _officerUserKey : _crewUserKey;
}

class StaffAuthException implements Exception {
  final String message;
  const StaffAuthException(this.message);
  @override
  String toString() => message;
}
