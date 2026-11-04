import 'dart:convert';

import 'package:flutter/material.dart';

/// Reaction là dữ liệu realtime tạm thời: gửi thẳng qua LiveKit data channel,
/// không qua backend, không lưu và không phát lại cho người vào sau.
enum RoomReaction {
  thumbsUp('thumbs_up', '👍', 'Agree'),
  clap('clap', '👏', 'Clap'),
  heart('heart', '❤️', 'Love'),
  surprised('surprised', '😮', 'Surprised');

  const RoomReaction(this.code, this.emoji, this.label);
  final String code;
  final String emoji;
  final String label;
}

const roomReactionTopic = 'reaction';
const roomReactionMaxBytes = 64;
const roomReactionDisplayDuration = Duration(seconds: 4);
const roomReactionMaxVisible = 12;

List<int> encodeRoomReaction(RoomReaction reaction) =>
    utf8.encode(jsonEncode({'v': 1, 'reaction': reaction.code}));

/// Chỉ chấp nhận reaction trong tập cho phép; payload không chứa danh tính,
/// người gửi luôn lấy từ participant LiveKit đã gửi packet.
RoomReaction? decodeRoomReaction(List<int> data) {
  if (data.isEmpty || data.length > roomReactionMaxBytes) return null;
  try {
    final json = jsonDecode(utf8.decode(data));
    if (json is! Map<String, dynamic>) return null;
    final code = json['reaction'];
    for (final reaction in RoomReaction.values) {
      if (reaction.code == code) return reaction;
    }
  } catch (_) {}
  return null;
}

/// Giới hạn kiểu cửa sổ trượt: tối đa [maxEvents] trong [window] cho mỗi key.
/// Dùng ở cả phía gửi lẫn phía nhận để một client lỗi không làm rối phòng.
class RoomReactionLimiter {
  RoomReactionLimiter({this.maxEvents = 3, this.window = const Duration(seconds: 3)});

  final int maxEvents;
  final Duration window;
  final _events = <String, List<DateTime>>{};

  bool allow(String key, DateTime now) {
    final events = _events.putIfAbsent(key, () => [])
      ..removeWhere((time) => now.difference(time) >= window);
    if (events.length >= maxEvents) return false;
    events.add(now);
    return true;
  }
}

class RoomReactionBubble {
  const RoomReactionBubble({required this.id, required this.reaction, required this.senderName});

  final int id;
  final RoomReaction reaction;
  final String senderName;
}

/// Thêm bubble mới, giữ tối đa [roomReactionMaxVisible] bubble mới nhất.
List<RoomReactionBubble> addRoomReactionBubble(
  List<RoomReactionBubble> bubbles,
  RoomReactionBubble bubble,
) {
  final next = [...bubbles, bubble];
  return next.length <= roomReactionMaxVisible
      ? next
      : next.sublist(next.length - roomReactionMaxVisible);
}

class RoomReactionOverlay extends StatelessWidget {
  const RoomReactionOverlay({super.key, required this.bubbles});
  final List<RoomReactionBubble> bubbles;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bubble in bubbles) _ReactionBubble(key: ValueKey(bubble.id), bubble: bubble),
      ],
    ),
  );
}

class _ReactionBubble extends StatelessWidget {
  const _ReactionBubble({super.key, required this.bubble});
  final RoomReactionBubble bubble;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '${bubble.senderName}: ${bubble.reaction.label}',
    child: ExcludeSemantics(
      // Nổi lên và mờ dần trong lúc hiển thị rồi bị gỡ khỏi danh sách.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: roomReactionDisplayDuration,
        builder: (context, progress, child) => Opacity(
          opacity: progress < 0.75 ? 1 : (1 - progress) * 4,
          child: Transform.translate(offset: Offset(0, -24 * progress), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
            decoration: BoxDecoration(
              color: roomReactionSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roomReactionBorder),
              boxShadow: roomReactionShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bubble.reaction.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    bubble.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffe8eaed),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const roomReactionSurface = Color(0xff2d2e31);
const roomReactionBorder = Color(0xff3c4043);
const roomReactionShadow = [
  BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8)),
];

/// Thanh chọn reaction: chỉ emoji, bấm là gửi ngay và thanh vẫn mở để gửi tiếp.
class RoomReactionPicker extends StatelessWidget {
  const RoomReactionPicker({super.key, required this.onSelected});
  final ValueChanged<RoomReaction> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: roomReactionSurface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: roomReactionBorder),
      boxShadow: roomReactionShadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final reaction in RoomReaction.values)
          _PickerEmoji(reaction: reaction, onTap: () => onSelected(reaction)),
      ],
    ),
  );
}

class _PickerEmoji extends StatefulWidget {
  const _PickerEmoji({required this.reaction, required this.onTap});
  final RoomReaction reaction;
  final VoidCallback onTap;

  @override
  State<_PickerEmoji> createState() => _PickerEmojiState();
}

class _PickerEmojiState extends State<_PickerEmoji> with SingleTickerProviderStateMixin {
  bool hovered = false;
  late final pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void _tap() {
    pulse.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.reaction.label,
    child: Semantics(
      button: true,
      label: widget.reaction.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTap: _tap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hovered ? roomReactionBorder : Colors.transparent,
            ),
            child: AnimatedBuilder(
              animation: pulse,
              // Bấm thì emoji co lại một nhịp để biết đã gửi.
              builder: (context, child) => Transform.scale(
                scale:
                    (hovered ? 1.2 : 1) *
                    (1 -
                        0.25 *
                            Curves.easeOut.transform(
                              pulse.value < 0.5 ? pulse.value * 2 : (1 - pulse.value) * 2,
                            )),
                child: child,
              ),
              child: ExcludeSemantics(
                child: Text(widget.reaction.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
