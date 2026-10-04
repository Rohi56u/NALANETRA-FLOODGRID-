import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, [this.statusCode = 0]);
  @override
  String toString() => message;
}

/// REST contract shared by all role interfaces. No separate tRPC service.
class BackendApi {
  final http.Client client;
  String? accessToken;
  BackendApi({http.Client? client}) : client = client ?? http.Client();
  Map<String, String> get headers => {
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  dynamic decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
        'Unexpected service response (${response.statusCode}).',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data is Map ? data['detail'] : null;
      throw ApiException(
        detail is String ? detail : 'Check required fields and retry.',
        response.statusCode,
      );
    }
    return data;
  }

  Future<dynamic> get(String path) async => decode(
    await client
        .get(Uri.parse('$backendBaseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 20)),
  );
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => (decode(
    await client
        .post(
          Uri.parse('$backendBaseUrl$path'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25)),
  ) as Map).cast<String, dynamic>();
  Future<Map<String, dynamic>> upload(
    String path,
    Uint8List photo,
    Map<String, String> fields,
  ) async {
    if (photo.isEmpty || photo.length > 6 * 1024 * 1024) {
      throw const ApiException('Use a photo of at most 6 MiB.');
    }
    final request =
        http.MultipartRequest('POST', Uri.parse('$backendBaseUrl$path'))
          ..headers.addAll(headers)
          ..fields.addAll(fields)
          ..files.add(
            http.MultipartFile.fromBytes(
              'photo',
              photo,
              filename: 'capture.jpg',
            ),
          );
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    return (decode(await http.Response.fromStream(response)) as Map)
        .cast<String, dynamic>();
  }
}
