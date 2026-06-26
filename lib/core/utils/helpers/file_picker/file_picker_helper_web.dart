import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
import 'package:web/web.dart' as web;

Future<LocalPickedFile?> pickImageFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  web.document.body?.append(input);

  final completer = Completer<LocalPickedFile?>();

  late final web.EventListener changeListener;
  changeListener = ((web.Event event) {
    final file = input.files?.item(0);
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    final reader = web.FileReader();
    late final web.EventListener loadListener;
    late final web.EventListener errorListener;

    loadListener = ((web.Event event) {
      final result = reader.result;
      if (result == null) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      final dataUrl = (result as JSString).toDart;
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      final bytes = base64Decode(dataUrl.substring(commaIndex + 1));
      if (!completer.isCompleted) {
        completer.complete(
          LocalPickedFile(
            name: file.name,
            contentType: file.type.isEmpty
                ? 'application/octet-stream'
                : file.type,
            bytes: bytes,
          ),
        );
      }
    }).toJS;

    errorListener = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(reader.error?.message ?? 'Unable to read selected file.'),
        );
      }
    }).toJS;

    reader.addEventListener('load', loadListener);
    reader.addEventListener('error', errorListener);
    reader.readAsDataURL(file);
  }).toJS;

  input.addEventListener('change', changeListener);
  input.click();

  return completer.future.whenComplete(() {
    input.removeEventListener('change', changeListener);
    input.remove();
  });
}
