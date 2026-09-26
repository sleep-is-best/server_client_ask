import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

class CallScreen extends StatefulWidget {
  final String userId;
  final String targetUserId;
  final bool isVideo;
  final bool isIncoming;
  final Map<String, dynamic>? initialOffer;

  const CallScreen({
    super.key,
    required this.userId,
    required this.targetUserId,
    this.isVideo = true,
    this.isIncoming = false,
    this.initialOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late WebRTCService _webrtcService;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  String _status = 'جاري الاتصال...';
  Map<String, dynamic>? _targetData;
  StreamSubscription? _signalingSubscription;
  bool _isInitialized = false;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _loadTargetData();
    _initRenderers();
  }

  void _loadTargetData() async {
    final data = await ApiService.getProfile(widget.targetUserId);
    if (mounted) setState(() => _targetData = data);
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      _webrtcService = WebRTCService(
        socketService: SocketService(),
        onRemoteStream: (stream) {
          if (mounted) {
            setState(() {
              _remoteRenderer.srcObject = stream;
              _status = 'متصل';
            });
          }
        },
        onConnectionStateChange: (state) {
          if (mounted) setState(() => _status = state);
        },
      );
      _isInitialized = true;

      _signalingSubscription = SocketService().signalingStream.listen((data) {
        if (data['senderId'] != widget.targetUserId) return;

        switch (data['type']) {
          case 'answer':
            _webrtcService.handleAnswer(data);
            break;
          case 'candidate':
            _webrtcService.handleCandidate(data);
            break;
          case 'hangup':
            _finishCall(sendHangup: false);
            break;
        }
      });

      await _webrtcService.openUserMedia(
        _localRenderer,
        _remoteRenderer,
        video: widget.isVideo,
      );

      if (widget.isIncoming && widget.initialOffer != null) {
        await _webrtcService.handleOffer(widget.initialOffer!);
      } else {
        await _webrtcService.call(widget.targetUserId, video: widget.isVideo);
      }
    } catch (e) {
      debugPrint('Call initialization failed: $e');
      if (_isInitialized) _webrtcService.close();
      if (mounted) {
        setState(() => _status = 'تعذر تشغيل الكاميرا أو الميكروفون');
      }
    }
  }

  @override
  void dispose() {
    _signalingSubscription?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    if (_isInitialized) _webrtcService.close();
    super.dispose();
  }

  void _endCall() {
    _finishCall(sendHangup: true);
  }

  void _finishCall({required bool sendHangup}) {
    if (_isEnding) return;
    _isEnding = true;
    if (_isInitialized) _webrtcService.close();
    if (sendHangup) {
      SocketService().sendSignaling(
        {'type': 'hangup', 'targetId': widget.targetUserId},
        isVideo: widget.isVideo,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video
          if (widget.isVideo)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          
          // Background if no video or remote not loaded
          if (!widget.isVideo || _remoteRenderer.srcObject == null)
            Positioned.fill(
              child: Container(
                color: colorScheme.surface.withValues(alpha: 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                      backgroundImage: _targetData?['profileImage'] != null ? NetworkImage(_targetData!['profileImage']) : null,
                      child: _targetData?['profileImage'] == null ? Text(
                        (widget.targetUserId[0]).toUpperCase(),
                        style: TextStyle(fontSize: 40, color: colorScheme.primary, fontWeight: FontWeight.bold),
                      ) : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _targetData?['name'] ?? widget.targetUserId,
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),

          // Local Video (Small Overlay)
          if (widget.isVideo)
            Positioned(
              top: 50,
              right: 20,
              width: 120,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      onTap: () {
                        setState(() => _isMuted = !_isMuted);
                        _webrtcService.toggleAudio(!_isMuted);
                      },
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.red : Colors.white24,
                    ),
                    if (widget.isVideo)
                      _buildControlButton(
                        onTap: () {
                          setState(() => _isCameraOff = !_isCameraOff);
                          _webrtcService.toggleVideo(!_isCameraOff);
                        },
                        icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                        color: _isCameraOff ? Colors.red : Colors.white24,
                      ),
                    _buildControlButton(
                      onTap: () {
                        setState(() => _isSpeakerOn = !_isSpeakerOn);
                        _webrtcService.toggleSpeaker(_isSpeakerOn);
                      },
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: Colors.white24,
                    ),
                    if (widget.isVideo)
                      _buildControlButton(
                        onTap: () => _webrtcService.switchCamera(),
                        icon: Icons.flip_camera_ios,
                        color: Colors.white24,
                      ),
                  ],
                ),
                const SizedBox(height: 30),
                FloatingActionButton.large(
                  onPressed: _endCall,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required VoidCallback onTap, required IconData icon, required Color color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
