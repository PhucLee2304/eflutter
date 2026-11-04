import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

TextSpan _seeMoreSpan(ThemeData theme, VoidCallback onTap) => TextSpan(
  text: 'See more',
  style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
  mouseCursor: SystemMouseCursors.click,
  recognizer: TapGestureRecognizer()..onTap = onTap,
);

/// Nội dung rút gọn kiểu Facebook: tối đa [maxLines] dòng, bị cắt thì kết
/// thúc bằng "… See more" ngay trong dòng cuối.
class _PreviewText extends StatelessWidget {
  const _PreviewText({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.onMore,
  });
  final String text;
  final TextStyle? style;
  final int maxLines;
  final VoidCallback? onMore;

  static bool overflows(String text, TextStyle? style, int maxLines, double width) {
    if (text.isEmpty) return false;
    return _painter(TextSpan(text: text, style: style), maxLines, width).didExceedMaxLines;
  }

  static TextPainter _painter(InlineSpan span, int maxLines, double width) =>
      TextPainter(text: span, maxLines: maxLines, textDirection: TextDirection.ltr)
        ..layout(maxWidth: width);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        if (!overflows(text, style, maxLines, c.maxWidth)) {
          return Text(text, style: style);
        }
        final more = TextSpan(
          children: [
            TextSpan(text: '… ', style: style),
            if (onMore != null) _seeMoreSpan(theme, onMore!),
          ],
          style: style,
        );
        // Tìm số ký tự dài nhất mà phần đầu + "… See more" vẫn vừa maxLines.
        var lo = 0, hi = text.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          final span = TextSpan(
            style: style,
            children: [
              TextSpan(text: text.substring(0, mid).trimRight()),
              more,
            ],
          );
          if (_painter(span, maxLines, c.maxWidth).didExceedMaxLines) {
            hi = mid - 1;
          } else {
            lo = mid;
          }
        }
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: text.substring(0, lo).trimRight()),
              more,
            ],
          ),
          maxLines: maxLines,
        );
      },
    );
  }
}

/// Thẻ bài viết kiểu Facebook. Ở danh sách ([full] = false) nội dung dài và
/// danh sách file bị rút gọn, bấm "See more" để mở trang chi tiết; comment chỉ
/// được tải ở trang chi tiết.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.readOnly,
    required this.onLike,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
    required this.admin,
    required this.onModerate,
    this.onOpen,
    this.onComment,
    this.full = false,
    this.footer,
  });
  final PostItem post;
  final bool readOnly, admin, full;
  final VoidCallback onLike, onPin, onEdit, onDelete;
  final ValueChanged<String> onModerate;

  /// Mở trang chi tiết; null khi đang ở trang chi tiết.
  final VoidCallback? onOpen;
  final VoidCallback? onComment;

  /// Phần dưới hàng nút (khung comment ở trang chi tiết).
  final Widget? footer;

  static const _previewLines = 3;
  static const _previewFiles = 3;

  @override
  Widget build(BuildContext context) {
    final hidden = post.status == 'HIDDEN';
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final canComment = post.allowComments || post.commentCount > 0;
    final files = post.attachments
        .where((a) => a.mediaType != 'IMAGE' && a.mediaType != 'VIDEO')
        .toList();
    final hiddenFiles = full ? 0 : files.length - _previewFiles;
    final extraFiles = hiddenFiles > 0 ? files.skip(_previewFiles).toSet() : <PostAttachment>{};
    final shown = post.attachments.where((a) => !extraFiles.contains(a)).toList();
    return Opacity(
      opacity: hidden ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
              child: _header(context, hidden, muted),
            ),
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: full
                    ? Text(post.content, style: theme.textTheme.bodyLarge)
                    : _PreviewText(
                        text: post.content,
                        style: theme.textTheme.bodyLarge,
                        maxLines: _previewLines,
                        onMore: onOpen,
                      ),
              ),
            if (shown.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PostAttachments(attachments: shown),
              ),
            if (hiddenFiles > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: LayoutBuilder(
                  // Chỉ một nút "See more": ưu tiên ở nội dung, nội dung đã bị
                  // cắt thì ở đây chỉ báo số file còn lại.
                  builder: (context, c) => Text.rich(
                    TextSpan(
                      style: muted,
                      children: [
                        TextSpan(text: '+$hiddenFiles more file${hiddenFiles == 1 ? '' : 's'}'),
                        if (onOpen != null &&
                            !_PreviewText.overflows(
                              post.content,
                              theme.textTheme.bodyLarge,
                              _previewLines,
                              c.maxWidth,
                            )) ...[
                          const TextSpan(text: ' · '),
                          _seeMoreSpan(theme, onOpen!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (post.likeCount > 0 || post.commentCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    if (post.likeCount > 0) ...[
                      const CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.favorite, size: 11, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text('${post.likeCount}', style: muted),
                    ],
                    const Spacer(),
                    if (post.commentCount > 0)
                      InkWell(
                        onTap: onOpen,
                        child: Text(
                          '${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}',
                          style: muted,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: post.liked ? Icons.favorite : Icons.favorite_border,
                          label: 'Like',
                          color: post.liked ? Colors.red : null,
                          onPressed: readOnly ? null : onLike,
                        ),
                      ),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Comment',
                          onPressed: canComment ? (onComment ?? onOpen) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            footer ?? const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool hidden, TextStyle? muted) => Row(
    children: [
      PostAvatar(user: post.author),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.author?.name ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            InkWell(
              onTap: onOpen,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(relativeTime(post.createdAt), style: muted),
                  if (post.pinned) ...[
                    Text(' · ', style: muted),
                    Icon(Icons.push_pin, size: 13, color: muted?.color),
                    Text(' Pinned', style: muted),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      if (hidden)
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Chip(label: Text('Hidden by moderation')),
        ),
      if (admin)
        PopupMenuButton<String>(
          tooltip: 'Moderate',
          icon: const Icon(Icons.shield_outlined),
          onSelected: onModerate,
          itemBuilder: (_) => [
            if (post.status == 'PUBLISHED') const PopupMenuItem(value: 'HIDE', child: Text('Hide')),
            if (post.status == 'HIDDEN')
              const PopupMenuItem(value: 'UNHIDE', child: Text('Unhide')),
            const PopupMenuItem(value: 'DELETE', child: Text('Delete')),
          ],
        ),
      if (post.canEdit || post.canDelete || post.canPin)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          position: PopupMenuPosition.under,
          // Menu gọn vừa chữ, không ép rộng tối thiểu như mặc định.
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          menuPadding: const EdgeInsets.all(6),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          ),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
            if (value == 'pin') onPin();
          },
          itemBuilder: (_) => [
            if (post.canEdit) _menuItem('edit', Icons.edit_outlined, 'Edit'),
            if (post.canPin && !readOnly)
              _menuItem('pin', Icons.push_pin_outlined, post.pinned ? 'Unpin' : 'Pin'),
            if (post.canDelete)
              _menuItem('delete', Icons.delete_outline, 'Delete', color: Colors.red),
          ],
        ),
    ],
  );
}

PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) =>
    PopupMenuItem(
      value: value,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Icon(icon, size: 18, color: color),
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onPressed, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).hintColor;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
