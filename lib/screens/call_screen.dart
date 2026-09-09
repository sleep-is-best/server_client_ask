import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import '../config.dart';
import '../widgets/user_avatar.dart';
import '../services/notification_service.dart';

enum CallState { idle, calling, ringing, connecting, connected, ended, failed }

class CallScreen extends StatefulWidget {
  final String userId;
  final String targetUserId;
  final String targetUserName;
  final String? targetUserImage;
  final bool isVideo;
  final bool isIncoming;
  final Map<String, dynamic>? initialOffer;

  const CallScreen({
    super.key,
    required this.userId,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserImage,
    required this.isVideo,
    this.isIncoming = false,
    this.initialOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final SocketService _socketService = SocketService();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  CallState _callState = CallState.idle;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  
  StreamSubscription? _signalingSubscription;
  Timer? _callTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _startCallProcess();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _startCallProcess() async {
    setState(() => _callState = widget.isIncoming ? CallState.ringing : CallState.calling);
    
    _signalingSubscription = _socketService.signalingStream.listen(_handleSignaling);

    await _setupPeerConnection();
    
    if (widget.isIncoming && widget.initialOffer != null) {
      // Wait for user to accept
    } else {
      await _makeOffer();
      _startTimeoutTimer();
    }
  }

  void _startTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_callState == CallState.calling || _callState == CallState.ringing) {
        _endCall(reason: 'لا يوجد رد');
      }
    });
  }

  Future<void> _setupPeerConnection() async {
    _peerConnection = await createPeerConnection(AppConfig.iceServers);

    _peerConnection!.onIceCandidate = (candidate) {
      _socketService.sendSignaling({
        'targetId': widget.targetUserId,
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('WebRTC Connection State: $state');
      if (mounted) {
        setState(() {
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _callState = CallState.connected;
            _callTimeoutTimer?.cancel();
          } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
              state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
            _callState = CallState.failed;
            _tryIceRestart();
          }
        });
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
        if (mounted) setState(() {});
      }
    };

    // Capture Local Media
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': widget.isVideo ? {
        'facingMode': _isFrontCamera ? 'user' : 'environment',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 20}
      } : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer.srcObject = _localStream;
      
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error getting user media: $e');
      _endCall(reason: 'فشل الوصول للكاميرا أو الميكروفون');
    }
  }

  void _tryIceRestart() async {
    if (_peerConnection == null || _callState == CallState.ended) return;
    
    debugPrint('Attempting ICE Restart...');
    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer({'iceRestart': true});
      await _peerConnection!.setLocalDescription(offer);

      _socketService.sendSignaling({
        'targetId': widget.targetUserId,
        'type': 'offer',
        'sdp': offer.sdp,
        'isVideo': widget.isVideo,
        'callerName': 'مستخدم',
      });
    } catch (e) {
      debugPrint('ICE Restart failed: $e');
    }
  }

  Future<void> _makeOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socketService.sendSignaling({
      'targetId': widget.targetUserId,
      'type': 'offer',
      'sdp': offer.sdp,
      'isVideo': widget.isVideo,
      'callerName': 'مستخدم', // ويمكن جلب الاسم الحقيقي
    });
  }

  void _handleSignaling(Map<String, dynamic> data) async {
    if (data['senderId'] != widget.targetUserId) return;

    final type = data['type'];
    switch (type) {
      case 'answer':
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
        setState(() => _callState = CallState.connecting);
        break;
      case 'candidate':
        final candidateData = data['candidate'];
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          ),
        );
        break;
      case 'reject':
        _endCall(reason: 'تم رفض المكالمة');
        break;
      case 'end':
        _endCall();
        break;
    }
  }

  void _acceptCall() async {
    if (widget.initialOffer == null) return;
    
    NotificationService.cancelNotification(999);
    setState(() => _callState = CallState.connecting);
    _callTimeoutTimer?.cancel();

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(widget.initialOffer!['sdp'], 'offer'),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socketService.sendSignaling({
      'targetId': widget.targetUserId,
      'type': 'answer',
      'sdp': answer.sdp,
    });
  }

  void _rejectCall() {
    NotificationService.cancelNotification(999);
    _socketService.sendSignaling({
      'targetId': widget.targetUserId,
      'type': 'reject',
    });
    _endCall();
  }

  void _endCall({String? reason}) {
    if (_callState == CallState.ended) return;

    NotificationService.cancelNotification(999);
    _socketService.sendSignaling({
      'targetId': widget.targetUserId,
      'type': 'end',
    });

    setState(() => _callState = CallState.ended);
    
    if (reason != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _toggleMute() {
    if (_localStream == null) return;
    final audioTrack = _localStream!.getAudioTracks()[0];
    _isMuted = !_isMuted;
    audioTrack.enabled = !_isMuted;
    setState(() {});
  }

  void _toggleVideo() {
    if (!widget.isVideo || _localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks()[0];
    _isVideoOff = !_isVideoOff;
    videoTrack.enabled = !_isVideoOff;
    setState(() {});
  }

  void _switchCamera() async {
    if (!widget.isVideo || _localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks()[0];
    await Helper.switchCamera(videoTrack);
    _isFrontCamera = !_isFrontCamera;
    setState(() {});
  }

  void _toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
    setState(() {});
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    _signalingSubscription?.cancel();
    _localStream?.dispose();
    _peerConnection?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          
          // Local Video (Overlay)
          if (widget.isVideo)
            Positioned(
              top: 50,
              right: 20,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black54,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: _isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // User Info (when audio only or calling)
          if (!widget.isVideo || _callState != CallState.connected)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UserAvatar(
                    name: widget.targetUserName,
                    imageUrl: widget.targetUserImage,
                    radius: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.targetUserName,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusText(),
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),

          // Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (_callState) {
      case CallState.calling: return 'جاري الاتصال...';
      case CallState.ringing: return 'يرن...';
      case CallState.connecting: return 'جاري الربط...';
      case CallState.connected: return 'متصل';
      case CallState.ended: return 'انتهت المكالمة';
      case CallState.failed: return 'فشل الاتصال';
      default: return '';
    }
  }

  Widget _buildControls() {
    if (_callState == CallState.ringing && widget.isIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            onPressed: _rejectCall,
            icon: Icons.call_end,
            color: Colors.red,
            label: 'رفض',
          ),
          _buildControlButton(
            onPressed: _acceptCall,
            icon: Icons.call,
            color: Colors.green,
            label: 'قبول',
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              onPressed: _toggleMute,
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              color: _isMuted ? Colors.white24 : Colors.white10,
              iconColor: Colors.white,
            ),
            if (widget.isVideo) ...[
              _buildControlButton(
                onPressed: _toggleVideo,
                icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                color: _isVideoOff ? Colors.white24 : Colors.white10,
                iconColor: Colors.white,
              ),
              _buildControlButton(
                onPressed: _switchCamera,
                icon: Icons.cameraswitch,
                color: Colors.white10,
                iconColor: Colors.white,
              ),
            ],
            _buildControlButton(
              onPressed: _toggleSpeaker,
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              color: _isSpeakerOn ? Colors.white24 : Colors.white10,
              iconColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildControlButton(
          onPressed: () => _endCall(),
          icon: Icons.call_end,
          color: Colors.red,
          size: 70,
          iconSize: 32,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    double size = 60,
    double iconSize = 28,
    String? label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo')),
        ],
      ],
    );
  }
}
