import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Custom video controls rendered by Chewie via [ChewieController.customControls].
///
/// Giống YouTube: thanh điều khiển hiện khi rê chuột hoặc đang dừng, tự ẩn sau
/// [_hideDelay] khi video đang phát; bấm vào video để phát/dừng.
class CustomVideoControls extends StatefulWidget {
  const CustomVideoControls({super.key});

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  bool _isVolumeHovered = false;
  bool _isHovering = false;
  bool _isMenuOpen = false;
  Timer? _hideTimer;
  ChewieController? _chewieController;

  static const _hideDelay = Duration(milliseconds: 2500);
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

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
    _hideTimer?.cancel();
    _chewieController?.videoPlayerController.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (!mounted) return;
    setState(() {
      _latestValue = controller.value;
    });
  }

  void _showControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _isHovering = false);
    });
    if (!_isHovering) setState(() => _isHovering = true);
  }

  /// 1.0 -> "1x", 1.25 -> "1.25x"
  String _speedLabel(double speed) =>
      '${speed.toString().replaceAll(RegExp(r'\.0$'), '')}x';

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

    final chewie = _chewieController!;
    final visible = !_latestValue.isPlaying || _isHovering || _isMenuOpen;
    final caption = chewie.showSubtitles
        ? chewie.subtitle?.getByPosition(_latestValue.position).firstOrNull
        : null;
    return MouseRegion(
      onHover: (_) => _showControls(),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _togglePlay();
                _showControls();
              },
            ),
          ),
          if (caption != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              // Thanh điều khiển ẩn thì phụ đề hạ xuống sát đáy, như YouTube.
              bottom: visible ? 76 : 20,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${caption.text}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _buildBottomBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    // Nền phẳng: LinearGradient vẽ đè lên video (platform view) làm CanvasKit
    // ném "Null check operator" ở CkGradientLinear.getSkShader.
    // Material vì IconButton/Slider/PopupMenuButton cần Material phía trên.
    return Material(
      color: Colors.black54,
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
                  playedColor: ColorName.primary,
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
                        tooltip: _latestValue.volume == 0 ? 'Unmute' : 'Mute',
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _isVolumeHovered ? 100 : 0,
                        // Chiều cao cố định: OverflowBox trong Row/Column không giới hạn
                        // chiều cao sẽ đòi cao vô hạn và làm cả thanh điều khiển không vẽ được.
                        height: 40,
                        curve: Curves.easeInOut,
                        child: ClipRect(
                          child: OverflowBox(
                            maxWidth: 100,
                            alignment: Alignment.centerLeft,
                            child: SliderTheme(
                              data: SliderThemeData(
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const Spacer(),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  initialValue: _latestValue.playbackSpeed,
                  // Mở lên trên nút, ngay trên thanh điều khiển.
                  offset: Offset(0, -(_speeds.length * 36.0 + 56)),
                  color: const Color(0xF0212121),
                  elevation: 0,
                  constraints: const BoxConstraints(minWidth: 168),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onOpened: () => setState(() => _isMenuOpen = true),
                  onCanceled: () => setState(() => _isMenuOpen = false),
                  onSelected: (speed) {
                    controller.setPlaybackSpeed(speed);
                    setState(() => _isMenuOpen = false);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<double>(
                      enabled: false,
                      height: 32,
                      child: Text(
                        'Playback speed',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final speed in _speeds)
                      PopupMenuItem<double>(
                        value: speed,
                        height: 36,
                        child: Row(
                          spacing: 10,
                          children: [
                            SizedBox(
                              width: 18,
                              child: speed == _latestValue.playbackSpeed
                                  ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            Text(
                              speed == 1.0 ? 'Normal' : _speedLabel(speed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      // Cao 16 = khung chữ nhật của icon CC (24px).
                      height: 16,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        _speedLabel(_latestValue.playbackSpeed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _chewieController!.showSubtitles
                        ? Icons.closed_caption
                        : Icons.closed_caption_disabled_outlined,
                    color: Colors.white,
                  ),
                  tooltip: _chewieController!.showSubtitles
                      ? 'Hide captions'
                      : 'Show captions',
                  onPressed: () => setState(() {
                    _chewieController!.showSubtitles =
                        !_chewieController!.showSubtitles;
                  }),
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
