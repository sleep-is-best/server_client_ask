import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/reel.dart';
import '../services/api_service.dart';
import '../config.dart';

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
  String? _error;
  bool _showPlayIcon = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    final videoUrl = _resolveVideoUrl(widget.reel.videoUrl);
    if (videoUrl == null) {
      if (mounted) setState(() => _error = 'رابط الفيديو غير صالح');
      return;
    }
    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
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
      await _controller.dispose();
      if (mounted) setState(() => _error = 'تعذر تشغيل الفيديو');
    }
  }

  String? _resolveVideoUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.hasScheme && uri.host.isNotEmpty) {
      // API responses from local development can contain localhost, which
      // is the device itself rather than the server.
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return uri.replace(host: AppConfig.serverHost).toString();
      }
      return raw;
    }
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '${AppConfig.serverUrl}$path';
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
            _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white70, size: 42),
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _initializeController();
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : _isInitialized
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
