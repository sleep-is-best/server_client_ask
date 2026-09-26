import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final _audioPlayer = AudioPlayer();
  String? _currentPath;
  bool _isRecorderInitialized = false;

  // فحص هل التسجيل جاري حالياً
  bool get isRecording => _recorder.isRecording;

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> startRecording() async {
    try {
      if (!_isRecorderInitialized) await _initRecorder();
      
      final dir = await getTemporaryDirectory();
      _currentPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      await _recorder.startRecorder(
        toFile: _currentPath,
        codec: Codec.aacADTS,
        bitRate: 16000,
        sampleRate: 16000,
      );
      print("🎙️ Recording started");
    } catch (e) {
      print("❌ Start recording error: $e");
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecorderInitialized || !_recorder.isRecording) return null;
      await _recorder.stopRecorder();
      print("🎙️ Recording stopped");
      return _currentPath;
    } catch (e) {
      print("❌ Stop recording error: $e");
      return null;
    }
  }

  Future<void> playAudio(String path) async {
    try {
      if (await File(path).exists()) {
        await _audioPlayer.play(DeviceFileSource(path));
      }
    } catch (e) {
      print("❌ Play audio error: $e");
    }
  }

  void dispose() {
    try {
      if (_recorder.isRecording) {
        _recorder.stopRecorder();
      }
      _recorder.closeRecorder();
      _audioPlayer.dispose();
    } catch (e) {
      print("❌ AudioService dispose error: $e");
    }
  }
}
