import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'media_picker_service.dart';

/// Records audio messages and returns them as media files ready for upload.
class AudioRecordingService {
  AudioRecordingService._();

  static final AudioRecordingService instance = AudioRecordingService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _activeRecordingPath;
  bool _isRecording = false;

  // Web-only: collects streaming audio chunks
  StreamSubscription<Uint8List>? _webStreamSub;
  List<Uint8List> _webChunks = [];
  Completer<List<Uint8List>>? _webCompleter;

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    if (kIsWeb) {
      _webChunks = [];
      _webCompleter = Completer<List<Uint8List>>();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );
      _webStreamSub = stream.listen(
        (chunk) => _webChunks.add(chunk),
        onDone: () => _webCompleter?.complete(_webChunks),
        onError: (e) => _webCompleter?.completeError(e),
        cancelOnError: false,
      );
      _isRecording = true;
    } else {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      final filePath = path.join(tempDir.path, fileName);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );
      _activeRecordingPath = filePath;
      _isRecording = true;
    }
  }

  Future<PickedMediaFile> stopRecording() async {
    if (!_isRecording) {
      throw Exception('No active audio recording');
    }

    _isRecording = false;

    if (kIsWeb) {
      // Stop recorder — triggers final onDone on the stream
      await _recorder.stop();
      final chunks = await _webCompleter!.future;
      await _webStreamSub?.cancel();
      _webStreamSub = null;
      _webCompleter = null;

      final bytes = Uint8List.fromList(chunks.expand((c) => c).toList());
      _webChunks = [];

      if (bytes.isEmpty) {
        throw Exception('Recorded audio is empty');
      }

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      return PickedMediaFile(
        name: fileName,
        path: '',
        bytes: bytes,
        mimeType: 'audio/wav',
        sizeBytes: bytes.length,
      );
    } else {
      final stoppedPath = await _recorder.stop();
      final resolvedPath = stoppedPath ?? _activeRecordingPath;
      _activeRecordingPath = null;

      if (resolvedPath == null) {
        throw Exception('Recorder returned no file path');
      }

      // dart:io is safe here — this branch only runs on native platforms
      // ignore: avoid_dynamic_calls
      final fileBytes = await File(resolvedPath).readAsBytes();
      final fileName = path.basename(resolvedPath);

      return PickedMediaFile(
        name: fileName,
        path: resolvedPath,
        bytes: fileBytes,
        mimeType: 'audio/wav',
        sizeBytes: fileBytes.length,
      );
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    await _recorder.stop();
    if (kIsWeb) {
      await _webStreamSub?.cancel();
      _webStreamSub = null;
      _webCompleter = null;
      _webChunks = [];
    } else {
      _activeRecordingPath = null;
    }
  }
}
