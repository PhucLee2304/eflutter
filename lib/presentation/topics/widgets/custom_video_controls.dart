import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Custom video controls rendered by Chewie via [ChewieController.customControls].
///
/// Chewie itself handles show/hide animation and pointer event interception
/// over the HTML platform view on Web. This widget only provides the UI.
class CustomVideoControls extends StatefulWidget {
  const CustomVideoControls({super.key});

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  bool _isVolumeHovered = false;
  ChewieController? _chewieController;

  VideoPlayerController get controller =>
      _chewieController!.videoPlayerController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newChewieController = ChewieController.of(context);

    if (_chewieController != newChewieController) {
      if (_chewieController != null) {
        _chewieController!.videoPlayerController.removeListener(_updateState);
      }

      _chewieController = newChewieController;
      _latestValue = controller.value;
      controller.addListener(_updateState);
    }
  }

  @override
  void dispose() {
    _chewieController?.videoPlayerController.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (!mounted) return;
    setState(() {
      _latestValue = controller.value;
    });
  }

  void _togglePlay() {
    if (_latestValue.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _toggleMute() {
    if (_latestValue.volume == 0) {
      controller.setVolume(_latestVolume ?? 1.0);
    } else {
      _latestVolume = _latestValue.volume;
      controller.setVolume(0.0);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) return const SizedBox.shrink();

    // No GestureDetector — Chewie handles tap-to-toggle-controls.
    // We only render the bottom bar. The empty area above passes taps to Chewie.
    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 10,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ),

          // Controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _latestValue.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlay,
                  tooltip: _latestValue.isPlaying ? 'Pause' : 'Play',
                ),
                MouseRegion(
                  onEnter: (_) => setState(() => _isVolumeHovered = true),
                  onExit: (_) => setState(() => _isVolumeHovered = false),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _latestValue.volume == 0
                              ? Icons.volume_off
                              : _latestValue.volume < 0.5
                                  ? Icons.volume_down
                                  : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: _toggleMute,
                        tooltip:
                            _latestValue.volume == 0 ? 'Unmute' : 'Mute',
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _isVolumeHovered ? 100 : 0,
                        curve: Curves.easeInOut,
                        child: ClipRect(
                          child: OverflowBox(
                            maxWidth: 100,
                            alignment: Alignment.centerLeft,
                            child: SliderTheme(
                              data: SliderThemeData(
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _latestValue.volume,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white30,
                                onChanged: (val) {
                                  controller.setVolume(val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatDuration(_latestValue.position)} / ${_formatDuration(_latestValue.duration)}',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const Spacer(),
                Theme(
                  data: Theme.of(context).copyWith(
                    cardColor: const Color(0xFF282828),
                  ),
                  child: PopupMenuButton<double>(
                    initialValue: _latestValue.playbackSpeed,
                    tooltip: 'Tốc độ phát',
                    onSelected: (speed) {
                      controller.setPlaybackSpeed(speed);
                    },
                    offset: const Offset(0, -200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: const Color(0xFF282828),
                    itemBuilder: (context) {
                      return [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
                        return PopupMenuItem<double>(
                          value: speed,
                          height: 36,
                          child: Text(
                            speed == 1.0 ? 'Chuẩn' : '${speed}x',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  _latestValue.playbackSpeed == speed
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    icon: const Icon(Icons.settings, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _chewieController!.isFullScreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  tooltip: 'Fullscreen',
                  onPressed: () {
                    _chewieController!.toggleFullScreen();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
