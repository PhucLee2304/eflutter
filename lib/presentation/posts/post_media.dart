import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/shared/app_video_player.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Avatar tròn: ảnh nếu có URL, ngược lại là chữ cái đầu của tên.
class PostAvatar extends StatelessWidget {
  const PostAvatar({super.key, this.user, this.url, this.name, this.radius = 20});
  final PostUser? user;
  final String? url;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final src = (url ?? user?.avatar)?.trim();
    final label = (name ?? user?.name ?? '').trim();
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: label.isEmpty
          ? Icon(Icons.person, size: radius)
          : Text(
              label.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600),
            ),
    );
    if (src == null || src.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        src,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Nền xám nhạt kiểu Facebook cho bong bóng comment, ô nhập, thẻ file.
Color postBubbleColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? Theme.of(context).colorScheme.surfaceContainerHighest
    : const Color(0xFFF0F2F5);

Future<void> openAttachment(PostAttachment attachment) =>
    launchUrl(Uri.parse(attachment.url), webOnlyWindowName: '_blank');

/// Ảnh/video dạng lưới như Facebook, file tài liệu dạng thẻ gọn bên dưới.
class PostAttachments extends StatelessWidget {
  const PostAttachments({super.key, required this.attachments});
  final List<PostAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final media = attachments.where((a) => a.mediaType == 'IMAGE').toList();
    final videos = attachments.where((a) => a.mediaType == 'VIDEO').toList();
    final files = attachments
        .where((a) => a.mediaType != 'IMAGE' && a.mediaType != 'VIDEO')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final video in videos) _Video(attachment: video),
        if (media.isNotEmpty) _ImageGrid(images: media),
        if (files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final file in files) _FileTile(attachment: file)],
            ),
          ),
      ],
    );
  }
}

class _Video extends StatelessWidget {
  const _Video({required this.attachment});
  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.processingStatus == 'PROCESSING') {
      return const ListTile(
        leading: SizedBox.square(dimension: 24, child: AppLoader()),
        title: Text('Video is being processed'),
      );
    }
    if (attachment.processingStatus == 'FAILED') {
      return const ListTile(
        leading: Icon(Icons.error_outline),
        title: Text('Video processing failed'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AppVideoPlayer(url: attachment.url, thumbnailUrl: attachment.thumbnailUrl),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  // Khối ảnh không cao quá 420 để mỗi bài vừa một màn hình.
  static const _maxHeight = 420.0;

  Widget _box(double aspectRatio, {required Widget child}) => LayoutBuilder(
    builder: (context, c) =>
        SizedBox(height: (c.maxWidth / aspectRatio).clamp(0, _maxHeight).toDouble(), child: child),
  );
  final List<PostAttachment> images;

  Widget _cell(BuildContext context, int index, {int extra = 0}) => GestureDetector(
    onTap: () => showImageViewer(context, images, index),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            images[index].url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
          if (extra > 0)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const gap = 2.0;
    final n = images.length;
    Widget row(List<Widget> children) => Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ],
    );
    if (n == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: GestureDetector(
          onTap: () => showImageViewer(context, images, 0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Image.network(
              images[0].url,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 160,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      );
    }
    if (n == 2) {
      return _box(2, child: row([_cell(context, 0), _cell(context, 1)]));
    }
    if (n == 3) {
      return _box(
        1.5,
        child: Row(
          children: [
            Expanded(flex: 2, child: _cell(context, 0)),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _cell(context, 1)),
                  const SizedBox(height: gap),
                  Expanded(child: _cell(context, 2)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // 4 ảnh trở lên: 1 ảnh lớn trên, 3 ảnh nhỏ dưới, ô cuối hiện +N.
    return _box(
      1,
      child: Column(
        children: [
          Expanded(flex: 2, child: _cell(context, 0)),
          const SizedBox(height: gap),
          Expanded(
            child: row([_cell(context, 1), _cell(context, 2), _cell(context, 3, extra: n - 4)]),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.attachment});
  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = attachment.originalName.contains('.')
        ? attachment.originalName.split('.').last.toUpperCase()
        : 'FILE';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Material(
        color: postBubbleColor(context),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openAttachment(attachment),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ext == 'PDF' ? Colors.red.shade600 : scheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ext.length > 4 ? ext.substring(0, 4) : ext,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(fileSize(attachment.size), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Xem ảnh toàn màn hình, vuốt/bấm mũi tên để chuyển ảnh.
Future<void> showImageViewer(BuildContext context, List<PostAttachment> images, int initial) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) => _ImageViewer(images: images, initial: initial),
    );

/// Nút xanh nhạt giống nút đóng của popup Create/Edit post.
final _viewerButton = IconButton.styleFrom(
  backgroundColor: AppButtonStyles.tint,
  foregroundColor: ColorName.primary,
);

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});
  final List<PostAttachment> images;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final controller = PageController(initialPage: widget.initial);
  late int index = widget.initial;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _go(int delta) => controller.animateToPage(
    index + delta,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      PageView.builder(
        controller: controller,
        itemCount: widget.images.length,
        onPageChanged: (value) => setState(() => index = value),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.network(widget.images[i].url, fit: BoxFit.contain)),
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: IconButton.filledTonal(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          style: _viewerButton,
          icon: const Icon(Icons.close, size: 20),
        ),
      ),
      if (index > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton.filledTonal(
              onPressed: () => _go(-1),
              style: _viewerButton,
              icon: const Icon(Icons.chevron_left),
            ),
          ),
        ),
      if (index < widget.images.length - 1)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton.filledTonal(
              onPressed: () => _go(1),
              style: _viewerButton,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ),
    ],
  );
}

String fileSize(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
    : '${(bytes / 1024).toStringAsFixed(1)} KiB';

/// Thời gian kiểu Facebook: "Just now", "5m", "3h", "2d", rồi ngày tháng.
String relativeTime(DateTime value) {
  final v = value.toLocal();
  final diff = DateTime.now().difference(v);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(v.day)}/${two(v.month)}/${v.year}';
}
