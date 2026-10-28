import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:solar_icons/solar_icons.dart';

/// Audio của trang nghe TOEIC_STRICT (PLAN_TOEIC_ATTEMPT.md T7): tự phát từ
/// [startOffset] (elapsedMs của server), không tua, không dừng, không hiện điều khiển.
/// Phát xong (hoặc không phát được, sau khi hết thời lượng) thì gọi [onCompleted].
/// Trình duyệt chặn autoplay (sau F5) thì [blocked] bật, [ListeningResumeButton] hiện
/// "Nhấn để tiếp tục nghe".
///
/// Không gắn vào vòng đời widget: Flutter web không build frame khi tab bị ẩn, nên
/// player tạo trong initState sẽ không phát trang kế tiếp cho tới khi quay lại tab.
/// Màn làm bài tạo một [ListeningPlayback] mỗi trang ngay khi [ListeningCubit] đổi
/// trang. Audio trang sau được tải trước qua [ListeningAudioPreloader].
class ListeningPlayback extends ChangeNotifier {
  ListeningPlayback({
    required this.url,
    required this.durationMs,
    required this.startOffset,
    required this.onCompleted,
    required this.preloader,
  }) {
    _start();
  }

  final String? url;
  final int? durationMs;
  final Duration startOffset;
  final VoidCallback onCompleted;
  final ListeningAudioPreloader preloader;

  final _clock = Stopwatch()..start();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  Timer? _fallbackTimer;
  Timer? _blockedCheck;
  bool _blocked = false;
  bool _completed = false;
  bool _disposed = false;

  bool get blocked => _blocked;

  Duration get _duration => Duration(milliseconds: durationMs ?? 0);

  /// Vị trí lẽ ra đang phát: offset lúc vào trang + thời gian đã trôi.
  Duration get _expectedPosition => startOffset + _clock.elapsed;

  Future<void> _start() async {
    final url = this.url;
    if (url == null || url.isEmpty) {
      _scheduleFallback();
      return;
    }
    if (_duration > Duration.zero && startOffset >= _duration) {
      return; // Đã hết audio (F5 trong gap): ListeningCubit đang đếm gap.
    }
    final player = preloader.take(url) ?? AudioPlayer();
    _player = player;
    _stateSubscription = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _complete();
    }, onError: (_) => _scheduleFallback());
    try {
      if (player.audioSource == null) {
        await player.setUrl(url, initialPosition: _expectedPosition);
      } else {
        await player.seek(_expectedPosition);
      }
      if (_disposed) return;
      _play();
    } catch (_) {
      _scheduleFallback();
    }
  }

  void _play() {
    final player = _player;
    if (player == null || _completed || _disposed) return;
    // play() chỉ xong khi dừng/hết bài nên không await; lỗi (vd NotAllowedError) coi
    // như bị chặn autoplay.
    unawaited(player.play().catchError((_) => _markBlocked()));
    _blockedCheck?.cancel();
    final before = player.position;
    _blockedCheck = Timer(const Duration(milliseconds: 1500), () {
      if (_disposed || _completed) return;
      if (!player.playing || player.position <= before) _markBlocked();
    });
  }

  void _markBlocked() {
    if (_disposed || _completed || _blocked) return;
    _blocked = true;
    notifyListeners();
    // Không nhấn thì vẫn sang trang đúng giờ (server cũng tự tiến).
    _scheduleFallback();
  }

  Future<void> resume() async {
    final player = _player;
    if (player == null || _disposed) return;
    _blocked = false;
    notifyListeners();
    _fallbackTimer?.cancel();
    if (_duration > Duration.zero && _expectedPosition >= _duration) {
      _complete();
      return;
    }
    await player.seek(_expectedPosition);
    _play();
  }

  /// Không phát được: gọi onCompleted khi lẽ ra audio đã hết.
  void _scheduleFallback() {
    if (_completed || _disposed || _fallbackTimer?.isActive == true) return;
    final remaining = _duration - _expectedPosition;
    _fallbackTimer = Timer(
      remaining > Duration.zero ? remaining : Duration.zero,
      _complete,
    );
  }

  void _complete() {
    if (_completed || _disposed) return;
    _completed = true;
    _fallbackTimer?.cancel();
    _blockedCheck?.cancel();
    if (_blocked) {
      _blocked = false;
      notifyListeners();
    }
    onCompleted();
  }

  @override
  void dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _blockedCheck?.cancel();
    _stateSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }
}

/// Nút "Tap to continue listening" khi trình duyệt chặn autoplay của [playback].
class ListeningResumeButton extends StatelessWidget {
  const ListeningResumeButton({super.key, required this.playback});

  final ListeningPlayback playback;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) {
      if (!playback.blocked) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: FilledButton.icon(
            key: const ValueKey('listening-resume'),
            onPressed: playback.resume,
            icon: const Icon(SolarIconsOutline.play),
            label: const Text('Tap to continue listening'),
          ),
        ),
      );
    },
  );
}

/// Tải trước audio trang nghe kế tiếp (`nextAudioUrl`) để sang trang không phải chờ.
class ListeningAudioPreloader {
  AudioPlayer? _player;
  String? _url;

  void preload(String? url) {
    if (url == null || url.isEmpty || url == _url) return;
    _player?.dispose();
    _url = url;
    final player = AudioPlayer();
    _player = player;
    unawaited(player.setUrl(url).then((_) => null, onError: (_) => null));
  }

  /// Lấy player đã tải sẵn cho [url] (người gọi sở hữu và dispose), null nếu không có.
  AudioPlayer? take(String url) {
    if (url != _url || _player == null) return null;
    final player = _player!;
    _player = null;
    _url = null;
    return player;
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _url = null;
  }
}
