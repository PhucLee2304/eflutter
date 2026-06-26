import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<void> uploadBinaryToUrl({
  required String url,
  required Uint8List bytes,
  required String contentType,
}) async {
  final dio = Dio();
  await dio.put<void>(
    url,
    data: bytes,
    options: Options(
      responseType: ResponseType.plain,
      headers: {'Content-Type': contentType},
    ),
  );
}
