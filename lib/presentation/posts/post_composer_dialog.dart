import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/utils/helpers/file_picker/file_picker_helper.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef PostComposeResult = ({String content, bool allowComments, List<int> attachmentIds});

/// Popup tạo/sửa bài. Khi sửa, đính kèm cũ hiện sẵn: bấm X chỉ đánh dấu xóa (có Undo),
/// tới lúc Save mới gửi danh sách id cuối cùng (giữ lại + mới upload) lên server.
class PostComposerDialog extends StatefulWidget {
  const PostComposerDialog({
    super.key,
    required this.repository,
    this.content = '',
    this.allowComments = true,
    this.attachments = const [],
    this.author,
    this.editing = false,
  });
  final PostRepository repository;
  final String content;
  final bool allowComments;
  final List<PostAttachment> attachments;
  final PostUser? author;
  final bool editing;

  @override
  State<PostComposerDialog> createState() => _PostComposerDialogState();
}

class _PostComposerDialogState extends State<PostComposerDialog> {
  late final TextEditingController text = TextEditingController(text: widget.content);
  late bool allowComments = widget.allowComments;
  final strip = ScrollController();

  /// Đính kèm cũ của bài; id nằm trong [removed] sẽ bị gỡ khi Save.
  late final existing = [...widget.attachments];
  final removed = <int>{};

  final files = <LocalPickedFile>[];
  final progress = <LocalPickedFile, double>{};
  final uploadedIds = <LocalPickedFile, int>{};
  final failed = <LocalPickedFile>{};
  final tokens = <LocalPickedFile, CancelToken>{};
  PostUploadLimits? limits;
  bool saving = false;
  String? error;

  bool get uploading => files.any((f) => !uploadedIds.containsKey(f) && !failed.contains(f));
  Iterable<PostAttachment> get kept => existing.where((a) => !removed.contains(a.id));
  int get count => kept.length + files.length;
  int get totalBytes =>
      kept.fold<int>(0, (s, a) => s + a.size) + files.fold<int>(0, (s, f) => s + f.bytes.length);

  @override
  void initState() {
    super.initState();
    unawaited(_loadLimits());
  }

  @override
  void dispose() {
    text.dispose();
    strip.dispose();
    for (final token in tokens.values) {
      token.cancel();
    }
    super.dispose();
  }

