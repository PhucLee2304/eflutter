import 'dart:typed_data';

class LocalPickedFile {
  const LocalPickedFile({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final Uint8List bytes;
}
