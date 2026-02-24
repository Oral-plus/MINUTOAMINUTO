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
  static const List<_PerfilGrabacion> _perfiles = [
    // Perfil prioritario para intentar capturar canal de llamada completo en equipos compatibles.
    _PerfilGrabacion(
      'voice_call_legacy',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          audioSource: AndroidAudioSource.voiceCall,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: false,
        ),
      ),
    ),
    // Alternativa moderna en modo comunicación.
    _PerfilGrabacion(
      'voice_communication',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: true,
        ),
      ),
    ),
    // Último fallback acústico para equipos donde Android bloquea canal remoto.
    _PerfilGrabacion(
      'mic_speakerphone',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
          manageBluetooth: false,
        ),
      ),
    ),
  ];

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

      for (final perfil in _perfiles) {
        try {
          await _instance.start(perfil.config, path: filePath);
          await Future.delayed(const Duration(milliseconds: 220));
          if (await _instance.isRecording()) {
            _currentPath = filePath;
            debugPrint('CallAudioRecordingService: perfil activo ${perfil.nombre}');
            return _currentPath;
          }
        } catch (e) {
          debugPrint(
            'CallAudioRecordingService start perfil ${perfil.nombre} error: $e',
          );
        } finally {
          if (!await _instance.isRecording()) {
            try {
              await _instance.stop();
            } catch (_) {}
          }
        }
      }

      debugPrint('CallAudioRecordingService: no se pudo iniciar ningún perfil');
      return null;
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

class _PerfilGrabacion {
  final String nombre;
  final RecordConfig config;

  const _PerfilGrabacion(this.nombre, this.config);
}
