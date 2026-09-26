import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';
import 'dart:async';
import '../config.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  final SocketService socketService;
  final Function(MediaStream) onRemoteStream;
  final Function(String)? onConnectionStateChange;

  final List<RTCIceCandidate> _remoteCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _disposed = false;
  bool _isVideoCall = true;

  WebRTCService({
    required this.socketService, 
    required this.onRemoteStream,
    this.onConnectionStateChange,
  });

  final Map<String, dynamic> _configuration = AppConfig.webRTCConfig;

  Future<void> openUserMedia(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo, {bool video = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video ? {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 30},
      } : false
    };

    try {
      if (localStream != null) {
        localStream!.getTracks().forEach((track) => track.stop());
        localStream = null;
      }
      
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localVideo.srcObject = localStream;
      
      if (_peerConnection != null) {
        for (final track in localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, localStream!);
        }
      }
      
      await Helper.setSpeakerphoneOn(true); 
      debugPrint("📸 Local media opened. Tracks: ${localStream!.getTracks().length}");
    } catch (e) {
      debugPrint("❌ Error opening media: $e");
      rethrow;
    }
  }

  void toggleSpeaker(bool isOn) {
    Helper.setSpeakerphoneOn(isOn);
  }

  Future<void> _createPeerConnection(String targetId) async {
    if (_disposed) return;
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onConnectionState = (state) {
      debugPrint("🔌 Connection State: ${state.name}");
      onConnectionStateChange?.call("CONN: ${state.name}");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (!_disposed) hangUp();
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (_disposed) return;
      if (candidate.candidate != null) {
        debugPrint("❄️ Sending ICE Candidate: ${candidate.sdpMid}");
        socketService.sendSignaling({
          'type': 'candidate',
          'candidate': candidate.toMap(),
          'targetId': targetId,
        }, isVideo: _isVideoCall);
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint("✅ Received remote track: ${event.track.kind}");
      
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        event.track.enabled = true;
        onRemoteStream(remoteStream!);
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint("❄️ ICE State: ${state.name}");
      onConnectionStateChange?.call("ICE: ${state.name}");
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _peerConnection!.restartIce();
      }
    };

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        debugPrint("📤 Adding local track: ${track.kind}");
        await _peerConnection!.addTrack(track, localStream!);
      }
    }
  }

  Future<void> call(String targetUserId, {bool video = true}) async {
    try {
      if (_disposed) return;
      _isVideoCall = video;
      _remoteDescriptionSet = false;
      _remoteCandidates.clear();
      
      await _createPeerConnection(targetUserId);

      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': video,
      });
      
      await _peerConnection!.setLocalDescription(offer);
      socketService.sendSignaling({
        'type': 'offer',
        'sdp': offer.toMap(),
        'targetId': targetUserId,
        'video': video,
      }, isVideo: video);
    } catch (e) {
      debugPrint("❌ Call error: $e");
    }
  }

  Future<void> handleOffer(Map<String, dynamic> data) async {
    if (_disposed) return;
    final senderId = data['senderId']?.toString() ?? 'unknown';
    final video = data['video'] == true;
    _isVideoCall = video;
    
    await _createPeerConnection(senderId);

    final sdpData = data['sdp'];
    if (sdpData is Map) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdpData['sdp'], sdpData['type'])
      );
    }
    
    _remoteDescriptionSet = true;
    for (var c in _remoteCandidates) {
      await _peerConnection!.addCandidate(c);
    }
    _remoteCandidates.clear();

    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });
    
    await _peerConnection!.setLocalDescription(answer);
    socketService.sendSignaling({
      'type': 'answer',
      'sdp': answer.toMap(),
      'targetId': senderId,
      'video': video,
    }, isVideo: video);
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    if (_disposed || _peerConnection == null) return;
    final sdpData = data['sdp'];
    if (sdpData is Map) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdpData['sdp'], sdpData['type'])
      );
      _remoteDescriptionSet = true;
      for (var c in _remoteCandidates) {
        await _peerConnection!.addCandidate(c);
      }
      _remoteCandidates.clear();
    }
  }

  Future<void> handleCandidate(Map<String, dynamic> data) async {
    if (_disposed) return;
    final candidateData = data['candidate'];
    if (candidateData is! Map) return;
    
    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );
    
    if (_peerConnection != null && _remoteDescriptionSet) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _remoteCandidates.add(candidate);
    }
  }

  void hangUp() {
    debugPrint("📱 Hanging up and disposing WebRTC resources...");
    
    // Stop and dispose local tracks
    localStream?.getTracks().forEach((track) {
      track.stop();
    });
    
    // Stop and dispose remote tracks
    remoteStream?.getTracks().forEach((track) {
      track.stop();
    });

    _peerConnection?.dispose();
    _peerConnection = null;
    localStream = null;
    remoteStream = null;
    _remoteCandidates.clear();
    _remoteDescriptionSet = false;
  }

  void toggleAudio(bool enabled) => localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  void toggleVideo(bool enabled) => localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  Future<void> switchCamera() async => (localStream != null) ? await Helper.switchCamera(localStream!.getVideoTracks()[0]) : null;

  void close() {
    _disposed = true;
    hangUp();
  }
}
