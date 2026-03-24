import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/registro_llamada.dart';
import '../utils/phone_utils.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../models/tipo_llamada.dart';
import '../models/nivel_cargo.dart';
import 'data_service.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart' show AppKeys;
import '../screens/mis_llamadas_screen.dart';
import 'ip_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'location_service.dart';
import 'call_saving_progress_service.dart';
import 'post_call_notification_service.dart';
import 'call_diagnostic_service.dart';
import 'transcription_manager.dart';

@pragma('vm:entry-point')
void callMonitorForegroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(_CallMonitorTaskHandler());
}

class _CallMonitorTaskHandler extends TaskHandler {
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await CallMonitorService.runBackgroundTick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_busy) return;
    _busy = true;
    runZonedGuarded(() {
      CallMonitorService.runBackgroundTick().whenComplete(() {
        _busy = false;
      });
    }, (error, stack) {
      debugPrint('CallMonitor TaskHandler Error: $error\n$stack');
      _busy = false;
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// Monitor de llamadas para Android: registra llamadas (y opcionalmente audio) en segundo plano.
class CallMonitorService {
  static const _keyEnabled = 'call_monitor_enabled';
  static const _keyLastProcessedId = 'call_monitor_last_id';
  static const _keyLastRegistroId = 'call_monitor_last_registro_id';
  static const keyCumplioMetaPending = 'cumplioMeta_pending_id';
  static const _keyNativeSignal = 'native_call_state_signal';
  static const _keyNativeSignalTs = 'native_call_state_ts';
  static const _keyNativeSignalNumber = 'native_call_state_number';
  static const _keyProcessingEnd = 'call_monitor_processing_end';
  static const EventChannel _nativeCallStateChannel = EventChannel(
    'minutoaminuto/call_state',
  );
  static const MethodChannel _audioRouteChannel = MethodChannel(
    'minutoaminuto/audio_route',
  );
  static const MethodChannel _audioAmplitudeChannel = MethodChannel(
    'minutoaminuto/audio_amplitude',
  );

  static final ValueNotifier<bool> isInCallNotifier = ValueNotifier(false);
  static final ValueNotifier<double> callAmplitudeNotifier = ValueNotifier(0.0);
  static Timer? _amplitudeTimer;

  static const int _delayAfterNotificationMs = 600;
  static const int _delayAfterPhoneMs = 600;
  static const int _delayAfterMicMs = 500;
  static const int _delayBeforeStartServiceSec = 1;
  static const int _pollIntervalWithListenerSec = 2;
  static const int _taskRepeatMs = 1500;
  static const int _watchdogIntervalSec = 15;

  static StreamSubscription? _callStateSub;
  static bool _isInCall = false;
  static bool _isStarting = false;
  static bool _procesandoFin = false;
  static Timer? _pollTimer;
  static Timer? _serviceWatchdogTimer;
  static bool _isManualRecording = false;
  static bool get isManualRecording => _isManualRecording;
  static int _lastHandledNativeSignalTs = 0;
  static int _lastHandledEndTs = 0;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static bool _guardAndroid() {
    if (_isAndroid) return true;
    return false;
  }

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!_guardAndroid()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, enabled);
    } catch (e) {
      debugPrint('CallMonitor setEnabled: $e');
    }
  }

  static Future<T?> _runSafe<T>(Future<T> Function() fn) async {
    try {
      final result = runZonedGuarded<Future<T?>>(
        () async {
          try {
            return await fn();
          } catch (e, st) {
            debugPrint('CallMonitor _runSafe inner: $e $st');
            return null;
          }
        },
        (error, stack) {
          debugPrint('CallMonitor safe zone: $error\n$stack');
        },
      );
      return await (result ?? Future<T?>.value(null));
    } catch (e, st) {
      debugPrint('CallMonitor _runSafe: $e\n$st');
      return null;
    }
  }

  static Future<bool> requestPermissions() async {
    if (!_guardAndroid()) return false;
    final ok = await _runSafe<bool>(() async {
      // Request notification permission
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
        await Future.delayed(const Duration(milliseconds: _delayAfterNotificationMs));
      }

      // Request phone permission
      final phone = await Permission.phone.request();
      if (!phone.isGranted) return false;
      await Future.delayed(const Duration(milliseconds: _delayAfterPhoneMs));

      // Request microphone permission
      await Permission.microphone.request();
      await Future.delayed(const Duration(milliseconds: _delayAfterMicMs));

      // Solicitar permisos drásticos de almacenamiento (con timeout para evitar cuelgues)
      try {
        if (!await Permission.manageExternalStorage.isGranted) {
          await Permission.manageExternalStorage.request().timeout(const Duration(seconds: 15));
        }
      } catch (e) {
        debugPrint('CallMonitor manageExternalStorage error/timeout: $e');
      }
      
      try {
        if (!await Permission.storage.isGranted) {
          await Permission.storage.request().timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('CallMonitor storage error: $e');
      }

      // Request location permission
      try {
        if (!await Permission.locationWhenInUse.isGranted) {
          await Permission.locationWhenInUse.request();
        }
      } catch (_) {}
      return await Permission.phone.isGranted;
    });
    return ok ?? false;
  }

  static Future<bool> hasPermissions() async {
    if (!_guardAndroid()) return false;
    try {
      final hasPhone = await Permission.phone.isGranted;
      final hasMic = await Permission.microphone.isGranted;
      final hasNotif = await Permission.notification.isGranted;
      // No requerir storage como obligatorio para no bloquear el inicio en celulares viejos
      return hasPhone && hasMic && hasNotif;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isServiceRunning() async {
    if (!_guardAndroid()) return false;
    try {
      _initForegroundTask();
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canDrawOverlays() async {
    if (!_guardAndroid()) return true;
    try {
      return await _audioRouteChannel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestOverlayPermission() async {
    if (!_guardAndroid()) return;
    try {
      await _audioRouteChannel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<bool> isActive() async {
    if (!_guardAndroid()) return false;
    final enabled = await isEnabled();
    if (!enabled) return false;
    return isServiceRunning();
  }

  static Future<void> requestPermissionsIfNeeded() async {
    if (!_guardAndroid()) return;
    await _runSafe(() async {
      try {
        if (!await Permission.notification.isGranted) {
          await Permission.notification.request();
          await Future.delayed(const Duration(milliseconds: _delayAfterNotificationMs));
        }
        if (!await Permission.phone.isGranted) {
          await Permission.phone.request();
          await Future.delayed(const Duration(milliseconds: _delayAfterPhoneMs));
        }
        if (!await Permission.microphone.isGranted) {
          await Permission.microphone.request();
          await Future.delayed(const Duration(milliseconds: _delayAfterMicMs));
        }
        // Request MANAGE_EXTERNAL_STORAGE and STORAGE if needed
        try {
          if (!await Permission.manageExternalStorage.isGranted) {
            await Permission.manageExternalStorage.request().timeout(const Duration(seconds: 15));
          }
        } catch (_) {}
        try {
          if (!await Permission.storage.isGranted) {
            await Permission.storage.request().timeout(const Duration(seconds: 5));
          }
        } catch (_) {}
        try {
          if (!await Permission.locationWhenInUse.isGranted) {
            await Permission.locationWhenInUse.request();
          }
        } catch (e) {
          debugPrint('CallMonitor requestPermissionsIfNeeded location: $e');
        }
      } catch (e) {
        debugPrint('CallMonitor requestPermissionsIfNeeded: $e');
      }
    });
  }

  static Future<bool> requestAllPermissions() async {
    if (!_guardAndroid()) return false;
    final ok = await _runSafe<bool>(() async {
      try {
        await Permission.notification.request();
        final phone = await Permission.phone.request();
        await Permission.microphone.request();
        try {
          if (!await Permission.manageExternalStorage.isGranted) {
            await Permission.manageExternalStorage.request().timeout(const Duration(seconds: 15));
          }
        } catch (_) {}
        try {
          if (!await Permission.storage.isGranted) {
            await Permission.storage.request().timeout(const Duration(seconds: 5));
          }
        } catch (_) {}
        if (!phone.isGranted) return false; // Return false if phone permission is not granted
        return true; // All permissions requested successfully
      } catch (e) {
        debugPrint('CallMonitor requestAllPermissions error: $e');
        return false;
      }
    });
    return ok ?? false;
  }

  static void initForegroundTaskEarly() {
    if (!_guardAndroid()) return;
    try {
      _initForegroundTask();
    } catch (_) {}
  }

  static Future<void> init() async {
    if (!_guardAndroid()) return;
    await _runSafe(() async {
      _isInCall = false;
      _procesandoFin = false;
      _lastHandledEndTs = 0;
      _lastHandledNativeSignalTs = 0;

      try {
        final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
        await prefs.setBool(_keyProcessingEnd, false);
      } catch (_) {}

      try {
        await PostCallNotificationService.init();
      } catch (e) {
        debugPrint('PostCallNotification init: $e');
      }

      await _stopStaleRecordingIfIdle();

      final enabled = await isEnabled();
      if (!enabled) return;
      final hasPerms = await hasPermissions();
      if (!hasPerms) return;

      await _processPendingCallSaveIfNeeded();
      await _startMonitoring();
    });
  }

  static Future<void> _stopStaleRecordingIfIdle() async {
    if (!_isAndroid) return;
    try {
      await _audioRouteChannel.invokeMethod('stopStaleRecording');
    } catch (e) {
      debugPrint('CallMonitor _stopStaleRecordingIfIdle: $e (ignorado)');
    }
  }

  static Future<void> _processPendingCallSaveIfNeeded() async {
    if (_procesandoFin) return;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      await prefs.reload();
      final pending = prefs.getBool('native_pending_call_save') ?? false;
      if (!pending) return;

      debugPrint('CallMonitor: llamada pendiente de guardar detectada al arrancar');
      await prefs.setBool('native_pending_call_save', false);

      final signal = (prefs.getString(_keyNativeSignal) ?? '').toLowerCase();
      final number = prefs.getString(_keyNativeSignalNumber) ?? '';
      final ts     = prefs.getInt(_keyNativeSignalTs) ?? 0;

      if (signal == 'end' && ts > 0) {
        _lastHandledNativeSignalTs = ts;
        _lastHandledEndTs = ts * 1000;
        await Future.delayed(const Duration(seconds: 3));
        await _handleCallEnd(source: 'pending_save', number: number);
      }
    } catch (e) {
      debugPrint('CallMonitor _processPendingCallSaveIfNeeded: $e');
    }
  }

  static Future<void> start() async {
    if (!_guardAndroid()) return;
    if (_isStarting) return;
    _isStarting = true;
    try {
      bool hasPerms = await hasPermissions();
      if (!hasPerms) {
        await requestPermissionsIfNeeded();
        await Future.delayed(const Duration(milliseconds: 500));
        hasPerms = await hasPermissions();
      }
      if (!hasPerms) {
        debugPrint('CallMonitor: permisos denegados');
        _isStarting = false;
        return;
      }

      if (!await canDrawOverlays()) {
        await requestOverlayPermission();
      }

      await setEnabled(true);
      await _startMonitoring();
    } catch (e, st) {
      debugPrint('CallMonitor start error: $e $st');
      try { await setEnabled(false); } catch (_) {}
    } finally {
      _isStarting = false;
    }
  }

  static Future<void> stop() async {
    if (!_guardAndroid()) return;
    _isManualRecording = false;
    await _runSafe(() async {
      try {
        await setEnabled(false);
        _pollTimer?.cancel();
        _pollTimer = null;
        await _callStateSub?.cancel();
        _callStateSub = null;
        _isInCall = false;
        _serviceWatchdogTimer?.cancel();
        _serviceWatchdogTimer = null;
      } catch (e) {
        debugPrint('CallMonitor stop cleanup: $e');
      }
      try {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
      } catch (e) {
        debugPrint('CallMonitor stop (service): $e');
      }
    });
  }

  static Future<void> _startMonitoring() async {
    try { FlutterForegroundTask.initCommunicationPort(); } catch (_) {}
    try { _initForegroundTask(); } catch (e) {
      debugPrint('CallMonitor initForegroundTask: $e');
      return;
    }

    await Future.delayed(const Duration(seconds: _delayBeforeStartServiceSec));
    if (!await isEnabled()) return;
    // Solicitar permiso de ubicación ANTES de iniciar el servicio en primer plano
    // Android 14+ exige que el permiso esté concedido antes de arrancar con foregroundServiceType=location
    try {
      if (!await Permission.locationWhenInUse.isGranted) {
        await Permission.locationWhenInUse.request();
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}
    final ok = await _ensureForegroundServiceRunning(forceNotificationRefresh: true);
    if (!ok) return;
    await startNativePhoneMonitor();
    _startServiceWatchdog();
    _startCallLogPolling();
    if (_callStateSub == null) {
      try { _listenToCallState(); } catch (_) {}
    }
    Future.delayed(const Duration(seconds: 3), () {
      runBackgroundTick().catchError((e) {
        debugPrint('CallMonitor first tick error: $e');
      });
    });
  }

  static Future<void> startNativePhoneMonitor() async {
    if (!_isAndroid) return;
    try {
      await _audioRouteChannel.invokeMethod('startPhoneStateMonitor');
    } catch (e) {
      debugPrint('CallMonitor startNativePhoneMonitor: $e');
    }
  }

  static void _startServiceWatchdog() {
    _serviceWatchdogTimer?.cancel();
    _serviceWatchdogTimer = Timer.periodic(
      const Duration(seconds: _watchdogIntervalSec),
      (_) async {
        await _runSafe(() async {
          if (!await isEnabled()) return;
          await _ensureForegroundServiceRunning();
        });
      },
    );
  }

  static Future<bool> _ensureForegroundServiceRunning({bool forceNotificationRefresh = false}) async {
    if (!_guardAndroid()) return false;
    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (!running) {
        final result = await FlutterForegroundTask.startService(
          serviceId: 1771,
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
          callback: callMonitorForegroundStartCallback,
        );
        return result is! ServiceRequestFailure;
      }
      if (forceNotificationRefresh) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
          callback: callMonitorForegroundStartCallback,
        );
      }
      return true;
    } catch (e) {
      debugPrint('CallMonitor ensureForegroundService error: $e');
      return false;
    }
  }

  static void _startCallLogPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: _pollIntervalWithListenerSec), (_) async {
      await _runSafe(() async {
        if (!await isEnabled()) return;
        await _consumeNativeCallSignal();
      });
    });
  }

  static Future<void> _consumeNativeCallSignal() async {
    if (_procesandoFin) return;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      await prefs.reload();
      final ts = prefs.getInt(_keyNativeSignalTs) ?? 0;
      final signal = (prefs.getString(_keyNativeSignal) ?? '').toLowerCase();
      final number = prefs.getString(_keyNativeSignalNumber) ?? '';

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (ts > 0 && (nowSec - ts).abs() > 300) { 
        if (ts > _lastHandledNativeSignalTs) {
          debugPrint('CallMonitor: Ignorando señal CADUCADA ($signal)');
          _lastHandledNativeSignalTs = ts;
        }
        return;
      }

      if (ts <= 0 || ts <= _lastHandledNativeSignalTs) return;
      _lastHandledNativeSignalTs = ts;

      if (signal == 'start') {
        await _handleCallStart(source: 'native_prefs', number: number);
      } else if (signal == 'end') {
        if (!_isInCall && number.isEmpty) return;
        final lastEndSec = _lastHandledEndTs ~/ 1000;
        if (ts <= lastEndSec) return;
        _lastHandledEndTs = ts * 1000;
        await _handleCallEnd(source: 'native_prefs', number: number);
      }
    } catch (e, st) {
      debugPrint('CallMonitor _consumeNativeCallSignal CRASH: $e\n$st');
    }
  }

  static Future<void> _handleCallStart({required String source, String? number}) async {
    if (_isInCall) return;
    _isInCall = true;
    isInCallNotifier.value = true;
    _startAmplitudePolling();
    debugPrint('CallMonitor $source: inicio llamada ${number ?? ""}');
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Grabando llamada',
          notificationText: 'Minuto a Minuto',
        );
      }
    } catch (_) {}
  }

  static void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final amp = await _audioAmplitudeChannel.invokeMethod<int>('getAmplitude');
        // Normalize 0..32767 to 0.0..1.0
        if (amp != null) {
          double normalized = amp / 32767.0;
          if (normalized > 1.0) normalized = 1.0;
          if (normalized < 0.0) normalized = 0.0;
          callAmplitudeNotifier.value = normalized;
        }
      } catch (_) {}
    });
  }

  static void _stopAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    callAmplitudeNotifier.value = 0.0;
  }

  static Future<void> _handleCallEnd({required String source, String? number}) async {
    if (_procesandoFin) return;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      await prefs.reload();
      if (prefs.getBool(_keyProcessingEnd) == true) return;
      await prefs.setBool(_keyProcessingEnd, true);
    } catch (_) {}

    _procesandoFin = true;
    _isInCall = false;
    isInCallNotifier.value = false;
    _stopAmplitudePolling();
    debugPrint('CallMonitor $source: fin llamada ${number ?? ""}');

    CallSavingProgressService.notifyFinalizandoGrabacion();
    
    String? audioPath;
    // Más intentos con delays crecientes para dispositivos lentos
    for (var i = 0; i < 12; i++) {
      await Future.delayed(Duration(milliseconds: i < 4 ? 800 : 1500));
      audioPath = await _consumeNativeRecordingPath();
      if (audioPath != null) break;
      if (i >= 2) {
        audioPath = await _findLatestRecordingFallback(maxMinutes: 5);
        if (audioPath != null) break;
      }
    }
    
    try {
      await _onCallEnded(audioPath: audioPath, nativeNumber: number);
    } catch (e, st) {
      debugPrint('CallMonitor _handleCallEnd CRASH: $e\n$st');
    } finally {
      _procesandoFin = false;
      try {
        final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
        await prefs.setBool(_keyProcessingEnd, false);
      } catch (_) {}
    }
  }

  static const _keyNativeRecordingPath = 'last_recording_path';
  // Fallback keys in case of prefixing issues
  static const _keyNativeRecordingPathAlt = 'flutter.last_recording_path';

  static Future<String?> _consumeNativeRecordingPath() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      await prefs.reload();
      
      // Intentar con y sin prefijo manual
      String? path = prefs.getString(_keyNativeRecordingPath);
      if (path == null || path.isEmpty) {
        path = prefs.getString(_keyNativeRecordingPathAlt);
      }
      
      if (path == null || path.isEmpty) return null;
      
      // Limpiar para el siguiente
      await prefs.remove(_keyNativeRecordingPath);
      await prefs.remove(_keyNativeRecordingPathAlt);
      
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('CallMonitor: El archivo en SharedPreferences no existe fisicamente: $path');
        return null;
      }
      
      final len = await file.length();
      if (len > 0) {
        debugPrint('CallMonitor: Audio encontrado en SharedPreferences: $path ($len bytes)');
        return path;
      }
      return null;
    } catch (e) { 
      debugPrint('CallMonitor Error consumiendo path: $e');
      return null; 
    }
  }

  static Future<String?> _findLatestRecordingFallback({int maxMinutes = 10}) async {
    try {
      final appFlutterDir = await getApplicationDocumentsDirectory(); 
      final filesDir = await getApplicationSupportDirectory();
      
      final candidates = [
        Directory('${filesDir.path}/call_recordings'),
        Directory('${appFlutterDir.path}/call_recordings'),
        Directory('${appFlutterDir.parent.path}/call_recordings'),
        
        // Rutas OEM Nativas (Samsung, Xiaomi, Huawei) para robar el audio del Dialer oficial si la app falló
        Directory('/storage/emulated/0/Call'),
        Directory('/storage/emulated/0/Recordings/Call'),
        Directory('/storage/emulated/0/Music/Call Recordings'),
        Directory('/storage/emulated/0/MIUI/sound_recorder/call_rec'),
        Directory('/storage/emulated/0/Sounds/CallRecord'),
        Directory('/storage/emulated/0/Audio/Call'),
      ];

      final cutoff = DateTime.now().subtract(Duration(minutes: maxMinutes));
      File? best;
      int bestMod = 0;

      for (final dir in candidates) {
        if (!await dir.exists()) {
          continue;
        }
        
        try {
          await for (final e in dir.list(recursive: false, followLinks: false)) {
            if (e is! File) continue;
            
            final path = e.path.toLowerCase();
            if (!path.endsWith('.wav') && !path.endsWith('.mp4') && !path.endsWith('.m4a') && 
                !path.endsWith('.amr') && !path.endsWith('.aac') && !path.endsWith('.mp3')) {
              continue;
            }
            
            final mod = await e.lastModified();
            if (mod.isBefore(cutoff)) continue;
            
            final len = await e.length();
            if (len < 4096) continue; // descartar archivos vacíos (0 bytes provenientes de bloqueos PCM)
            
            final ms = mod.millisecondsSinceEpoch;
            if (ms > bestMod) {
              bestMod = ms;
              best = e;
            }
          }
        } catch (e) {
          debugPrint('CallMonitor: Sin permisos para leer directorio nativo $dir');
        }
      }
      
      if (best != null) {
        debugPrint('CallMonitor: Fallback encontró audio: ${best.path} (${await best.length()} bytes)');
      } else {
        debugPrint('CallMonitor: Fallback NO encontró ningún audio reciente');
      }
      return best?.path;
    } catch (e) { 
      debugPrint('CallMonitor Fallback error: $e'); 
      return null; 
    }
  }

  static void _listenToCallState() {
    if (!_isAndroid) return;
    try {
      _callStateSub?.cancel();
      _callStateSub = _nativeCallStateChannel.receiveBroadcastStream().listen((data) async {
        if (data is Map) {
          final state = data['state'];
          final number = data['number'] as String?;
          final ts = DateTime.now().millisecondsSinceEpoch;
          
          if (state == 'start') {
            await _handleCallStart(source: 'event_channel', number: number);
          } else if (state == 'end') {
            if (ts - _lastHandledEndTs < 2000) return;
            _lastHandledEndTs = ts;
            await _handleCallEnd(source: 'event_channel', number: number);
          }
        }
      });
    } catch (_) {}
  }

  static Future<void> _onCallEnded({String? audioPath, String? nativeNumber}) async {
    await _runSafe(() async {
      final prefs = await SharedPreferences.getInstance();
      await _onCallEndedCore(prefs: prefs, audioPath: audioPath, nativeNumber: nativeNumber);
    });
  }

  static Future<void> _onCallEndedCore({
    required SharedPreferences prefs,
    String? audioPath,
    String? nativeNumber,
  }) async {
    CallLogEntry? entry;
    try {
      entry = await _pollForCallLog();
    } catch (e) {
      debugPrint('CallMonitor _pollForCallLog error: $e');
    }
    
    // Fallback: usar número nativo si call log no encontró nada
    entry ??= (nativeNumber != null ? _createSyntheticEntry(nativeNumber) : null);
    
    // Último recurso: crear entrada sintética con datos de SharedPreferences
    if (entry == null) {
      final lastNumber = prefs.getString('last_call_number') ?? prefs.getString('numero_telefono_propietario');
      if (lastNumber != null && lastNumber.isNotEmpty) {
        entry = _createSyntheticEntry(lastNumber);
        debugPrint('CallMonitor: usando número de SharedPreferences como fallback: $lastNumber');
      }
    }
    
    // Si aún no hay entry, crear una genérica para no perder la llamada
    entry ??= _createSyntheticEntry('Desconocido');

    final r = await _prepareRegistro(prefs, entry, audioPath);
    String finalId = r.id;
    bool merged = false;

    CallSavingProgressService.notifyGuardandoDatos();

    try {
      final result = await DataService.insertRegistroLlamadaWithCorrelation(r).timeout(const Duration(seconds: 60));
      finalId = result.registroId;
      merged = result.merged;
      await prefs.setString(_keyLastRegistroId, finalId);
    } catch (e) {
      // DataService ya tiene fallback local, esto solo pasa si hasta el local falla
      final errMsg = e.toString().replaceFirst('Exception: ', '').split('\n').first;
      debugPrint('CallMonitor: Error total al guardar (API + local): $errMsg');
      await CallDiagnosticService.record(
        registroId: r.id,
        nombreContactado: r.nombreContactado,
        duracionMinutos: r.duracionMinutos,
        guardadoEnApi: false,
        merged: false,
        audioPath: audioPath,
        errorMsg: '⚠️ ERROR: $errMsg',
      );
      await prefs.setString(_keyLastProcessedId, entry.id ?? entry.timestamp.toString());
      CallSavingProgressService.notifyError('❌ Error guardando: $errMsg');
      return;
    }
    
    await prefs.setString(_keyLastProcessedId, entry.id ?? entry.timestamp.toString());
    await prefs.setString(keyCumplioMetaPending, finalId);
    await _notifyUser(finalId, r.nombreContactado, r.duracionMinutos, merged, 'API');
    
    // Registrar diagnóstico para mostrar en la UI
    await CallDiagnosticService.record(
      registroId: finalId,
      nombreContactado: r.nombreContactado,
      duracionMinutos: r.duracionMinutos,
      guardadoEnApi: true,
      merged: merged,
      audioPath: audioPath,
    );
    
    // Alerta de éxito clara al usuario
    CallSavingProgressService.notifyListo(cruce: merged);

    // Traer la app al frente y navegar a Mis Llamadas para el formulario
    try {
      FlutterForegroundTask.launchApp();
      await Future.delayed(const Duration(milliseconds: 800));
      final nav = AppKeys.navigatorKey.currentState;
      if (nav != null) {
        nav.push(MaterialPageRoute(builder: (_) => const MisLlamadasScreen()));
      }
    } catch (e) {
      debugPrint('CallMonitor: no se pudo traer la app al frente: $e');
    }

    // Subir audio al servidor en background (no bloquea la UI)
    if (audioPath != null && audioPath.isNotEmpty) {
      unawaited(_uploadAudioBackground(finalId, audioPath, isPuntoB: merged));
      // Auto-transcribir con IA en background
      unawaited(_autoTranscribe(finalId, audioPath));
    }
  }

  /// Transcribe automáticamente el audio después de una llamada (unido a la cola del manager)
  static Future<void> _autoTranscribe(String registroId, String audioPath) async {
    try {
      // Esperar un poco para que el audio se termine de escribir al archivo antes de encolar
      await Future.delayed(const Duration(seconds: 4));
      TranscriptionManager.instance.enqueue(registroId, audioPath);
    } catch (e) {
      debugPrint('CallMonitor: error en auto-transcripción: $e');
    }
  }

  /// Sube el audio al servidor y parchea rutaGrabacion con la URL resultante.
  static Future<void> _uploadAudioBackground(String registroId, String audioPath, {bool isPuntoB = false}) async {
    try {
      final audioUrl = await ApiService.uploadAudioFile(registroId, audioPath, isPuntoB: isPuntoB);
      if (audioUrl != null && audioUrl.isNotEmpty) {
        // Guardar la URL en el servidor
        await ApiService.updateRegistroLlamadaRutaGrabacion(registroId, audioUrl, isPuntoB: isPuntoB);
        // También actualizar la URL en la base de datos local para mantener sincronía
        try {
          if (!isPuntoB) {
            await DatabaseService.updateRegistroLlamadaRutaGrabacion(registroId, audioUrl);
          }
        } catch (_) {}
        debugPrint('CallMonitor: audio URL (${isPuntoB ? "Punto B" : "Principal"}) guardada: $audioUrl');
      }
    } catch (e) {
      debugPrint('CallMonitor: error subiendo audio: $e');
    }
  }

  static Future<CallLogEntry?> _pollForCallLog() async {
    // Más reintentos con delays crecientes para dispositivos lentos
    final delays = [500, 800, 1000, 1500, 2000, 2000, 2500, 3000];
    for (var i = 0; i < delays.length; i++) {
      try {
        final entries = await CallLog.get();
        if (entries.isNotEmpty) {
          final last = entries.first;
          final diff = (DateTime.now().millisecondsSinceEpoch - (last.timestamp ?? 0)).abs();
          // Ventana ampliada a 2 minutos para dispositivos lentos
          if (diff < 120000) return last;
        }
      } catch (e) {
        debugPrint('CallMonitor _pollForCallLog intento $i error: $e');
      }
      await Future.delayed(Duration(milliseconds: delays[i]));
    }
    return null;
  }

  static CallLogEntry _createSyntheticEntry(String number) {
    return CallLogEntry(
      number: number,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      duration: 0,
      callType: CallType.outgoing,
    );
  }

  static Future<RegistroLlamada> _prepareRegistro(SharedPreferences prefs, CallLogEntry entry, String? audioPath) async {
    final dur = (entry.duration ?? 0) > 0 ? (entry.duration! / 60).ceil() : 0;
    final ts = entry.timestamp ?? DateTime.now().millisecondsSinceEpoch;
    
    final supId = prefs.getString('supervisor_id');
    final venId = prefs.getString('vendedor_id');
    
    // Ubicación: lastKnown del stream → última conocida de Android → GPS fresco → fallback IP
    Position? pos = LocationService.lastKnown;
    if (pos == null) {
      try { pos = await Geolocator.getLastKnownPosition(); } catch (_) {}
    }
    // Leer de SharedPreferences (funciona en todos los isolates)
    if (pos == null) {
      try { pos = await LocationService.getFromPrefs(); } catch (_) {}
    }
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.reduced, timeLimit: Duration(seconds: 6)),
        ).timeout(const Duration(seconds: 7));
      } catch (_) {}
    }
    if (pos == null) {
      try { pos = await LocationService.getGoogleGeolocationFallback(); } catch (_) {}
    }

    final results = await Future.wait([
      IpService.getPublicIp().timeout(const Duration(seconds: 6)).catchError((_) => null),
      supId != null ? DataService.getSupervisor(supId).catchError((_) => null) : Future.value(null),
      venId != null ? DataService.getVendedor(venId).catchError((_) => null) : Future.value(null),
    ]);

    final ip = results[0] as String?;
    final sup = results[1] as Supervisor?;
    final ven = results[2] as Vendedor?;

    final name = sup?.nombre ?? ven?.nombre ?? prefs.getString('user_name') ?? 'Usuario';
    final p = sup?.telefono ?? ven?.telefono ?? prefs.getString('numero_telefono_propietario');
    final c = sup?.cargo ?? NivelCargo.values.firstWhere((e) => e.valor == prefs.getString('user_cargo'), orElse: () => NivelCargo.coach);

    return RegistroLlamada(
      id: 'llamada_${ts}_${PhoneUtils.normalize(p ?? "")}_${PhoneUtils.normalize(entry.number ?? "")}',
      fecha: DateTime.fromMillisecondsSinceEpoch(ts),
      horaInicio: DateTime.now().subtract(Duration(seconds: entry.duration ?? 0)),
      horaFin: DateTime.now(),
      duracionMinutos: dur,
      tipoLlamada: TipoLlamada.fromHora(),
      cargoLider: c,
      zona: sup?.zona ?? ven?.zona ?? prefs.getString('user_zona') ?? 'N/A',
      nombreLider: name.isNotEmpty ? name : 'Auto',
      nombreContactado: (entry.name?.isNotEmpty == true) ? entry.name! : (entry.number ?? 'Desconocido'),
      confirmacionVeracidad: true,
      observaciones: 'Llamada ${entry.callType}. Duración: $dur min. IP: $ip',
      rutaGrabacion: audioPath,
      numeroContacto: entry.number,
      numeroPropietario: p,
      latitud: pos?.latitude,
      longitud: pos?.longitude,
    );
  }

  static Future<void> _notifyUser(String id, String name, int dur, bool merged, String env) async {
    try { await PostCallNotificationService.showLlamadaGrabadaYRegistrada(id, name, dur, correlacionada: merged, guardadoEn: env); } catch (_) {}
  }

  static Future<void> _attachAudioToLastRegistro({required SharedPreferences prefs, required String audioPath}) async {
    final lastId = prefs.getString(_keyLastRegistroId);
    if (lastId == null) return;
    try { await DataService.uploadAudioPuntoB(lastId, audioPath); } catch (_) {}
  }

  static void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'minutoaminuto_call_monitor',
        channelName: 'Grabación de llamadas',
        channelDescription: 'App en segundo plano. Graba y registra llamadas automáticamente.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_taskRepeatMs),
        autoRunOnBoot: true,
      ),
    );
  }

  static Future<void> runBackgroundTick() async {
    if (!_guardAndroid()) return;
    await runZonedGuarded(() async {
      if (!await isEnabled()) return;
      await _consumeNativeCallSignal();
    }, (error, stack) {
      debugPrint('CallMonitor runBackgroundTick CRASH: $error\n$stack');
    });
  }
}
