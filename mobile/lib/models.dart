import 'dart:convert';
import 'dart:typed_data';

/// Original bytes, capture time and retry ID survive offline queue persistence.
class QueuedReport {
  final String clientId, ownerId;
  final Map<String, String> fields;
  final Uint8List photo;
  const QueuedReport({
    required this.clientId,
    required this.ownerId,
    required this.fields,
    required this.photo,
  });
  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'ownerId': ownerId,
    'fields': fields,
    'photo': base64Encode(photo),
  };
  factory QueuedReport.fromJson(Map<String, dynamic> json) => QueuedReport(
    clientId: json['clientId'] as String,
    ownerId: json['ownerId'] as String,
    fields: (json['fields'] as Map).cast<String, String>(),
    photo: base64Decode(json['photo'] as String),
  );
}

List<Map<String, dynamic>> records(dynamic value) => (value as List? ?? [])
    .map((e) => (e as Map).cast<String, dynamic>())
    .toList();
