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
import 'post_call_notification_service.dart';
import 'transcription_service.dart';

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
  static const EventChannel _nativeCallStateChannel = EventChannel(
    'minutoaminuto/call_state',
  );

  /// Delays en ms para no saturar el sistema Android al pedir permisos.
  static const int _delayAfterNotificationMs = 600;
  static const int _delayAfterPhoneMs = 600;
  static const int _delayAfterMicMs = 500;
  static const int _delayBeforeStartServiceSec = 1;
  static const int _delayBeforeMonitoringSec = 2;
  static const int _pollIntervalWithListenerSec = 8;
  static const int _pollIntervalOnlyPollingSec = 5;
  static const int _firstPollDelaySec = 1;

  static StreamSubscription? _callStateSub;
  static bool _isInCall = false;
  static bool _isStarting = false;
  static Timer? _pollTimer;
  /// Listener de estado de llamada activo para grabación automática.
  static bool _usePhoneStateListener = true;
  static bool _isManualRecording = false;
  static bool get isManualRecording => _isManualRecording;
  static const int _delayBeforePhoneStateListenerSec = 1;
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
      return await Permission.phone.isGranted && await Permission.microphone.isGranted;
    } catch (_) {
      return false;
    }
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
      try {
        await PostCallNotificationService.init();
      } catch (e) {
        debugPrint('PostCallNotification init: $e');
      }
      final enabled = await isEnabled();
      if (!enabled) return;
      final hasPerms = await hasPermissions();
      if (!hasPerms) return;
      Future.delayed(const Duration(seconds: 2), () async {
        await _runSafe(() async {
          try {
            if (!await isEnabled()) return;
            await _startMonitoring();
          } catch (e) {
            debugPrint('CallMonitor init defer: $e');
          }
        });
      });
    });
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
      unawaited(Future.delayed(const Duration(seconds: _delayBeforeMonitoringSec), () async {
        runZonedGuarded(() async {
          await _runSafe(() async {
            try {
              if (!await isEnabled()) return;
              await _startMonitoring();
            } catch (e, st) {
              debugPrint('CallMonitor delayed start error: $e $st');
            }
          });
        }, (error, stack) {
          debugPrint('CallMonitor start zone: $error\n$stack');
        });
      }));
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
      } catch (e) {
        debugPrint('CallMonitor stop cleanup: $e');
      }
      try {
        await FlutterForegroundTask.stopService();
      } catch (e) {
        debugPrint('CallMonitor stop (service): $e');
      }
    });
  }

  static Future<void> _startMonitoring() async {
    if (_pollTimer != null) return;

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

    bool started = false;
    try {
      if (!await isEnabled()) return;
      final running = await FlutterForegroundTask.isRunningService;
      if (!running) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
        );
      } else {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Minuto a Minuto - Activo',
          notificationText: 'Registrando y grabando llamadas automáticamente.',
        );
      }
      started = true;
    } catch (e, st) {
      debugPrint('ForegroundTask startService error: $e $st');
      started = false;
    }
    if (!started) return;

    _startCallLogPolling();

    if (_usePhoneStateListener) {
      Future.delayed(const Duration(seconds: _delayBeforePhoneStateListenerSec), () async {
        runZonedGuarded(() async {
          await _runSafe(() async {
            if (!_isAndroid || !await isEnabled()) return;
            if (_callStateSub != null) return;
            try {
              _listenToCallState();
            } catch (e) {
              debugPrint('Native call state start: $e');
              _usePhoneStateListener = false;
            }
          });
        }, (error, stack) {
          debugPrint('Native call state zone: $error\n$stack');
          _usePhoneStateListener = false;
        });
      });
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
          await _checkAndStartRecordingIfInCall();
          await _onCallEnded();
        } catch (e) {
          debugPrint('CallMonitor polling error: $e');
        }
      });
    });
    Future.delayed(const Duration(seconds: _firstPollDelaySec), () async {
      await _runSafe(() async {
        try {
          if (!await isEnabled()) return;
          await _checkAndStartRecordingIfInCall();
          await _onCallEnded();
        } catch (_) {}
      });
    });
  }

  static Future<void> _checkAndStartRecordingIfInCall() async {
    try {
      final entries = await CallLog.get();
      if (entries.isEmpty) return;
      final last = entries.first;
      final ts = last.timestamp ?? 0;
      final callTime = DateTime.fromMillisecondsSinceEpoch(ts);
      final now = DateTime.now();
      final diffSec = now.difference(callTime).inSeconds;
      final dur = last.duration ?? 0;

      if (dur == 0 && diffSec < 120) {
        if (!_isInCall) {
          _isInCall = true;
          debugPrint('CallMonitor polling: llamada activa detectada, iniciando grabación');
          try {
            final path = await CallAudioRecordingService.start();
            if (path != null) {
              debugPrint('CallMonitor polling: grabación iniciada');
              try {
                if (await FlutterForegroundTask.isRunningService) {
                  await FlutterForegroundTask.updateService(
                    notificationTitle: 'Grabando llamada...',
                    notificationText: 'Minuto a Minuto - Grabación activa',
                  );
                }
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('CallMonitor polling start recording: $e');
          }
        }
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
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
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
                _isInCall = true;
                await Future.delayed(const Duration(milliseconds: 500));
                for (var attempt = 0; attempt < 3; attempt++) {
                  try {
                    final path = await CallAudioRecordingService.start();
                    if (path != null) {
                      debugPrint('CallMonitor: grabación iniciada (intento $attempt)');
                      break;
                    }
                  } catch (e) {
                    debugPrint('CallMonitor start recording intento $attempt: $e');
                  }
                  if (attempt < 2) {
                    await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
                  }
                }
                try {
                  if (await FlutterForegroundTask.isRunningService) {
                    await FlutterForegroundTask.updateService(
                      notificationTitle: 'Grabando llamada',
                      notificationText: 'Minuto a Minuto',
                    );
                  }
                } catch (_) {}
              } else if (state == 'end') {
                String? audioPath;
                try {
                  if (await FlutterForegroundTask.isRunningService) {
                    await FlutterForegroundTask.updateService(
                      notificationTitle: 'Guardando...',
                      notificationText: 'Minuto a Minuto',
                    );
                  }
                } catch (_) {}
                try {
                  audioPath = await CallAudioRecordingService.stop();
                  if (audioPath != null) {
                    final file = File(audioPath);
                    if (await file.exists()) {
                      final size = await file.length();
                      if (size <= 0) {
                        await Future.delayed(const Duration(milliseconds: 500));
                        final retrySize = await file.length();
                        if (retrySize <= 0) audioPath = null;
                      }
                    } else {
                      audioPath = null;
                    }
                  }
                } catch (e) {
                  debugPrint('CallMonitor stop recording: $e');
                }
                _isInCall = false;
                await _onCallEnded(audioPath: audioPath);
                try {
                  if (await FlutterForegroundTask.isRunningService) {
                    await FlutterForegroundTask.updateService(
                      notificationTitle: 'Minuto a Minuto - Activo',
                      notificationText:
                          'Registrando y grabando llamadas automáticamente.',
                    );
                  }
                } catch (_) {}
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
      await Future.delayed(const Duration(milliseconds: 600));
      Iterable<CallLogEntry> entries = await CallLog.get();
      if (entries.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 400));
        entries = await CallLog.get();
      }
      if (entries.isEmpty) return;
      final last = entries.first;
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_keyLastProcessedId);
      final id = '${last.timestamp}_${last.number}_${last.duration}';
      if (lastId == id) {
        if (audioPath != null && audioPath.isNotEmpty) {
          await _attachAudioToLastRegistro(
            prefs: prefs,
            audioPath: audioPath,
          );
        }
        return;
      }
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

      String ubicacion = '';
      try {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          ubicacion =
              'Ubicación: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
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
      );

      try {
        await DataService.insertRegistroLlamada(r);
        await prefs.setString(_keyLastRegistroId, r.id);
        debugPrint('CallMonitor: $tipoTexto - $nombreContactado ($duration min)');
      } catch (e) {
        debugPrint('CallMonitor insertRegistro remoto: $e');
        try {
          await DatabaseService.insertRegistroLlamada(r);
          await prefs.setString(_keyLastRegistroId, r.id);
          debugPrint(
            'CallMonitor: registro guardado en SQLite respaldo (${r.id})',
          );
        } catch (e2) {
          debugPrint('CallMonitor insertRegistro sqlite: $e2');
          return;
        }
      }

      try {
        await PostCallNotificationService.showLlamadaGrabadaYRegistrada(
          r.id,
          nombreContactado,
          duration,
        );
      } catch (e) {
        debugPrint('PostCallNotification: $e');
      }

      if (audioPath != null && audioPath.isNotEmpty) {
        unawaited(_transcribirEnSegundoPlano(r.id, audioPath));
      }
    } catch (e, st) {
      debugPrint('CallMonitor _onCallEnded: $e $st');
    }
  }

  static Future<void> _transcribirEnSegundoPlano(
    String registroId,
    String rutaAudio,
  ) async {
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
