import 'dart:async';

import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:solar_icons/solar_icons.dart';

/// Audio của trang nghe TOEIC_STRICT (PLAN_TOEIC_ATTEMPT.md T7): tự phát từ
/// [startOffset] (elapsedMs của server), không tua, không dừng, chỉ chỉnh âm lượng.
/// Phát xong (hoặc không phát được, sau khi hết thời lượng) thì gọi [onCompleted].
/// Trình duyệt chặn autoplay (sau F5) thì hiện lớp phủ "Nhấn để tiếp tục nghe".
///
/// Widget gắn key theo trang: đổi trang là tạo player mới. Audio trang sau được tải
/// trước qua [ListeningAudioPreloader].
class ListeningAudio extends StatefulWidget {
  const ListeningAudio({
    super.key,
    required this.url,
    required this.durationMs,
    required this.startOffset,
    required this.onCompleted,
    required this.preloader,
  });

  final String? url;
  final int? durationMs;
  final Duration startOffset;
  final VoidCallback onCompleted;
  final ListeningAudioPreloader preloader;

  @override
  State<ListeningAudio> createState() => _ListeningAudioState();
}

class _ListeningAudioState extends State<ListeningAudio> {
  final _clock = Stopwatch()..start();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  Timer? _fallbackTimer;
  Timer? _blockedCheck;
  bool _blocked = false;
  bool _completed = false;
  double _volume = 1;

  Duration get _duration => Duration(milliseconds: widget.durationMs ?? 0);

  /// Vị trí lẽ ra đang phát: offset lúc vào trang + thời gian đã trôi.
  Duration get _expectedPosition => widget.startOffset + _clock.elapsed;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      _scheduleFallback();
      return;
    }
    if (_duration > Duration.zero && widget.startOffset >= _duration) {
      return; // Đã hết audio (F5 trong gap): ListeningCubit đang đếm gap.
    }
    final player = widget.preloader.take(url) ?? AudioPlayer();
    _player = player;
    _stateSubscription = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _complete();
    }, onError: (_) => _scheduleFallback());
    try {
      await player.setVolume(_volume);
      if (player.audioSource == null) {
        await player.setUrl(url, initialPosition: _expectedPosition);
      } else {
        await player.seek(_expectedPosition);
      }
      if (!mounted) return;
      _play();
    } catch (_) {
      _scheduleFallback();
    }
  }

  void _play() {
    final player = _player;
    if (player == null || _completed) return;
    // play() chỉ xong khi dừng/hết bài nên không await; lỗi (vd NotAllowedError) coi
    // như bị chặn autoplay.
    unawaited(player.play().catchError((_) => _markBlocked()));
    _blockedCheck?.cancel();
    final before = player.position;
    _blockedCheck = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _completed) return;
      if (!player.playing || player.position <= before) _markBlocked();
    });
  }

  void _markBlocked() {
    if (!mounted || _completed || _blocked) return;
    setState(() => _blocked = true);
    // Không nhấn thì vẫn sang trang đúng giờ (server cũng tự tiến).
    _scheduleFallback();
  }

  Future<void> _resume() async {
    final player = _player;
    if (player == null) return;
    setState(() => _blocked = false);
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
    if (_completed || _fallbackTimer?.isActive == true) return;
    final remaining = _duration - _expectedPosition;
    _fallbackTimer = Timer(
      remaining > Duration.zero ? remaining : Duration.zero,
      _complete,
    );
  }

  void _complete() {
    if (_completed) return;
    _fallbackTimer?.cancel();
    _blockedCheck?.cancel();
    if (mounted) {
      setState(() {
        _completed = true;
        _blocked = false;
      });
    } else {
      _completed = true;
    }
    widget.onCompleted();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _blockedCheck?.cancel();
    _stateSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _blocked
          ? Center(
              child: FilledButton.icon(
                key: const ValueKey('listening-resume'),
                onPressed: _resume,
                icon: const Icon(SolarIconsOutline.play),
                label: const Text('Tap to continue listening'),
              ),
            )
          : Row(
              children: [
                Icon(
                  _completed
                      ? SolarIconsOutline.checkCircle
                      : SolarIconsOutline.musicNote,
                  color: ColorName.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _completed
                        ? 'Audio finished'
                        : 'Playing — the audio cannot be paused or replayed',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(
                  SolarIconsOutline.volumeLoud,
                  size: 18,
                  color: ColorName.labelSecondary,
                ),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      _player?.setVolume(value);
                      widget.preloader.volume = value;
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Tải trước audio trang nghe kế tiếp (`nextAudioUrl`) để sang trang không phải chờ.
class ListeningAudioPreloader {
  AudioPlayer? _player;
  String? _url;
  double volume = 1;

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
    final player = _player!..setVolume(volume);
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