  Future<void> _loadLimits() async {
    try {
      final value = await widget.repository.getUploadLimits();
      if (mounted) setState(() => limits = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load upload settings.');
    }
  }

  Future<void> _pick(String accept) async {
    final config = limits;
    if (config == null) return;
    final picked = await pickPostAttachments(accept: accept);
    if (picked.isEmpty || !mounted) return;
    if (count + picked.length > config.maxAttachments) {
      setState(() => error = 'A post supports up to ${config.maxAttachments} attachments.');
      return;
    }
    var total = totalBytes;
    var videoCount =
        kept.where((a) => a.mediaType == 'VIDEO').length +
        files.where((f) => config.videoTypes.contains(f.contentType)).length;
    for (final file in picked) {
      final image = config.imageTypes.contains(file.contentType);
      final video = config.videoTypes.contains(file.contentType);
      if (video) videoCount++;
      final accepted = image || video || config.fileTypes.contains(file.contentType);
      final maximum = image
          ? config.imageMaxBytes
          : video
          ? config.videoMaxBytes
          : config.fileMaxBytes;
      if (!accepted || file.bytes.length > maximum) {
        setState(() => error = '${file.name} is unsupported or exceeds ${_size(maximum)}.');
        return;
      }
      total += file.bytes.length;
    }
    if (videoCount > 1) {
      setState(() => error = 'A post supports one video.');
      return;
    }
    if (total > config.postMaxBytes) {
      setState(() => error = 'Attachments exceed ${_size(config.postMaxBytes)} per post.');
      return;
    }
    setState(() {
      files.addAll(picked);
      error = null;
    });
    for (final file in picked) {
      unawaited(_upload(file));
    }
    // Cuộn tới cuối dải để thấy file vừa thêm.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (strip.hasClients) {
        strip.animateTo(
          strip.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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

  void _toggleExisting(PostAttachment attachment) => setState(() {
    if (!removed.remove(attachment.id)) removed.add(attachment.id);
  });

  void _save() {
    if (text.text.trim().isEmpty && count == 0) {
      setState(() => error = 'Write something or attach a file.');
      return;
    }
    if (uploading || failed.isNotEmpty) return;
    setState(() => saving = true);
    Navigator.pop(context, (
      content: text.text.trim(),
      allowComments: allowComments,
      attachmentIds: [...kept.map((a) => a.id), ...files.map((f) => uploadedIds[f]!)],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppCubit>().state.user;
    final author = widget.author;
    final tiles = <Widget>[
      for (final a in existing)
        _ExistingTile(
          attachment: a,
          removed: removed.contains(a.id),
          onToggle: saving ? null : () => _toggleExisting(a),
        ),
      for (final f in files)
        _LocalTile(
          file: f,
          progress: uploadedIds.containsKey(f) ? null : progress[f],
          failed: failed.contains(f),
          onRetry: () => _upload(f),
          onRemove: saving ? null : () => _remove(f),
        ),
    ];
    return PopScope(
      // Chỉ đóng bằng nút Cancel/X, không đóng bằng Esc/bấm ra ngoài.
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.editing ? 'Edit post' : 'Create post',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFE4E6EB)),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          PostAvatar(user: author, url: me?.avatar, name: me?.name),
                          Text(
                            author?.name ?? me?.name ?? 'User',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      TextField(
                        controller: text,
                        minLines: 3,
                        // Viết bao nhiêu dòng cũng được; ô cao tối đa 12 dòng rồi cuộn bên trong.
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                        style: const TextStyle(fontSize: 16, height: 1.45),
                        decoration: const InputDecoration(
                          hintText: "What's on your mind?",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                      if (tiles.isNotEmpty) _attachments(tiles),
                      _addBar(),
                      if (error != null)
                        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 20, 12),
                child: Row(
                  children: [
                    Switch(
                      value: allowComments,
                      onChanged: saving ? null : (v) => setState(() => allowComments = v),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Allow comments',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(uploading ? 'Cancel upload' : 'Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: saving || uploading || failed.isNotEmpty ? null : _save,
                      child: Text(widget.editing ? 'Save' : 'Post'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachments(List<Widget> tiles) {
    final config = limits;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Attachments · $count${config == null ? '' : '/${config.maxAttachments}'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorName.labelSecondary,
                    ),
                  ),
                ),
                Text(
                  config == null
                      ? _size(totalBytes)
                      : '${_size(totalBytes)} of ${_size(config.postMaxBytes)}',
                  style: const TextStyle(fontSize: 12, color: ColorName.gray1),
                ),
              ],
            ),
          ),
          // Dải đính kèm trượt ngang; có nút mũi tên khi còn file khuất bên phải.
          SizedBox(
            height: _tileSize,
            child: Stack(
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                  child: ListView.separated(
                    controller: strip,
                    scrollDirection: Axis.horizontal,
                    itemCount: tiles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => tiles[i],
                  ),
                ),
                ListenableBuilder(
                  listenable: strip,
                  builder: (context, _) {
                    final more =
                        strip.hasClients &&
                        strip.position.hasContentDimensions &&
                        strip.offset < strip.position.maxScrollExtent - 1;
                    if (!more) return const SizedBox.shrink();
                    return Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 56,
                        alignment: Alignment.centerRight,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0x00FFFFFF), Colors.white]),
                        ),
                        child: IconButton.outlined(
                          tooltip: 'More',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: ColorName.gray5),
                          ),
                          onPressed: () => strip.animateTo(
                            (strip.offset + _tileSize * 3).clamp(0, strip.position.maxScrollExtent),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                          icon: const Icon(Icons.chevron_right, size: 18),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addBar() {
    final enabled = !saving && limits != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Add to your post',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Photo/video',
            onPressed: enabled ? () => _pick(postMediaAccept) : null,
            icon: const Icon(Icons.photo_library_outlined, color: Colors.green),
          ),
          IconButton(
            tooltip: 'Document',
            onPressed: enabled ? () => _pick(postDocumentAccept) : null,
            icon: const Icon(Icons.description_outlined, color: Colors.orange),
          ),
        ],
      ),
    );
  }
}

const _tileSize = 112.0;

/// Ô đính kèm đã có trên bài; [removed] thì mờ đi, gạch tên và hiện Undo.
class _ExistingTile extends StatelessWidget {
  const _ExistingTile({required this.attachment, required this.removed, this.onToggle});
  final PostAttachment attachment;
  final bool removed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final preview = a.mediaType == 'IMAGE'
        ? Image.network(a.url, fit: BoxFit.cover)
        : a.mediaType == 'VIDEO'
        ? _VideoPreview(thumbnail: a.thumbnailUrl, seconds: a.durationSeconds)
        : _DocumentPreview(name: a.originalName, size: a.size, removed: removed);
    return _Tile(
      removed: removed,
      corner: removed ? _UndoChip(onPressed: onToggle) : _RemoveButton(onPressed: onToggle),
      child: removed && a.mediaType != 'FILE'
          ? Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: 0.35, child: preview),
                const Center(
                  child: Text(
                    'Removed on save',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : preview,
    );
  }
}

/// Ô file mới chọn: xem trước ảnh từ bytes, hiện tiến độ upload hoặc nút thử lại.
class _LocalTile extends StatelessWidget {
  const _LocalTile({
    required this.file,
    required this.progress,
    required this.failed,
    required this.onRetry,
    this.onRemove,
  });
  final LocalPickedFile file;
  final double? progress;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final type = file.contentType;
    final preview = type.startsWith('image/')
        ? Image.memory(file.bytes, fit: BoxFit.cover)
        : type.startsWith('video/')
        ? const _VideoPreview()
        : _DocumentPreview(name: file.name, size: file.bytes.length);
    return _Tile(
      corner: _RemoveButton(onPressed: onRemove),
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          if (failed)
            ColoredBox(
              color: Colors.white.withValues(alpha: 0.75),
              child: Center(
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ),
            )
          else if (progress != null)
            ColoredBox(
              color: Colors.white.withValues(alpha: 0.55),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      'Uploading ${(progress! * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorName.primary,
                      ),
                    ),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child, required this.corner, this.removed = false});
  final Widget child, corner;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _tileSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: removed ? const Color(0xFFFFF5F5) : const Color(0xFFF5F6F8),
                  border: Border.all(color: removed ? const Color(0xFFF3C5C5) : ColorName.gray5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: child,
              ),
            ),
          ),
          Positioned(top: 6, right: 6, child: corner),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 14, color: ColorName.labelPrimary),
        ),
      ),
    );
  }
}

class _UndoChip extends StatelessWidget {
  const _UndoChip({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: ColorName.gray5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            'Undo',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorName.primary),
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({this.thumbnail, this.seconds});
  final String? thumbnail;
  final double? seconds;

  @override
  Widget build(BuildContext context) {
    final s = seconds?.round();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnail != null)
          Image.network(thumbnail!, fit: BoxFit.cover)
        else
          const ColoredBox(color: Color(0xFF9AA3A8)),
        const Center(
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.black45,
            child: Icon(Icons.play_arrow, color: Colors.white),
          ),
        ),
        if (s != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.name, required this.size, this.removed = false});
  final String name;
  final int size;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    final color = removed ? Colors.red : ColorName.primary;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description_outlined, size: 20, color: color),
          ),
          const Spacer(),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: removed ? ColorName.gray1 : ColorName.labelPrimary,
              decoration: removed ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            removed ? 'Removed on save' : _size(size),
            style: TextStyle(fontSize: 11, color: removed ? Colors.red : ColorName.gray1),
          ),
        ],
      ),
    );
  }
}

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(1)} KB';
