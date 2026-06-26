import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> uploadBinaryToUrl({
  required String url,
  required Uint8List bytes,
  required String contentType,
}) async {
  try {
    final headers = web.Headers();
    headers.set('Content-Type', contentType);
    final request = web.Request(
      url.toJS,
      web.RequestInit(
        method: 'PUT',
        headers: headers,
        body: bytes.toJS,
      ),
    );
    final response = await web
        .window
        .fetch(request)
        .toDart;

    if (!response.ok) {
      throw Exception(
        'Upload failed with status ${response.status}: ${response.statusText}',
      );
    }
  } catch (_) {
    throw Exception(
      'Avatar upload was blocked before reaching storage. This is usually a CORS rule on the storage bucket or presigned URL.',
    );
  }
}
