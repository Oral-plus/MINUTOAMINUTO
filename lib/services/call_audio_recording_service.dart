import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Grabación de audio durante la llamada. Muy importante: robusto para no cerrar la app.
class CallAudioRecordingService {
  static AudioRecorder? _recorder;
  static String? _currentPath;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static AudioRecorder get _instance => _recorder ??= AudioRecorder();

  /// Inicia la grabación. Pequeña pausa si hace falta permiso.
  static Future<String?> start() async {
    if (!_isAndroid) return null;
    try {
      if (await _instance.isRecording()) return _currentPath;
      bool hasPerm = await _instance.hasPermission();
      if (!hasPerm) {
        await Permission.microphone.request();
        await Future.delayed(const Duration(milliseconds: 300));
        hasPerm = await _instance.hasPermission();
      }
      if (!hasPerm) {
        debugPrint('CallAudioRecordingService: sin permiso de micrófono');
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final recDir = Directory('${dir.path}/call_recordings');
      if (!await recDir.exists()) {
        await recDir.create(recursive: true);
      }

      final filePath =
          '${recDir.path}/call_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _instance.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
          noiseSuppress: true,
          echoCancel: true,
        ),
        path: filePath,
      );
      _currentPath = filePath;
      return _currentPath;
    } catch (e) {
      debugPrint('CallAudioRecordingService start error: $e');
      return null;
    }
  }

  /// Detiene la grabación. Siempre devuelve la ruta si había grabación (aunque falle stop).
  static Future<String?> stop() async {
    if (!_isAndroid) return null;
    final pathToReturn = _currentPath;
    try {
      if (!await _instance.isRecording()) return pathToReturn;
      final path = await _instance.stop();
      if (path != null && path.isNotEmpty) {
        _currentPath = path;
        return _currentPath;
      }
      return pathToReturn;
    } catch (e) {
      debugPrint('CallAudioRecordingService stop error: $e');
      return pathToReturn;
    } finally {
      _currentPath = null;
    }
  }
}
