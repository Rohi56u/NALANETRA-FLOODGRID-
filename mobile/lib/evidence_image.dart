import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';

/// Protected image bytes are fetched with the active account's bearer token.
class EvidenceImage extends StatelessWidget {
  final String path;
  final double height;
  const EvidenceImage({super.key, required this.path, this.height = 180});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final uri = Uri.parse('$backendBaseUrl$path')
        .replace(queryParameters: {'account': store.ownerId ?? ''});
    if (!path.startsWith('/api/v1/evidence/')) {
      return const Icon(Icons.image_not_supported_outlined);
    }
    return Image.network(
      uri.toString(),
      headers: store.api.headers,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => SizedBox(
        height: height,
        child: const Center(child: Text('Protected evidence unavailable')),
      ),
    );
  }
}
