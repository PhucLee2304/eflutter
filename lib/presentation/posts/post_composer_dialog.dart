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
  final progress = <int, double>{};
  final uploadedIds = <LocalPickedFile, int>{};
  PostUploadLimits? limits;
  CancelToken? cancelToken;
  bool saving = false;
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
  }

  Future<void> _save() async {
    if (text.text.trim().isEmpty && files.isEmpty) {
      setState(() => error = 'Write something or attach a file.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
      progress.clear();
    });
    cancelToken = CancelToken();
    try {
      final ids = <int>[];
      for (var i = 0; i < files.length; i++) {
        final existing = uploadedIds[files[i]];
        if (existing != null) {
          ids.add(existing);
          continue;
        }
        final id = await widget.repository.uploadAttachment(
          files[i],
          cancelToken: cancelToken!,
          onProgress: (value) {
            if (mounted) setState(() => progress[i] = value);
          },
        );
        uploadedIds[files[i]] = id;
        ids.add(id);
      }
      if (mounted) {
        Navigator.pop(context, (
          content: text.text.trim(),
          allowComments: allowComments,
          attachmentIds: ids,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is DioException && CancelToken.isCancel(e)
              ? 'Upload cancelled.'
              : 'Upload failed. Check your connection and retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    cancelToken?.cancel();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
            ...files.asMap().entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.value.contentType.startsWith('image/')
                      ? Icons.image_outlined
                      : entry.value.contentType.startsWith('video/')
                      ? Icons.videocam_outlined
                      : Icons.description_outlined,
                ),
                title: Text(
                  entry.value.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: progress[entry.key] == null
                    ? Text(_size(entry.value.bytes.length))
                    : LinearProgressIndicator(value: progress[entry.key]),
                trailing: saving
                    ? null
                    : IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => files.removeAt(entry.key)),
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
        onPressed: () {
          if (saving) {
            cancelToken?.cancel();
          } else {
            Navigator.pop(context);
          }
        },
        child: Text(saving ? 'Cancel upload' : 'Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(
          error?.startsWith('Upload failed') == true ? 'Retry' : 'Save',
        ),
      ),
    ],
  );
}

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
    : '${(bytes / 1024).toStringAsFixed(1)} KiB';
