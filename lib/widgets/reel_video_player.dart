import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/reel.dart';
import '../services/api_service.dart';

class ReelVideoPlayer extends StatefulWidget {
  final Reel reel;
  final String myUserId;
  final bool isVisible;

  const ReelVideoPlayer({
    super.key,
    required this.reel,
    required this.myUserId,
    required this.isVisible,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showPlayIcon = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl));
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isVisible) {
          _controller.play();
          _startTime = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint('Video initialization error: $e');
    }
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      if (_isInitialized) {
        _controller.play();
        _startTime = DateTime.now();
      }
    } else if (!widget.isVisible && oldWidget.isVisible) {
      if (_isInitialized) {
        _controller.pause();
        _reportView();
      }
    }
  }

  void _reportView() {
    if (_startTime != null && _isInitialized) {
      final duration = DateTime.now().difference(_startTime!).inSeconds;
      if (duration > 1) {
        final totalDuration = _controller.value.duration.inSeconds;
        final completionRate = totalDuration > 0 ? duration / totalDuration : 0.0;
        ApiService.reportReelView(widget.myUserId, widget.reel.id!, duration, completionRate);
      }
      _startTime = null;
    }
  }

  @override
  void dispose() {
    _reportView();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showPlayIcon = true;
      } else {
        _controller.play();
        _showPlayIcon = false;
      }
    });
    
    if (_showPlayIcon) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showPlayIcon = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('reel_${widget.reel.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0 && mounted) {
          _controller.pause();
        } else if (info.visibleFraction > 0.8 && widget.isVisible && mounted) {
          _controller.play();
        }
      },
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _isInitialized
                ? SizedOverflowBox(
                    size: MediaQuery.of(context).size,
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            if (_showPlayIcon)
              const Icon(Icons.play_arrow, size: 80, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
