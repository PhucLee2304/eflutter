import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/topic_transcript.dart';
import 'package:eflutter/presentation/topics/widgets/custom_video_controls.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LessonVideoController extends ChangeNotifier {
  VideoPlayerController? videoPlayerController;
  ChewieController? chewieController;
  ValueChanged<double>? _positionListener;
  String? _preparedUrl;
  bool _isDisposed = false;

  void setPositionListener(ValueChanged<double>? listener) {
    _positionListener = listener;
  }

  Future<void> seekToAndPlay(double seconds) async {
    final controller = videoPlayerController;
    if (controller == null) return;
    await controller.seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
    await controller.play();
  }

  Future<void> prepare(String url, List<TopicTranscript> transcripts) async {
    if (_preparedUrl == url) return;
    _preparedUrl = url;

    // Dispose old controllers if they exist
    _disposeControllers();

    final vpController = VideoPlayerController.networkUrl(Uri.parse(url));
    videoPlayerController = vpController;

    try {
      await vpController.initialize();
      if (_isDisposed) {
        vpController.dispose();
        return;
      }
      vpController.addListener(_videoPlayerListener);

      chewieController = ChewieController(
        videoPlayerController: vpController,
        autoPlay: false,
        looping: false,
        aspectRatio: vpController.value.aspectRatio,
        allowFullScreen: true,
        showOptions: false,
        customControls: const CustomVideoControls(),
        // Phụ đề lấy từ transcript; CustomVideoControls tự vẽ và bật/tắt bằng nút CC.
        showSubtitles: true,
        subtitle: Subtitles([
          for (final transcript in transcripts)
            Subtitle(
              index: transcript.order,
              start: Duration(
                milliseconds: (transcript.timeStart * 1000).round(),
              ),
              end: Duration(milliseconds: (transcript.timeEnd * 1000).round()),
              text: transcript.content,
            ),
        ]),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  void _videoPlayerListener() {
    if (_isDisposed) return;
    final controller = videoPlayerController;
    if (controller != null && _positionListener != null) {
      _positionListener!(controller.value.position.inMilliseconds / 1000.0);
    }
  }

  void _disposeControllers() {
    videoPlayerController?.removeListener(_videoPlayerListener);
    chewieController?.dispose();
    videoPlayerController?.dispose();
    chewieController = null;
    videoPlayerController = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeControllers();
    super.dispose();
  }
}

class LessonVideoPlayer extends StatefulWidget {
  const LessonVideoPlayer({
    required this.url,
    required this.transcripts,
    required this.controller,
    super.key,
  });

  final String url;
  final List<TopicTranscript> transcripts;
  final LessonVideoController controller;

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.prepare(widget.url, widget.transcripts);
  }

  @override
  void didUpdateWidget(covariant LessonVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      widget.controller.prepare(widget.url, widget.transcripts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final chewie = widget.controller.chewieController;
        if (chewie != null) {
          return Chewie(controller: chewie);
        }
        return const AppLoader();
      },
    );
  }
}
