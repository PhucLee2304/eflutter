import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';

Future<LocalPickedFile?> pickImageFile() async {
  return null;
}

const postMediaAccept =
    'image/jpeg,image/png,image/webp,video/mp4,video/quicktime';
const postDocumentAccept = '.pdf,.txt,.doc,.docx,.xls,.xlsx,.ppt,.pptx';

Future<List<LocalPickedFile>> pickPostAttachments({String? accept}) async =>
    const [];
