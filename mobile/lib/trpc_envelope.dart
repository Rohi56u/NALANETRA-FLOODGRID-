import 'dart:convert';

class TrpcEnvelopeException implements Exception {
  final String message;
  const TrpcEnvelopeException(this.message);

  @override
  String toString() => message;
}

Map<String, dynamic> decodeTrpcBatchResponse(
  String body, {
  required int statusCode,
  required String fallbackMessage,
}) {
  final decoded = jsonDecode(body);
  final item = _firstMap(decoded);
  if (item == null) {
    throw TrpcEnvelopeException(fallbackMessage);
  }

  final error = item['error'];
  if (error != null) {
    final errorMap = error is Map ? error.cast<String, dynamic>() : null;
    final errorJson = errorMap?['json'];
    final errorData = errorJson is Map
        ? errorJson.cast<String, dynamic>()
        : const <String, dynamic>{};
    throw TrpcEnvelopeException(
      errorData['message'] as String? ?? fallbackMessage,
    );
  }

  if (statusCode < 200 || statusCode >= 300) {
    throw TrpcEnvelopeException(fallbackMessage);
  }

  final result = item['result'];
  final resultMap = result is Map ? result.cast<String, dynamic>() : null;
  final data = resultMap?['data'];
  final dataMap = data is Map ? data.cast<String, dynamic>() : null;
  final payload = dataMap?['json'] ?? dataMap;
  if (payload is Map) {
    return payload.cast<String, dynamic>();
  }

  throw TrpcEnvelopeException(fallbackMessage);
}

Map<String, dynamic>? _firstMap(dynamic decoded) {
  if (decoded is List && decoded.isNotEmpty) {
    final first = decoded.first;
    return first is Map ? first.cast<String, dynamic>() : null;
  }
  return decoded is Map ? decoded.cast<String, dynamic>() : null;
}
