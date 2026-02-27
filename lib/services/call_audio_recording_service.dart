import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class CallAudioRecordingService {
  static AudioRecorder? _recorder;
  static String? _currentPath;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static const int _warmupBeforeCheckMs = 900;
  static const int _amplitudeSamples = 4;
  static const int _amplitudeGapMs = 220;
  static const double _invalidAmplitudeFloor = -159.0;
  static const int _maxStartRetriesPerProfile = 2;

  static AudioRecorder get _instance => _recorder ??= AudioRecorder();

  static const _channel = MethodChannel('minutoaminuto/audio_route');

  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<bool> isAccessibilityServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityServiceRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  static const List<_PerfilGrabacion> _perfiles = [
    // Modo privado (sin altavoz): intenta capturar la llamada sin forzar speaker.
    _PerfilGrabacion(
      'voice_call_legacy_private',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 192000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
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
    // VoiceCommunication con MediaRecorder legacy en privado.
    _PerfilGrabacion(
      'voice_communication_legacy_private',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: false,
        ),
      ),
    ),
    // VoiceCommunication sin altavoz.
    _PerfilGrabacion(
      'voice_communication_private',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 192000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: false,
        ),
      ),
    ),
    // VoiceRecognition sin altavoz.
    _PerfilGrabacion(
      'voice_recognition_private',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 192000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: false,
        ),
      ),
    ),
    // Micrófono legacy privado: fallback fuerte de compatibilidad.
    _PerfilGrabacion(
      'mic_legacy_private',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: false,
        ),
      ),
      forceKeepIfRecording: true,
    ),
    // Micrófono sin altavoz (fallback para garantizar guardado).
    _PerfilGrabacion(
      'mic_private',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 192000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: false,
          manageBluetooth: false,
        ),
      ),
      forceKeepIfRecording: true,
    ),
    // Fallback final: en algunos equipos solo entra señal utilizable con speaker ON.
    _PerfilGrabacion(
      'voice_call_legacy_speaker_fallback',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          audioSource: AndroidAudioSource.voiceCall,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
          manageBluetooth: false,
        ),
      ),
      forceKeepIfRecording: true,
    ),
    _PerfilGrabacion(
      'mic_legacy_speaker_fallback',
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
          manageBluetooth: false,
        ),
      ),
      forceKeepIfRecording: true,
    ),
  ];

  static String _buildAttemptPath(Directory recDir, String perfil, int attempt) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = perfil.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return '${recDir.path}/call_${ts}_${safe}_$attempt.m4a';
  }

  static Future<void> _safeStopRecorder() async {
    try {
      if (await _instance.isRecording()) {
        await _instance.stop();
      }
    } catch (_) {}
  }

  static Future<bool> _hasUsableSignal() async {
    try {
      double bestCurrent = -160.0;
      double bestMax = -160.0;
      for (var i = 0; i < _amplitudeSamples; i++) {
        final amp = await _instance.getAmplitude();
        if (amp.current > bestCurrent) bestCurrent = amp.current;
        if (amp.max > bestMax) bestMax = amp.max;
        if (bestCurrent > _invalidAmplitudeFloor || bestMax > _invalidAmplitudeFloor) {
          return true;
        }
        if (i < _amplitudeSamples - 1) {
          await Future.delayed(const Duration(milliseconds: _amplitudeGapMs));
        }
      }
      return false;
    } catch (_) {
      // Si el dispositivo no soporta lectura de amplitud, no bloqueamos el inicio.
      return true;
    }
  }

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

      for (final perfil in _perfiles) {
        for (var attempt = 1; attempt <= _maxStartRetriesPerProfile; attempt++) {
          final filePath = _buildAttemptPath(recDir, perfil.nombre, attempt);
          try {
            await _safeStopRecorder();
            await _instance.start(perfil.config, path: filePath);
            await Future.delayed(const Duration(milliseconds: _warmupBeforeCheckMs));
            final isRec = await _instance.isRecording();
            if (!isRec) {
              debugPrint('CallAudioRecordingService: ${perfil.nombre} intento $attempt no inició');
              continue;
            }
            final hasSignal = await _hasUsableSignal();
            if (!hasSignal && !perfil.forceKeepIfRecording) {
              debugPrint(
                'CallAudioRecordingService: ${perfil.nombre} intento $attempt sin señal utilizable',
              );
              await _safeStopRecorder();
              continue;
            }
            _currentPath = filePath;
            debugPrint(
              'CallAudioRecordingService: grabando con ${perfil.nombre} (intento $attempt)',
            );
            return _currentPath;
          } catch (e) {
            debugPrint(
              'CallAudioRecordingService perfil ${perfil.nombre} intento $attempt: $e',
            );
            await _safeStopRecorder();
          }
        }
      }

      debugPrint('CallAudioRecordingService: ningún perfil funcionó');
      return null;
    } catch (e) {
      debugPrint('CallAudioRecordingService start error: $e');
      return null;
    }
  }

  static Future<String?> stop() async {
    if (!_isAndroid) return null;
    final pathToReturn = _currentPath;
    try {
      String? candidatePath = pathToReturn;
      if (await _instance.isRecording()) {
        final path = await _instance.stop();
        if (path != null && path.isNotEmpty) {
          candidatePath = path;
        }
      }
      final stabilizedPath = await _stabilizeRecordingPath(candidatePath);
      if (stabilizedPath != null) {
        _currentPath = stabilizedPath;
        return _currentPath;
      }
      return candidatePath;
    } catch (e) {
      debugPrint('CallAudioRecordingService stop error: $e');
      return pathToReturn;
    } finally {
      _currentPath = null;
    }
  }

  static Future<String?> _stabilizeRecordingPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final source = File(path);
      if (!await source.exists()) return null;

      var size = await source.length();
      if (size <= 0) {
        for (var wait = 0; wait < 4 && size <= 0; wait++) {
          await Future.delayed(Duration(milliseconds: 300 * (wait + 1)));
          if (!await source.exists()) return null;
          size = await source.length();
        }
      }
      if (size <= 0) return null;

      final dir = await getApplicationDocumentsDirectory();
      final recDir = Directory('${dir.path}/call_recordings');
      if (!await recDir.exists()) {
        await recDir.create(recursive: true);
      }

      final normalizedSourceDir = source.parent.path.replaceAll('\\', '/');
      final normalizedTargetDir = recDir.path.replaceAll('\\', '/');
      if (normalizedSourceDir == normalizedTargetDir) {
        return source.path;
      }

      final ext = source.path.toLowerCase().endsWith('.m4a') ? '.m4a' : '.aac';
      final targetPath =
          '${recDir.path}/call_${DateTime.now().millisecondsSinceEpoch}$ext';
      final copied = await source.copy(targetPath);
      return copied.path;
    } catch (e) {
      debugPrint('CallAudioRecordingService stabilize: $e');
      return path;
    }
  }
}

class _PerfilGrabacion {
  final String nombre;
  final RecordConfig config;
  final bool forceKeepIfRecording;
  const _PerfilGrabacion(
    this.nombre,
    this.config, {
    this.forceKeepIfRecording = false,
  });
}
