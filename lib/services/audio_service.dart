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

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> startRecording() async {
    if (!_isRecorderInitialized) await _initRecorder();
    
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    
    await _recorder.startRecorder(
      toFile: _currentPath,
      codec: Codec.aacADTS,
    );
  }

  Future<String?> stopRecording() async {
    if (!_isRecorderInitialized) return null;
    await _recorder.stopRecorder();
    return _currentPath;
  }

  Future<void> playAudio(String path) async {
    if (await File(path).exists()) {
      await _audioPlayer.play(DeviceFileSource(path));
    }
  }

  void dispose() {
    if (_recorder.isRecording) {
      _recorder.stopRecorder();
    }
    _recorder.closeRecorder();
    _audioPlayer.dispose();
  }
}
