import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({super.key, required this.url, this.thumbnailUrl});
  final String url;
  final String? thumbnailUrl;
  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? video;
  ChewieController? chewie;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      video = controller;
      chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        showOptions: false,
        placeholder: widget.thumbnailUrl == null
            ? null
            : Image.network(widget.thumbnailUrl!, fit: BoxFit.cover),
      );
    });
  }

  @override
  void dispose() {
    chewie?.dispose();
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: ValueKey('video-${widget.url}'),
    onVisibilityChanged: (info) {
      if (info.visibleFraction < .35) video?.pause();
    },
    child: AspectRatio(
      aspectRatio: video?.value.aspectRatio ?? 16 / 9,
      child: chewie == null
          ? const Center(child: CircularProgressIndicator())
          : Chewie(controller: chewie!),
    ),
  );
}
