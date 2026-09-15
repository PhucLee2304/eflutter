import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:video_player/video_player.dart';

class ExamAudioPlayer extends StatefulWidget {
  const ExamAudioPlayer({super.key, required this.url});
  final String url;

  @override
  State<ExamAudioPlayer> createState() => _ExamAudioPlayerState();
}

class _ExamAudioPlayerState extends State<ExamAudioPlayer> {
  late VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object _) {
            if (mounted) setState(() => _failed = true);
          });
  }

  @override
  void didUpdateWidget(covariant ExamAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _controller.dispose();
    _failed = false;
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Row(
        children: [
          Icon(SolarIconsOutline.dangerCircle, color: ColorName.orange),
          SizedBox(width: 8),
          Text('Audio unavailable'),
        ],
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        if (!value.isInitialized) {
          return const SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds.clamp(0, durationMs);
        return Row(
          children: [
            IconButton.filledTonal(
              tooltip: value.isPlaying ? 'Pause audio' : 'Play audio',
              onPressed: value.isPlaying ? _controller.pause : _controller.play,
              icon: Icon(
                value.isPlaying
                    ? SolarIconsOutline.pauseCircle
                    : SolarIconsOutline.playCircle,
              ),
            ),
            Expanded(
              child: Slider(
                value: positionMs.toDouble(),
                max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                onChanged: (position) => _controller.seekTo(
                  Duration(milliseconds: position.round()),
                ),
              ),
            ),
            Text(_durationLabel(value.position)),
          ],
        );
      },
    );
  }
}

String _durationLabel(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
