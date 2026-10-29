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

class RoomScreenShareRequests extends StatelessWidget {
  const RoomScreenShareRequests({
    super.key,
    required this.requests,
    required this.nameOf,
    required this.onReview,
    this.reviewing = const {},
  });

  final List<RoomParticipantState> requests;
  final String Function(String userId) nameOf;
  final void Function(String userId, bool approve) onReview;

  /// userId đang chờ phản hồi từ backend; nút của họ bị khóa để tránh bấm lặp.
  final Set<String> reviewing;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final request in requests)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: const Color(0xff303134),
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.present_to_all, color: Colors.white70),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '${nameOf(request.userId)} wants to present',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: reviewing.contains(request.userId)
                        ? null
                        : () => onReview(request.userId, false),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: reviewing.contains(request.userId)
                        ? null
                        : () => onReview(request.userId, true),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
