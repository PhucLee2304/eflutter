import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/material.dart';

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

  static const _previewChars = 300;
  static const _previewLines = 5;
  static const _previewFiles = 3;

  @override
  Widget build(BuildContext context) {
    final hidden = post.status == 'HIDDEN';
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final canComment = post.allowComments || post.commentCount > 0;
    final longText =
        post.content.length > _previewChars ||
        '\n'.allMatches(post.content).length >= _previewLines;
    final files = post.attachments
        .where((a) => a.mediaType != 'IMAGE' && a.mediaType != 'VIDEO')
        .toList();
    final hiddenFiles = full ? 0 : files.length - _previewFiles;
    final extraFiles = hiddenFiles > 0
        ? files.skip(_previewFiles).toSet()
        : <PostAttachment>{};
    final shown = post.attachments
        .where((a) => !extraFiles.contains(a))
        .toList();
    final truncated = !full && (longText || hiddenFiles > 0);
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
                child: Text(
                  post.content,
                  style: theme.textTheme.bodyLarge,
                  maxLines: full ? null : _previewLines,
                  overflow: full ? null : TextOverflow.ellipsis,
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
                child: Text(
                  '+$hiddenFiles more file${hiddenFiles == 1 ? '' : 's'}',
                  style: muted,
                ),
              ),
            if (truncated && onOpen != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: TextButton(
                    onPressed: onOpen,
                    child: const Text('See more'),
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
                        child: Icon(
                          Icons.favorite,
                          size: 11,
                          color: Colors.white,
                        ),
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
                          icon: post.liked
                              ? Icons.favorite
                              : Icons.favorite_border,
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
            if (post.status == 'PUBLISHED')
              const PopupMenuItem(value: 'HIDE', child: Text('Hide')),
            if (post.status == 'HIDDEN')
              const PopupMenuItem(value: 'UNHIDE', child: Text('Unhide')),
            const PopupMenuItem(value: 'DELETE', child: Text('Delete')),
          ],
        ),
      if (post.canEdit || post.canDelete || post.canPin)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
            if (value == 'pin') onPin();
          },
          itemBuilder: (_) => [
            if (post.canEdit)
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (post.canPin && !readOnly)
              PopupMenuItem(
                value: 'pin',
                child: Text(post.pinned ? 'Unpin' : 'Pin'),
              ),
            if (post.canDelete)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
  });
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
