import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart'
    show VideoTrack, VideoTrackRenderer, VideoViewFit;

/// Nút chia sẻ màn hình trên thanh điều khiển ở từng trạng thái.
enum RoomScreenShareControl { unavailable, request, waiting, start, stop }

RoomScreenShareControl roomScreenShareControl({
  required bool supported,
  required bool isHost,
  required bool sharing,
  RoomParticipantState? ownState,
}) {
  if (!supported) return RoomScreenShareControl.unavailable;
  if (sharing) return RoomScreenShareControl.stop;
  if (isHost || ownState?.screenShareApprovedAt != null) {
    return RoomScreenShareControl.start;
  }
  if (ownState?.screenShareRequestedAt != null) {
    return RoomScreenShareControl.waiting;
  }
  return RoomScreenShareControl.request;
}

/// Yêu cầu đang chờ giáo viên duyệt, cũ nhất trước.
List<RoomParticipantState> pendingScreenShareRequests(RoomActivity? activity) {
  final pending = [
    for (final state in activity?.participants ?? const <RoomParticipantState>[])
      if (state.screenShareRequestedAt != null &&
          state.screenShareApprovedAt == null &&
          state.removedAt == null)
        state,
  ];
  pending.sort((a, b) => a.screenShareRequestedAt!.compareTo(b.screenShareRequestedAt!));
  return pending;
}

/// Backend chỉ cho một người chia sẻ, nhưng trong khoảnh khắc thay thế có thể
/// thấy hai track; khi đó ưu tiên giáo viên để mọi client chọn giống nhau.
T? pickRoomPresenter<T>(Iterable<T> presenters, bool Function(T) isHost) {
  T? first;
  for (final presenter in presenters) {
    if (isHost(presenter)) return presenter;
    first ??= presenter;
  }
  return first;
}

class RoomScreenShareStage extends StatelessWidget {
  const RoomScreenShareStage({
    super.key,
    required this.presenterName,
    required this.isLocal,
    this.track,
    this.onStop,
  });

  final String presenterName;
  final bool isLocal;
  final VideoTrack? track;

  /// Có giá trị khi người xem được phép dừng phần chia sẻ này.
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final label = isLocal ? 'You are presenting' : '$presenterName is presenting';
    return Semantics(
      container: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: const Color(0xff202124),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Không render màn hình của chính mình để tránh hiệu ứng gương
              // lặp vô hạn khi người dùng chia sẻ toàn màn hình.
              if (isLocal)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.present_to_all, size: 56, color: Colors.white70),
                      SizedBox(height: 12),
                      Text(
                        'Everyone in the class can see your screen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else if (track != null)
                ExcludeSemantics(child: VideoTrackRenderer(track!, fit: VideoViewFit.contain))
              else
                const AppLoader(),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.present_to_all, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (onStop != null)
                      FilledButton.icon(
                        onPressed: onStop,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.stop_screen_share),
                        label: Text(isLocal ? 'Stop presenting' : 'Stop'),
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
}

/// Yêu cầu chia sẻ màn hình (Figma R2): mỗi lần một thẻ có avatar và hai nút; các
/// yêu cầu còn lại gộp thành "+N more". Ghi rõ nếu đang có người trình chiếu.
class RoomScreenShareRequests extends StatelessWidget {
  const RoomScreenShareRequests({
    super.key,
    required this.requests,
    required this.nameOf,
    required this.onReview,
    this.reviewing = const {},
    this.presentingName,
    this.presentingIsLocal = false,
  });

  final List<RoomParticipantState> requests;
  final String Function(String userId) nameOf;
  final void Function(String userId, bool approve) onReview;

  /// userId đang chờ phản hồi từ backend; nút của họ bị khóa để tránh bấm lặp.
  final Set<String> reviewing;

  /// Người đang trình chiếu (nếu có), để giáo viên biết trước khi cho phép;
  /// [presentingIsLocal]: chính giáo viên đang trình chiếu.
  final String? presentingName;
  final bool presentingIsLocal;

  static const _card = Color(0xFF2D2E31);
  static const _line = Color(0xFF3C4043);
  static const _muted = Color(0xFFBDC1C6);
  static const _avatarColors = [
    Color(0xFF1E8E3E),
    Color(0xFFB26A00),
    Color(0xFF0483CA),
    Color(0xFF8E44AD),
    Color(0xFFD93025),
  ];

  @override
  Widget build(BuildContext context) {
    final request = requests.first;
    final name = nameOf(request.userId);
    final busy = reviewing.contains(request.userId);
    final more = requests.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: _card,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            _avatarColors[request.userId.hashCode.abs() % _avatarColors.length],
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Wants to share their screen',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.present_to_all, size: 18, color: Color(0xFF8AB4F8)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : () => onReview(request.userId, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE8EAED),
                          side: const BorderSide(color: Color(0xFF5F6368)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Decline'),
                      ),
                      FilledButton(
                        onPressed: busy ? null : () => onReview(request.userId, true),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Allow'),
                      ),
                    ],
                  ),
                  if (presentingName != null)
                    Text(
                      presentingIsLocal
                          ? 'You are presenting right now.'
                          : '$presentingName is presenting right now.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9AA0A6)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (more > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(999)),
            child: Text(
              '+$more more ${more == 1 ? 'request' : 'requests'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE8EAED),
              ),
            ),
          ),
      ],
    );
  }
}
