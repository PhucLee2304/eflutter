import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/utils/helpers/file_picker/file_picker_helper.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:flutter/material.dart';

typedef PostComposeResult = ({
  String content,
  bool allowComments,
  List<int> attachmentIds,
});

class PostComposerDialog extends StatefulWidget {
  const PostComposerDialog({
    super.key,
    required this.repository,
    this.content = '',
    this.allowComments = true,
    this.editing = false,
  });
  final PostRepository repository;
  final String content;
  final bool allowComments;
  final bool editing;

  @override
  State<PostComposerDialog> createState() => _PostComposerDialogState();
}

class _PostComposerDialogState extends State<PostComposerDialog> {
  late final TextEditingController text = TextEditingController(
    text: widget.content,
  );
  late bool allowComments = widget.allowComments;
  final files = <LocalPickedFile>[];
  final progress = <LocalPickedFile, double>{};
  final uploadedIds = <LocalPickedFile, int>{};
  final failed = <LocalPickedFile>{};
  final tokens = <LocalPickedFile, CancelToken>{};
  PostUploadLimits? limits;
  bool saving = false;

  bool get uploading =>
      files.any((f) => !uploadedIds.containsKey(f) && !failed.contains(f));
  String? error;

  @override
  void initState() {
    super.initState();
    if (!widget.editing) unawaited(_loadLimits());
  }

  Future<void> _loadLimits() async {
    try {
      final value = await widget.repository.getUploadLimits();
      if (mounted) setState(() => limits = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load upload settings.');
    }
  }

  Future<void> _pick() async {
    final config = limits;
    if (config == null) return;
    final picked = await pickPostAttachments();
    if (picked.isEmpty || !mounted) return;
    final combined = [...files, ...picked];
    if (combined.length > config.maxAttachments) {
      setState(
        () => error =
            'A post supports up to ${config.maxAttachments} attachments.',
      );
      return;
    }
    var total = 0;
    var videoCount = 0;
    for (final file in combined) {
      final image = config.imageTypes.contains(file.contentType);
      final video = config.videoTypes.contains(file.contentType);
      if (video) videoCount++;
      final accepted =
          image || video || config.fileTypes.contains(file.contentType);
      final maximum = image
          ? config.imageMaxBytes
          : video
          ? config.videoMaxBytes
          : config.fileMaxBytes;
      if (!accepted || file.bytes.length > maximum) {
        setState(
          () => error =
              '${file.name} is unsupported or exceeds ${_size(maximum)}.',
        );
        return;
      }
      total += file.bytes.length;
    }
    if (videoCount > 1) {
      setState(() => error = 'A post supports one video.');
      return;
    }
    if (total > config.postMaxBytes) {
      setState(
        () => error =
            'Attachments exceed ${_size(config.postMaxBytes)} per post.',
      );
      return;
    }
    setState(() {
      files
        ..clear()
        ..addAll(combined);
      error = null;
    });
    for (final file in picked) {
      unawaited(_upload(file));
    }
  }

  /// Tải file lên ngay khi chọn (presign + PUT + complete), để lúc bấm Save
  /// chỉ còn gửi danh sách id.
  Future<void> _upload(LocalPickedFile file) async {
    final token = CancelToken();
    tokens[file] = token;
    setState(() {
      failed.remove(file);
      progress[file] = 0;
    });
    try {
      final id = await widget.repository.uploadAttachment(
        file,
        cancelToken: token,
        onProgress: (value) {
          if (mounted) setState(() => progress[file] = value);
        },
      );
      if (mounted) setState(() => uploadedIds[file] = id);
    } catch (e) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        failed.add(file);
        error = 'Upload of ${file.name} failed. Tap retry.';
      });
    } finally {
      if (tokens[file] == token) tokens.remove(file);
    }
  }

  void _remove(LocalPickedFile file) {
    tokens.remove(file)?.cancel();
    setState(() {
      files.remove(file);
      progress.remove(file);
      uploadedIds.remove(file);
      failed.remove(file);
    });
  }

  void _save() {
    if (text.text.trim().isEmpty && files.isEmpty) {
      setState(() => error = 'Write something or attach a file.');
      return;
    }
    if (uploading || failed.isNotEmpty) return;
    setState(() => saving = true);
    Navigator.pop(context, (
      content: text.text.trim(),
      allowComments: allowComments,
      attachmentIds: [for (final f in files) uploadedIds[f]!],
    ));
  }

  @override
  void dispose() {
    for (final token in tokens.values) {
      token.cancel();
    }
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Chỉ đóng bằng nút Cancel, không đóng bằng Esc/bấm ra ngoài.
    canPop: false,
    child: AlertDialog(
      title: Text(widget.editing ? 'Edit post' : 'Create post'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                minLines: 4,
                maxLines: 10,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow comments'),
                value: allowComments,
                onChanged: saving
                    ? null
                    : (v) => setState(() => allowComments = v),
              ),
              if (!widget.editing)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: saving || limits == null ? null : _pick,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Add photos or documents'),
                  ),
                ),
              ...files.map(
                (file) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    file.contentType.startsWith('image/')
                        ? Icons.image_outlined
                        : file.contentType.startsWith('video/')
                        ? Icons.videocam_outlined
                        : Icons.description_outlined,
                  ),
                  title: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle:
                      uploadedIds.containsKey(file) || failed.contains(file)
                      ? Text(
                          failed.contains(file)
                              ? 'Upload failed'
                              : _size(file.bytes.length),
                        )
                      : LinearProgressIndicator(value: progress[file]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (failed.contains(file))
                        IconButton(
                          tooltip: 'Retry',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _upload(file),
                        ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () => _remove(file),
                      ),
                    ],
                  ),
                ),
              ),
              if (error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(uploading ? 'Cancel upload' : 'Cancel'),
        ),
        FilledButton(
          onPressed: saving || uploading || failed.isNotEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
    : '${(bytes / 1024).toStringAsFixed(1)} KiB';
