import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  bool get isRecording => _isRecording;

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording({required Function(String) onAudioChunk}) async {
    if (_isRecording) return;

    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    try {
      // Check if the recorder is supported
      if (await _recorder.hasPermission()) {
        // Start streaming audio
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        _isRecording = true;

        // 🎤 Audio streaming started successfully
        print('🎤 Audio recording started: 16kHz, PCM16, Mono');
        int chunkCount = 0;

        _audioStreamSubscription = stream.listen(
          (audioData) {
            chunkCount++;
            // Convert audio data to base64
            final base64Audio = base64Encode(audioData);

            // 📊 Log audio chunk info (every 10 chunks to avoid spam)
            if (chunkCount % 10 == 1) {
              print(
                '🎤 Audio chunk #$chunkCount: ${audioData.length} bytes → ${base64Audio.length} chars (base64)',
              );
            }

            onAudioChunk(base64Audio);
          },
          onError: (error) {
            print('Audio stream error: $error');
            stopRecording();
          },
        );
      }
    } catch (e) {
      print('Failed to start recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _audioStreamSubscription?.cancel();
      await _recorder.stop();
      _isRecording = false;
      print('🛑 Audio recording stopped');
    } catch (e) {
      print('❌ Failed to stop recording: $e');
    }
  }

  void dispose() {
    stopRecording();
    _recorder.dispose();
  }
}



