import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'trpc_envelope.dart';

class CitizenAuthSession {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final String name;
  final String email;
  final String phone;

  const CitizenAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory CitizenAuthSession.fromJson(Map<String, dynamic> json) {
    final user =
        (json['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return CitizenAuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: (user['id'] as num).toInt(),
      name: user['name'] as String? ?? 'Citizen',
      email: user['email'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
    );
  }
}

class CitizenChallenge {
  final int challengeId;
  final int userId;
  final int expiresInSeconds;
  final List<String> channels;

  const CitizenChallenge({
    required this.challengeId,
    required this.userId,
    required this.expiresInSeconds,
    this.channels = const ['email'],
  });
}

class CitizenAuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'nalanetra.citizen.access_token';
  static const _refreshKey = 'nalanetra.citizen.refresh_token';
  static const _userKey = 'nalanetra.citizen.user_json';

  static Future<Map<String, dynamic>> _call(
    String procedure,
    Map<String, dynamic> input, {
    String? bearer,
  }) async {
    final uri = Uri.parse(
      '$nalanetraBackendBaseUrl/api/trpc/citizenAuth.$procedure?batch=1',
    );
    final response = await http
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            if (bearer != null) 'authorization': 'Bearer $bearer',
          },
          body: jsonEncode({
            '0': {'json': input},
          }),
        )
        .timeout(const Duration(seconds: 25));
    try {
      return decodeTrpcBatchResponse(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Citizen authentication failed.',
      );
    } on TrpcEnvelopeException catch (e) {
      throw CitizenAuthException(e.message);
    }
  }

  static Future<CitizenChallenge> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _call('register', {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    return CitizenChallenge(
      challengeId: (data['challengeId'] as num).toInt(),
      userId: (data['userId'] as num?)?.toInt() ?? 0,
      expiresInSeconds: (data['expiresInSeconds'] as num).toInt(),
      channels:
          ((data['channels'] as List?)?.whereType<String>().toList()) ??
          const ['email'],
    );
  }

  static Future<CitizenAuthSession> verify({
    required int challengeId,
    required String emailCode,
  }) async {
    final data = await _call('verify', {
      'challengeId': challengeId,
      'emailCode': emailCode,
    });
    final session = CitizenAuthSession.fromJson(data);
    await save(session);
    return session;
  }

  static Future<CitizenAuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _call('login', {'email': email, 'password': password});
    final session = CitizenAuthSession.fromJson(data);
    await save(session);
    return session;
  }

  static Future<CitizenChallenge> resend({required int userId}) async {
    final data = await _call('resend', {'userId': userId});
    return CitizenChallenge(
      challengeId: (data['challengeId'] as num).toInt(),
      userId: userId,
      expiresInSeconds: (data['expiresInSeconds'] as num).toInt(),
      channels:
          ((data['channels'] as List?)?.whereType<String>().toList()) ??
          const ['email'],
    );
  }

  static Future<CitizenChallenge> resendByEmail({required String email}) async {
    final data = await _call('resendByEmail', {'email': email});
    return CitizenChallenge(
      challengeId: (data['challengeId'] as num).toInt(),
      userId: (data['userId'] as num).toInt(),
      expiresInSeconds: (data['expiresInSeconds'] as num).toInt(),
      channels:
          ((data['channels'] as List?)?.whereType<String>().toList()) ??
          const ['email'],
    );
  }

  static Future<CitizenAuthSession?> restore() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      final userJson = await _storage.read(key: _userKey);
      if (access == null || refresh == null || userJson == null) return null;
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      return CitizenAuthSession(
        accessToken: access,
        refreshToken: refresh,
        userId: (user['userId'] as num).toInt(),
        name: user['name'] as String,
        email: user['email'] as String,
        phone: user['phone'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<CitizenAuthSession?> refresh(String refreshToken) async {
    try {
      final data = await _call('refresh', {'refreshToken': refreshToken});
      final previous = await restore();
      if (previous == null) return null;
      final session = CitizenAuthSession(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: previous.userId,
        name: previous.name,
        email: previous.email,
        phone: previous.phone,
      );
      await save(session);
      return session;
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(CitizenAuthSession session) async {
    try {
      await _storage.write(key: _accessKey, value: session.accessToken);
      await _storage.write(key: _refreshKey, value: session.refreshToken);
      await _storage.write(
        key: _userKey,
        value: jsonEncode({
          'userId': session.userId,
          'name': session.name,
          'email': session.email,
          'phone': session.phone,
        }),
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _userKey);
    } catch (_) {}
  }
}

class CitizenAuthException implements Exception {
  final String message;
  const CitizenAuthException(this.message);
  @override
  String toString() => message;
}
