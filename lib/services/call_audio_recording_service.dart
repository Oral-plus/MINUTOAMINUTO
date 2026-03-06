import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class CallAudioRecordingService {
  static AudioRecorder? _recorder;
  static String? _currentPath;
  static bool _isRecording = false;
  static bool get isRecording => _isRecording;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static const int _warmupBeforeCheckMs = 1200;  // Más tiempo para estabilizar
  static const int _amplitudeSamples = 5;  // Más muestras para verificación
  static const int _amplitudeGapMs = 250;
  static const double _invalidAmplitudeFloor = -159.0;
  static const int _maxStartRetriesPerProfile = 3;  // Más reintentos
  static const int _maxRecordingDurationMinutes = 90;  // Límite de grabación

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
        bitRate: 256000,  // Bitrate más alto para mejor calidad
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
        bitRate: 192000,
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
    // VoiceRecognition - funciona bien en Samsung
    _PerfilGrabacion(
      'voice_recognition_legacy_private',
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
          audioSource: AndroidAudioSource.voiceRecognition,
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
        bitRate: 192000,
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
    // Fallback con altavoz: VoiceRecognition primero (mejor para Samsung)
    _PerfilGrabacion(
      'voice_recognition_speaker_fallback',
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
          audioSource: AndroidAudioSource.voiceRecognition,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
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
        bitRate: 192000,
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
      // Verificar si ya estamos grabando
      if (_isRecording && _currentPath != null) {
        debugPrint('CallAudioRecordingService: ya grabando en $_currentPath');
        return _currentPath;
      }
      
      if (await _instance.isRecording()) {
        _isRecording = true;
        return _currentPath;
      }
      
      bool hasPerm = await _instance.hasPermission();
      if (!hasPerm) {
        await Permission.microphone.request();
        await Future.delayed(const Duration(milliseconds: 400));
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

      // Limpiar archivos temporales antiguos (más de 24 horas)
      await _cleanOldTempFiles(recDir);

      for (final perfil in _perfiles) {
        for (var attempt = 1; attempt <= _maxStartRetriesPerProfile; attempt++) {
          final filePath = _buildAttemptPath(recDir, perfil.nombre, attempt);
          try {
            await _safeStopRecorder();
            
            // Dar un pequeño delay entre intentos para que el sistema se estabilice
            if (attempt > 1) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
            
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
            _isRecording = true;
            debugPrint(
              'CallAudioRecordingService: grabando con ${perfil.nombre} (intento $attempt) -> $filePath',
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
      _isRecording = false;
      return null;
    } catch (e) {
      debugPrint('CallAudioRecordingService start error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Limpia archivos temporales de más de 24 horas para evitar acumulación
  static Future<void> _cleanOldTempFiles(Directory recDir) async {
    try {
      final now = DateTime.now();
      final files = await recDir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          // Eliminar archivos de más de 24 horas que sean pequeños (fallidos)
          if (age.inHours > 24 && stat.size < 10240) {
            try {
              await entity.delete();
              debugPrint('CallAudioRecordingService: eliminado archivo temporal antiguo: ${entity.path}');
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('CallAudioRecordingService _cleanOldTempFiles: $e');
    }
  }

  static Future<String?> stop() async {
    if (!_isAndroid) return null;
    final pathToReturn = _currentPath;
    
    // Marcar como no grabando inmediatamente
    _isRecording = false;
    
    try {
      String? candidatePath = pathToReturn;
      
      // Dar un momento para que el buffer se vacíe antes de detener
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (await _instance.isRecording()) {
        try {
          final path = await _instance.stop();
          if (path != null && path.isNotEmpty) {
            candidatePath = path;
          }
        } catch (e) {
          debugPrint('CallAudioRecordingService: error al detener grabador: $e');
          // Intentar forzar la parada
          try {
            await _instance.cancel();
          } catch (_) {}
        }
      }
      
      // Esperar un momento para que el archivo se escriba completamente
      await Future.delayed(const Duration(milliseconds: 500));
      
      final stabilizedPath = await _stabilizeRecordingPath(candidatePath);
      if (stabilizedPath != null) {
        debugPrint('CallAudioRecordingService: grabación guardada en $stabilizedPath');
        return stabilizedPath;
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
      if (!await source.exists()) {
        debugPrint('CallAudioRecordingService: archivo no existe: $path');
        return null;
      }

      var size = await source.length();
      debugPrint('CallAudioRecordingService: tamaño inicial del archivo: $size bytes');
      
      // Esperar más tiempo si el archivo está vacío o muy pequeño
      if (size <= 1024) {
        for (var wait = 0; wait < 6 && size <= 1024; wait++) {
          await Future.delayed(Duration(milliseconds: 400 * (wait + 1)));
          if (!await source.exists()) {
            debugPrint('CallAudioRecordingService: archivo desapareció durante espera');
            return null;
          }
          size = await source.length();
          debugPrint('CallAudioRecordingService: tamaño después de espera ${wait + 1}: $size bytes');
        }
      }
      
      // Archivo demasiado pequeño, probablemente corrupto
      if (size <= 512) {
        debugPrint('CallAudioRecordingService: archivo muy pequeño ($size bytes), descartando');
        try {
          await source.delete();
        } catch (_) {}
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final recDir = Directory('${dir.path}/call_recordings');
      if (!await recDir.exists()) {
        await recDir.create(recursive: true);
      }

      final normalizedSourceDir = source.parent.path.replaceAll('\\', '/');
      final normalizedTargetDir = recDir.path.replaceAll('\\', '/');
      if (normalizedSourceDir == normalizedTargetDir) {
        debugPrint('CallAudioRecordingService: archivo ya en directorio correcto: ${source.path} ($size bytes)');
        return source.path;
      }

      // Determinar extensión correcta
      final ext = source.path.toLowerCase().endsWith('.m4a') 
          ? '.m4a' 
          : source.path.toLowerCase().endsWith('.wav')
              ? '.wav'
              : '.aac';
      final targetPath =
          '${recDir.path}/call_${DateTime.now().millisecondsSinceEpoch}$ext';
      final copied = await source.copy(targetPath);
      debugPrint('CallAudioRecordingService: archivo copiado a $targetPath ($size bytes)');
      
      // Eliminar archivo original después de copiar
      try {
        await source.delete();
      } catch (_) {}
      
      return copied.path;
    } catch (e) {
      debugPrint('CallAudioRecordingService stabilize error: $e');
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
