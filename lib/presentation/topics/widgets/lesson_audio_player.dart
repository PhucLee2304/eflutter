import 'dart:async';

import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/topics/widgets/lesson_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:solar_icons/solar_icons.dart';

/// Phát audio mp3 của lesson.
class LessonAudioController {
  final AudioPlayer player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  String? _preparedUrl;

  void setPositionListener(ValueChanged<double>? listener) {
    _positionSubscription?.cancel();
    _positionSubscription = listener == null
        ? null
        : player.positionStream.listen(
            (position) => listener(position.inMilliseconds / 1000.0),
          );
  }

  Future<void> prepare(String url) async {
    if (_preparedUrl == url) return;
    _preparedUrl = url;
    try {
      await player.setUrl(url);
    } catch (e) {
      debugPrint('Error loading lesson audio: $e');
    }
  }

  Future<void> seekToAndPlay(double seconds) async {
    await player.seek(Duration(milliseconds: (seconds * 1000).round()));
    // play() chỉ xong khi dừng hoặc hết bài nên không await.
    unawaited(player.play());
  }

  void dispose() {
    _positionSubscription?.cancel();
    player.dispose();
  }
}

/// Thanh điều khiển audio một hàng: câu trước/sau, play, tiến trình, tốc độ,
/// Repeat và Auto-scroll.
class LessonAudioBar extends StatelessWidget {
  const LessonAudioBar({
    required this.controller,
    required this.onPrevious,
    required this.onNext,
    required this.isRepeating,
    required this.onToggleRepeat,
    required this.autoScroll,
    required this.onToggleAutoScroll,
    super.key,
  });

  final LessonAudioController controller;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool isRepeating;
  final VoidCallback? onToggleRepeat;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = controller.player;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous sentence',
            onPressed: onPrevious,
            icon: const Icon(SolarIconsBold.skipPrevious, size: 22),
            color: ColorName.labelPrimary,
          ),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final isPlaying =
                  (state?.playing ?? false) &&
                  state?.processingState != ProcessingState.completed;
              return IconButton.filled(
                tooltip: isPlaying ? 'Pause' : 'Play',
                style: IconButton.styleFrom(
                  backgroundColor: ColorName.primary,
                  fixedSize: const Size.square(44),
                ),
                onPressed: () {
                  if (isPlaying) {
                    player.pause();
                    return;
                  }
                  if (state?.processingState == ProcessingState.completed) {
                    player.seek(Duration.zero);
                  }
                  player.play();
                },
                icon: Icon(
                  isPlaying ? SolarIconsBold.pause : SolarIconsBold.play,
                  size: 20,
                  color: ColorName.white,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Next sentence',
            onPressed: onNext,
            icon: const Icon(SolarIconsBold.skipNext, size: 22),
            color: ColorName.labelPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = player.duration ?? Duration.zero;
                final max = duration.inMilliseconds.toDouble();
                return Row(
                  children: [
                    Text(_formatDuration(position), style: _timeStyle),
                    Expanded(
                      child: SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 6,
                          activeTrackColor: ColorName.primary,
                          inactiveTrackColor: ColorName.gray5,
                          thumbColor: ColorName.primary,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          max: max > 0 ? max : 1,
                          value: position.inMilliseconds.toDouble().clamp(
                            0,
                            max > 0 ? max : 1,
                          ),
                          onChanged: max > 0
                              ? (value) => player.seek(
                                  Duration(milliseconds: value.round()),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Text(_formatDuration(duration), style: _timeStyle),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          StreamBuilder<double>(
            stream: player.speedStream,
            builder: (context, snapshot) {
              final speed = snapshot.data ?? 1.0;
              return PopupMenuButton<double>(
                tooltip: 'Playback speed',
                initialValue: speed,
                onSelected: player.setSpeed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(minWidth: 168),
                itemBuilder: (context) => [
                  const PopupMenuItem<double>(
                    enabled: false,
                    height: 32,
                    child: Text(
                      'Playback speed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ColorName.labelSecondary,
                      ),
                    ),
                  ),
                  for (final option in _speeds)
                    PopupMenuItem<double>(
                      value: option,
                      height: 36,
                      child: Row(
                        spacing: 10,
                        children: [
                          SizedBox(
                            width: 18,
                            child: option == speed
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: ColorName.primary,
                                  )
                                : null,
                          ),
                          Text(option == 1.0 ? 'Normal' : _speedLabel(option)),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorName.gray6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _speedLabel(speed),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorName.labelPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          LessonIconButton(
            icon: SolarIconsOutline.repeat,
            tooltip: 'Repeat sentence',
            selected: isRepeating,
            onPressed: onToggleRepeat,
          ),
          const SizedBox(width: 8),
          LessonIconButton(
            icon: SolarIconsOutline.sortFromTopToBottom,
            tooltip: 'Auto-scroll',
            selected: autoScroll,
            onPressed: onToggleAutoScroll,
          ),
        ],
      ),
    );
  }
}

const _timeStyle = TextStyle(fontSize: 12, color: ColorName.labelSecondary);

/// 1.0 -> "1x", 1.25 -> "1.25x"
String _speedLabel(double speed) =>
    '${speed.toString().replaceAll(RegExp(r'\.0$'), '')}x';

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
