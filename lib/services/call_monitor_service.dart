import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/registro_llamada.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../models/tipo_llamada.dart';
import '../models/nivel_cargo.dart';
import 'call_audio_recording_service.dart';
import 'data_service.dart';
import 'database_service.dart';
import 'ip_service.dart';
import 'location_service.dart';
import 'call_saving_progress_service.dart';
import 'post_call_notification_service.dart';
import 'transcription_service.dart';

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
    unawaited(
      CallMonitorService.runBackgroundTick().whenComplete(() {
        _busy = false;
      }),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// Monitor de llamadas para Android: registra llamadas (y opcionalmente audio) en segundo plano.
///
/// Flujo Android:
/// 1. Permisos (teléfono, micrófono, notificaciones) antes de activar.
/// 2. Servicio en primer plano para que el proceso no se cierre al salir de la app.
/// 3. Detección por polling del registro de llamadas (CallLog); opcionalmente listener nativo para audio.
class CallMonitorService {
  static const _keyEnabled = 'call_monitor_enabled';
  static const _keyLastProcessedId = 'call_monitor_last_id';
  static const _keyLastRegistroId = 'call_monitor_last_registro_id';
  static const _keyNativeSignal = 'native_call_state_signal';
  static const _keyNativeSignalTs = 'native_call_state_ts';
  static const _keyNativeSignalNumber = 'native_call_state_number';
  static const EventChannel _nativeCallStateChannel = EventChannel(
    'minutoaminuto/call_state',
  );
  static const MethodChannel _audioRouteChannel = MethodChannel(
    'minutoaminuto/audio_route',
  );

  /// Delays en ms para no saturar el sistema Android al pedir permisos.
  static const int _delayAfterNotificationMs = 600;
  static const int _delayAfterPhoneMs = 600;
  static const int _delayAfterMicMs = 500;
  static const int _delayBeforeStartServiceSec = 1;
  static const int _pollIntervalWithListenerSec = 2;
  static const int _pollIntervalOnlyPollingSec = 2;
  static const int _taskRepeatMs = 1500;
  static const int _watchdogIntervalSec = 15;

  static StreamSubscription? _callStateSub;
  static bool _isInCall = false;
  static bool _isStarting = false;
  static bool _procesandoFin = false; // mutex para evitar doble registro
  static Timer? _pollTimer;
  static Timer? _serviceWatchdogTimer;
  static bool _usePhoneStateListener = true;
  static bool _isManualRecording = false;
  static bool get isManualRecording => _isManualRecording;
  static int _lastHandledNativeSignalTs = 0;
  // Timestamp del último fin procesado — evita duplicados entre EventChannel y polling
  static int _lastHandledEndTs = 0;
  // ID de la última llamada registrada — evita duplicados por mismo número+timestamp
  static String _lastRegisteredCallId = '';
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

  /// Ejecuta [fn] en una zona que captura cualquier error para no cerrar la app.
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
      final notif = await Permission.notification.request();
      if (notif.isPermanentlyDenied) return false;
      await Future.delayed(const Duration(milliseconds: _delayAfterNotificationMs + 200));
      final phone = await Permission.phone.request();
      if (!phone.isGranted) return false;
      await Future.delayed(const Duration(milliseconds: _delayAfterPhoneMs));
      await Permission.microphone.request();
      await Future.delayed(const Duration(milliseconds: _delayAfterMicMs));
      try {
        await Permission.locationWhenInUse.request();
      } catch (_) {}
      try {
        await Permission.locationAlways.request();
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

  static Future<bool> isActive() async {
    if (!_guardAndroid()) return false;
    final enabled = await isEnabled();
    if (!enabled) return false;
    return isServiceRunning();
  }

  /// Solo pide permisos que faltan. No re-pide si el usuario ya aceptó (Android best practice).
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
        try {
          if (!await Permission.locationWhenInUse.isGranted) {
            await Permission.locationWhenInUse.request();
          }
        } catch (_) {}
        try {
          if (!await Permission.locationAlways.isGranted) {
            await Permission.locationAlways.request();
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('CallMonitor requestPermissionsIfNeeded: $e');
      }
    });
  }

  static Future<bool> requestAllPermissions() async {
    if (!_guardAndroid()) return false;
    final ok = await _runSafe<bool>(() async {
      await Permission.notification.request();
      final phone = await Permission.phone.request();
      await Permission.microphone.request();
      return phone.isGranted;
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
      // Resetear estado en memoria al iniciar
      _isInCall = false;
      _procesandoFin = false;
      _lastHandledEndTs = 0;
      _lastHandledNativeSignalTs = 0;
      _lastRegisteredCallId = '';

      try {
        await PostCallNotificationService.init();
      } catch (e) {
        debugPrint('PostCallNotification init: $e');
      }

      // Detener el micrófono si quedó activo de una sesión anterior y el teléfono está en IDLE
      await _stopStaleRecordingIfIdle();

      final enabled = await isEnabled();
      if (!enabled) return;
      final hasPerms = await hasPermissions();
      if (!hasPerms) return;

      // PRIMERO: procesar llamada pendiente ANTES de arrancar el polling
      // para evitar que el polling consuma la señal y bloquee el guardado
      await _processPendingCallSaveIfNeeded();

      // DESPUÉS: arrancar el monitoreo normal
      await _startMonitoring();
    });
  }

  /// Detiene el CallRecorderService si el teléfono está en IDLE al arrancar.
  /// Evita el micrófono fantasma cuando la app se reinicia después de una llamada.
  static Future<void> _stopStaleRecordingIfIdle() async {
    if (!_isAndroid) return;
    try {
      await _audioRouteChannel.invokeMethod('stopStaleRecording');
    } catch (e) {
      debugPrint('CallMonitor _stopStaleRecordingIfIdle: $e (ignorado)');
    }
  }

  /// Si el nativo marcó KEY_PENDING_SAVE=true, procesa el fin de llamada al arrancar.
  static Future<void> _processPendingCallSaveIfNeeded() async {
    if (_procesandoFin) return;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.reload();
      final pending = prefs.getBool('native_pending_call_save') ?? false;
      if (!pending) return;

      debugPrint('CallMonitor: llamada pendiente de guardar detectada al arrancar');
      // Limpiar la bandera ANTES de procesar para no repetir si la app se cierra de nuevo
      await prefs.setBool('native_pending_call_save', false);

      final signal = (prefs.getString(_keyNativeSignal) ?? '').toLowerCase();
      final number = prefs.getString(_keyNativeSignalNumber) ?? '';
      final ts     = prefs.getInt(_keyNativeSignalTs) ?? 0;

      if (signal == 'end' && ts > 0) {
        // Marcar todos los timestamps para que ninguna otra fuente duplique
        _lastHandledNativeSignalTs = ts;
        _lastHandledEndTs = ts * 1000;
        // Esperar a que el archivo de grabación esté listo
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

      await setEnabled(true);
      await _runSafe(() async {
        try {
          await PostCallNotificationService.init();
        } catch (e) {
          debugPrint('CallMonitor PostCallNotification init: $e');
        }
      });
      await _startMonitoring();
    } catch (e, st) {
      debugPrint('CallMonitor start error: $e $st');
      try {
        await setEnabled(false);
      } catch (_) {}
    } finally {
      _isStarting = false;
    }
  }

  /// Inicia la grabación manual (solo al pulsar el botón). No usa detector de llamada.
  static Future<bool> startManualRecording() async {
    if (!_guardAndroid()) return false;
    if (_isManualRecording) return true;
    final started = await _runSafe(() async {
      try {
        final path = await CallAudioRecordingService.start();
        if (path != null) {
          _isManualRecording = true;
          return true;
        }
      } catch (e) {
        debugPrint('startManualRecording: $e');
      }
      return false;
    });
    return started ?? false;
  }

  /// Detiene la grabación manual y guarda la última llamada del registro con ese audio.
  static Future<void> stopManualRecordingAndSaveLastCall() async {
    if (!_guardAndroid()) return;
    if (!_isManualRecording) return;
    await _runSafe(() async {
      try {
        final path = await CallAudioRecordingService.stop();
        _isManualRecording = false;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            await _onCallEnded(audioPath: path);
          } else {
            await _onCallEnded();
          }
        } else {
          await _onCallEnded();
        }
      } catch (e) {
        debugPrint('stopManualRecordingAndSaveLastCall: $e');
        _isManualRecording = false;
      }
    });
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
    try {
      FlutterForegroundTask.initCommunicationPort();
    } catch (_) {}
    try {
      _initForegroundTask();
    } catch (e) {
      debugPrint('CallMonitor initForegroundTask: $e');
      return;
    }

    await Future.delayed(const Duration(seconds: _delayBeforeStartServiceSec));
    if (!await isEnabled()) return;
    final ok = await _ensureForegroundServiceRunning(forceNotificationRefresh: true);
    if (!ok) return;
    _startServiceWatchdog();
    _startCallLogPolling();
    if (_callStateSub == null) {
      try {
        _listenToCallState();
      } catch (_) {}
    }
    // Primer tick con delay extra para no bloquear la UI en el arranque
    Future.delayed(const Duration(seconds: 3), () {
      runBackgroundTick().catchError((e) {
        debugPrint('CallMonitor first tick error: $e');
      });
    });
  }

  /// Inicia el PhoneStateMonitorService nativo (TelephonyCallback en segundo plano).
  /// Se llama desde la UI cuando el usuario activa el monitor.
  static Future<void> startNativePhoneMonitor() async {
    if (!_isAndroid) return;
    try {
      await _audioRouteChannel.invokeMethod('startPhoneStateMonitor');
    } catch (e) {
      debugPrint('CallMonitor startNativePhoneMonitor: $e (ignorado)');
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

  static Future<bool> _ensureForegroundServiceRunning({
    bool forceNotificationRefresh = false,
  }) async {
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
        if (result is ServiceRequestFailure) {
          debugPrint('CallMonitor startService failure: ${result.error}');
          return false;
        }
        return true;
      }
      if (forceNotificationRefresh) {
        final update = await FlutterForegroundTask.updateService(
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
          callback: callMonitorForegroundStartCallback,
        );
        if (update is ServiceRequestFailure) {
          debugPrint('CallMonitor updateService failure: ${update.error}');
        }
      }
      return true;
    } catch (e, st) {
      debugPrint('CallMonitor ensureForegroundService error: $e $st');
      return false;
    }
  }

  static void _startCallLogPolling() {
    _pollTimer?.cancel();
    final intervalSec = _usePhoneStateListener
        ? _pollIntervalWithListenerSec
        : _pollIntervalOnlyPollingSec;
    _pollTimer = Timer.periodic(Duration(seconds: intervalSec), (_) async {
      await _runSafe(() async {
        try {
          if (!await isEnabled()) return;
          await _consumeNativeCallSignal();
          // Solo detectar inicio de llamada por polling; el fin lo maneja
          // exclusivamente el BroadcastReceiver nativo para evitar duplicados.
          await _checkAndStartRecordingIfInCall();
          // _checkAndFinalizeRecordingFromPolling deshabilitado: causa duplicados
          // cuando el nativo ya disparó el fin.
        } catch (e) {
          debugPrint('CallMonitor polling error: $e');
        }
      });
    });
  }

  static Future<void> _consumeNativeCallSignal() async {
    // No procesar señales si ya estamos guardando una llamada
    if (_procesandoFin) return;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.reload();
      final ts = prefs.getInt(_keyNativeSignalTs) ?? 0;
      if (ts <= 0 || ts <= _lastHandledNativeSignalTs) return;

      final signal = (prefs.getString(_keyNativeSignal) ?? '').toLowerCase();
      final number = prefs.getString(_keyNativeSignalNumber) ?? '';
      _lastHandledNativeSignalTs = ts;
      debugPrint('CallMonitor native_prefs: señal=$signal ts=$ts number=$number');

      if (signal == 'start') {
        await _handleCallStart(source: 'native_prefs', number: number);
      } else if (signal == 'end') {
        final lastEndSec = _lastHandledEndTs ~/ 1000;
        if (ts <= lastEndSec) {
          debugPrint('CallMonitor native_prefs: fin ya procesado ts=$ts <= lastEnd=$lastEndSec');
          return;
        }
        _lastHandledEndTs = ts * 1000;
        await _handleCallEnd(source: 'native_prefs', number: number);
      }
    } catch (e) {
      debugPrint('CallMonitor _consumeNativeCallSignal: $e');
    }
  }

  static Future<void> _handleCallStart({
    required String source,
    String? number,
  }) async {
    if (_isInCall) return;
    _isInCall = true;
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

  /// Clave donde el servicio nativo guarda la ruta del archivo grabado.
  /// El plugin de Flutter añade automáticamente el prefijo "flutter." al leer,
  /// por lo que la clave aquí debe ser SIN prefijo.
  static const _keyNativeRecordingPath = 'last_recording_path';

  /// Lee y limpia la ruta del archivo grabado por el servicio nativo.
  /// Fuerza reload() para evitar leer un caché desactualizado.
  static Future<String?> _consumeNativeRecordingPath() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      // Forzar recarga desde disco para ver lo que el nativo escribió
      await prefs.reload();
      final path = prefs.getString(_keyNativeRecordingPath);
      if (path == null || path.isEmpty) return null;
      // Limpiar inmediatamente para no reutilizar en la siguiente llamada
      await prefs.remove(_keyNativeRecordingPath);
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('CallMonitor: archivo de grabación no existe: $path');
        return null;
      }
      final size = await file.length();
      if (size <= 0) {
        debugPrint('CallMonitor: archivo de grabación vacío: $path');
        return null;
      }
      debugPrint('CallMonitor: grabación válida encontrada: $path ($size bytes)');
      return path;
    } catch (e) {
      debugPrint('CallMonitor _consumeNativeRecordingPath: $e');
      return null;
    }
  }

  static Future<void> _handleCallEnd({
    required String source,
    String? number,
  }) async {
    // Mutex estricto: si ya estamos procesando un fin, ignorar completamente
    if (_procesandoFin) {
      debugPrint('CallMonitor $source: fin IGNORADO — ya procesando otro fin');
      return;
    }
    _procesandoFin = true;
    _isInCall = false;
    debugPrint('CallMonitor $source: fin llamada ${number ?? ""}');

    CallSavingProgressService.notifyFinalizandoGrabacion();

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Guardando grabación...',
          notificationText: 'Minuto a Minuto',
        );
      }
    } catch (_) {}

    // Esperar a que el servicio nativo termine de escribir el archivo.
    // WAV (PCM conversion) puede tardar hasta 30s en llamadas largas.
    String? audioPath;
    const maxRetries = 30;
    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      CallSavingProgressService.notifySubiendoAudio(i / maxRetries * 0.5);
      audioPath = await _consumeNativeRecordingPath();
      if (audioPath != null) {
        debugPrint('CallMonitor: grabación encontrada en intento ${i + 1}: $audioPath');
        break;
      }
      debugPrint('CallMonitor: esperando grabación... intento ${i + 1}/$maxRetries');
    }

    if (audioPath != null) {
      debugPrint('CallMonitor: grabación encontrada: $audioPath');
    } else {
      debugPrint('CallMonitor: no se encontró grabación del servicio nativo tras ${maxRetries}s');
    }

    try {
      await _onCallEnded(audioPath: audioPath);
    } finally {
      _procesandoFin = false;
    }

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
        );
      }
    } catch (_) {}
  }

  // El polling ya NO inicia grabaciones — solo el BroadcastReceiver nativo lo hace.
  // Esta función solo detecta si hay una llamada activa para marcar _isInCall.
  static Future<void> _checkAndStartRecordingIfInCall() async {
    if (_isInCall) return;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final lastProcessedId = prefs.getString(_keyLastProcessedId) ?? '';

      final entries = await CallLog.get()
          .timeout(const Duration(seconds: 5));
      if (entries.isEmpty) return;
      final last = entries.first;
      final dur = last.duration ?? 0;
      final ts  = last.timestamp ?? 0;
      final lastLogId = '${ts}_${last.number}';

      if (lastProcessedId == lastLogId) return;

      final diffSec = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts))
          .inSeconds;
      if (dur == 0 && diffSec < 90) {
        await _handleCallStart(source: 'polling_detect', number: last.number);
      }
    } catch (e) {
      debugPrint('CallMonitor _checkAndStartRecordingIfInCall: $e');
    }
  }

  static void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'minutoaminuto_call_monitor',
        channelName: 'Grabación de llamadas',
        channelDescription:
            'App en segundo plano. Graba y registra llamadas automáticamente.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        onlyAlertOnce: true,
        showWhen: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_taskRepeatMs),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> runBackgroundTick() async {
    if (!_guardAndroid()) return;
    await _runSafe(() async {
      if (!await isEnabled()) return;
      // Solo consumir señales nativas — el PhoneStateMonitorService es la fuente de verdad
      // No llamar _checkAndStartRecordingIfInCall ni polling de fin para evitar duplicados
      await _consumeNativeCallSignal();
    });
  }

  static void _listenToCallState() {
    if (!_isAndroid) return;
    try {
      _callStateSub?.cancel();
      _callStateSub = _nativeCallStateChannel.receiveBroadcastStream().listen(
        (event) {
          runZonedGuarded(() async {
            try {
              final data = event is Map
                  ? Map<String, dynamic>.from(
                      event.map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    )
                  : const <String, dynamic>{};
              final state = (data['state']?.toString() ?? '').toLowerCase();
              if (state == 'start') {
                await _handleCallStart(
                  source: 'event_channel',
                  number: data['number']?.toString(),
                );
              } else if (state == 'end') {
                if (_procesandoFin) {
                  debugPrint('CallMonitor event_channel: fin IGNORADO — ya procesando');
                  return;
                }
                // Marcar timestamp para que el polling no duplique
                _lastHandledEndTs = DateTime.now().millisecondsSinceEpoch;
                // Sincronizar con native_prefs para que el polling tampoco dispare
                final nowSec = _lastHandledEndTs ~/ 1000;
                if (nowSec > _lastHandledNativeSignalTs) {
                  _lastHandledNativeSignalTs = nowSec;
                }
                await _handleCallEnd(
                  source: 'event_channel',
                  number: data['number']?.toString(),
                );
              }
            } catch (e) {
              debugPrint('CallMonitor native phoneState: $e');
            }
          }, (error, stack) {
            debugPrint('CallMonitor native phoneState zone: $error\n$stack');
          });
        },
        onError: (error, stack) {
          debugPrint('CallMonitor native channel error: $error $stack');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('CallMonitor _listenToCallState: $e');
      _usePhoneStateListener = false;
    }
  }

  static Future<void> _attachAudioToLastRegistro({
    required SharedPreferences prefs,
    required String audioPath,
  }) async {
    if (audioPath.isEmpty) return;
    final registroId = prefs.getString(_keyLastRegistroId);
    if (registroId == null || registroId.isEmpty) return;
    try {
      await DataService.updateRegistroLlamadaRutaGrabacion(registroId, audioPath);
      debugPrint('CallMonitor: audio vinculado al registro $registroId');
    } catch (e) {
      debugPrint('CallMonitor attach audio remoto: $e');
      try {
        await DatabaseService.updateRegistroLlamadaRutaGrabacion(
          registroId,
          audioPath,
        );
        debugPrint(
          'CallMonitor: audio vinculado en SQLite respaldo ($registroId)',
        );
      } catch (e2) {
        debugPrint('CallMonitor attach audio sqlite: $e2');
      }
    }
  }

  static Future<void> _onCallEnded({String? audioPath}) async {
    try {
      CallSavingProgressService.notifyGuardandoDatos();
      // Esperar a que Android actualice el CallLog (puede tardar hasta 3s)
      await Future.delayed(const Duration(milliseconds: 1500));

      Iterable<CallLogEntry> entries = const [];
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          entries = await CallLog.get().timeout(const Duration(seconds: 6));
          if (entries.isNotEmpty) break;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 800));
        debugPrint('CallMonitor _onCallEnded: reintentando CallLog (intento ${attempt + 1})');
      }
      if (entries.isEmpty) {
        debugPrint('CallMonitor _onCallEnded: CallLog vacío tras 5 intentos — abortando');
        return;
      }
      final last = entries.first;
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final lastId = prefs.getString(_keyLastProcessedId);
      // ID basado solo en timestamp+número (sin duración) para deduplicar
      final id = '${last.timestamp}_${last.number}';

      // Doble barrera: prefs persistida + variable en memoria
      if (lastId == id || _lastRegisteredCallId == id) {
        debugPrint('CallMonitor _onCallEnded: llamada ya registrada ($id) — solo adjuntar audio');
        if (audioPath != null && audioPath.isNotEmpty) {
          await _attachAudioToLastRegistro(prefs: prefs, audioPath: audioPath);
        }
        return;
      }
      // Marcar en memoria Y en prefs ANTES de insertar para evitar race condition
      _lastRegisteredCallId = id;
      await prefs.setString(_keyLastProcessedId, id);

      final durationSec = last.duration ?? 0;
      final duration = durationSec > 0
          ? (durationSec / 60).ceil().clamp(1, 999)
          : 1;

      final ts = last.timestamp ?? DateTime.now().millisecondsSinceEpoch;
      final fecha = DateTime.fromMillisecondsSinceEpoch(ts);
      final fin = DateTime.now();
      final inicio = fin.subtract(
        Duration(seconds: durationSec > 0 ? durationSec : 60),
      );

      final nombreContactado = (last.name?.isNotEmpty == true)
          ? last.name!
          : (last.number ?? 'Desconocido');

      double? latitud;
      double? longitud;
      String ubicacion = '';
      try {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          latitud = pos.latitude;
          longitud = pos.longitude;
          ubicacion =
              'Ubicación: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        }
      } catch (_) {}

      String ipPublica = '';
      try {
        final ip = await IpService.getPublicIp();
        if (ip != null && ip.isNotEmpty) ipPublica = 'IP: $ip';
      } catch (_) {}

      final horaStr =
          '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
      final esIncoming =
          last.callType == CallType.incoming ||
          last.callType == CallType.wifiIncoming;
      final tipoTexto = esIncoming ? 'Llamada recibida' : 'Llamada realizada';
      final duracionTexto = duration == 1 ? '1 min' : '$duration min';
      final observaciones = [
        tipoTexto,
        'Duración: $duracionTexto',
        'Hora: $horaStr',
        'Número: ${last.number ?? "?"}',
        if (ipPublica.isNotEmpty) ipPublica,
        if (ubicacion.isNotEmpty) ubicacion,
        if (audioPath != null && audioPath.isNotEmpty) 'Audio: guardado',
      ].join('. ');

      Supervisor? sup;
      Vendedor? ven;
      try {
        final supId = prefs.getString('supervisor_id');
        final venId = prefs.getString('vendedor_id');
        if (supId != null) sup = await DataService.getSupervisor(supId);
        if (venId != null) ven = await DataService.getVendedor(venId);
      } catch (_) {}

      final nombreLider = sup?.nombre ?? ven?.nombre ?? 'Usuario';
      final zona = sup?.zona ?? ven?.zona ?? '';
      final numeroPropietario = sup?.telefono ?? ven?.telefono ??
          prefs.getString('numero_telefono_propietario');
      final numeroContacto = last.number;

      final r = RegistroLlamada(
        id: const Uuid().v4(),
        fecha: fecha,
        horaInicio: inicio,
        horaFin: fin,
        duracionMinutos: duration,
        tipoLlamada: TipoLlamada.manana,
        cargoLider: sup?.cargo ?? NivelCargo.coach,
        zona: zona,
        nombreLider: nombreLider,
        nombreContactado: nombreContactado,
        confirmacionVeracidad: true,
        observaciones: observaciones,
        rutaGrabacion: audioPath,
        numeroContacto: numeroContacto,
        numeroPropietario: numeroPropietario,
        latitud: latitud,
        longitud: longitud,
      );

      bool insertOk = false;
      String finalRegistroId = r.id;
      bool wasMerged = false;
      try {
        CallSavingProgressService.notifySubiendoAudio(0.5);
        final result = await DataService.insertRegistroLlamadaWithCorrelation(r);
        await prefs.setString(_keyLastRegistroId, result.registroId);
        finalRegistroId = result.registroId;
        wasMerged = result.merged;
        debugPrint('CallMonitor: $tipoTexto - $nombreContactado ($duration min)${result.merged ? ' [correlacionado]' : ''}');
        insertOk = true;
      } catch (e) {
        debugPrint('CallMonitor insertRegistro remoto: $e');
        try {
          await DatabaseService.insertRegistroLlamada(r);
          await prefs.setString(_keyLastRegistroId, r.id);
          finalRegistroId = r.id;
          debugPrint(
            'CallMonitor: registro guardado en SQLite respaldo (${r.id})',
          );
          insertOk = true;
        } catch (e2) {
          debugPrint('CallMonitor insertRegistro sqlite: $e2');
          CallSavingProgressService.notifyError('Error al guardar la llamada');
          return;
        }
      }

      if (insertOk) {
        CallSavingProgressService.notifySubiendoAudio(0.9);
      }

      try {
        await PostCallNotificationService.showLlamadaGrabadaYRegistrada(
          finalRegistroId,
          nombreContactado,
          duration,
          correlacionada: wasMerged,
        );
      } catch (e) {
        debugPrint('PostCallNotification: $e');
      }

      if (audioPath != null && audioPath.isNotEmpty && !wasMerged) {
        unawaited(_transcribirEnSegundoPlano(finalRegistroId, audioPath));
      } else {
        CallSavingProgressService.notifyListo();
      }
    } catch (e, st) {
      debugPrint('CallMonitor _onCallEnded: $e $st');
      CallSavingProgressService.notifyError('Error inesperado al guardar');
    }
  }

  static Future<void> _transcribirEnSegundoPlano(
    String registroId,
    String rutaAudio,
  ) async {
    CallSavingProgressService.notifyTranscribiendo();
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Transcribiendo llamada...',
          notificationText: 'Minuto a Minuto - IA procesando audio',
        );
      }
    } catch (_) {}

    try {
      final text = await TranscriptionService.transcribeAndSave(
        registroId: registroId,
        rutaAudio: rutaAudio,
      );
      if (text != null) {
        debugPrint('CallMonitor: transcripción completada (${text.length} chars)');
      } else {
        debugPrint('CallMonitor: transcripción devolvió null');
      }
    } catch (e) {
      debugPrint('CallMonitor transcripción error: $e');
    }

    CallSavingProgressService.notifyListo();

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
        );
      }
    } catch (_) {}
  }
}
