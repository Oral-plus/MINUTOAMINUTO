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
import 'ip_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'location_service.dart';
import 'call_saving_progress_service.dart';
import 'post_call_notification_service.dart';
import 'call_diagnostic_service.dart';

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
      await Permission.notification.request();
      await Future.delayed(const Duration(milliseconds: _delayAfterNotificationMs));
      final phone = await Permission.phone.request();
      if (!phone.isGranted) return false;
      await Future.delayed(const Duration(milliseconds: _delayAfterPhoneMs));
      await Permission.microphone.request();
      await Future.delayed(const Duration(milliseconds: _delayAfterMicMs));
      try {
        await Permission.locationWhenInUse.request();
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
        try {
          if (!await Permission.locationWhenInUse.isGranted) {
            await Permission.locationWhenInUse.request();
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
    debugPrint('CallMonitor $source: fin llamada ${number ?? ""}');

    CallSavingProgressService.notifyFinalizandoGrabacion();
    
    String? audioPath;
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      audioPath = await _consumeNativeRecordingPath();
      if (audioPath != null) break;
      if (i >= 2) {
        audioPath = await _findLatestRecordingFallback();
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

  static Future<String?> _consumeNativeRecordingPath() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      await prefs.reload();
      final path = prefs.getString(_keyNativeRecordingPath);
      if (path == null || path.isEmpty) return null;
      await prefs.remove(_keyNativeRecordingPath);
      final file = File(path);
      if (!await file.exists()) return null;
      return (await file.length()) > 0 ? path : null;
    } catch (_) { return null; }
  }

  static Future<String?> _findLatestRecordingFallback({int maxMinutes = 10}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/call_recordings');
      if (!await dir.exists()) return null;
      final cutoff = DateTime.now().subtract(Duration(minutes: maxMinutes));
      File? best;
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final mod = await e.lastModified();
        if (mod.isBefore(cutoff)) continue;
        if (best == null || mod.isAfter(await best.lastModified())) best = e;
      }
      return best?.path;
    } catch (_) { return null; }
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
    
    entry ??= (nativeNumber != null ? _createSyntheticEntry(nativeNumber) : null);
    
    if (entry == null) {
      if (audioPath != null) {
        try {
          await _attachAudioToLastRegistro(prefs: prefs, audioPath: audioPath);
        } catch (_) {}
      }
      return;
    }

    final r = await _prepareRegistro(prefs, entry, audioPath);
    String finalId = r.id;
    bool merged = false;
    String env = 'local';

    try {
      final result = await DataService.insertRegistroLlamadaWithCorrelation(r).timeout(const Duration(seconds: 60));
      finalId = result.registroId;
      merged = result.merged;
      env = 'API';
      await prefs.setString(_keyLastRegistroId, finalId);
    } catch (e) {
      final errMsg = e.toString().replaceFirst('Exception: ', '').split('\n').first;
      debugPrint('CallMonitor: API falló al guardar, usando SQLite local. Error: $errMsg');
      // Guardar en SQLite como respaldo y encolar reintento
      await DatabaseService.insertRegistroLlamada(r);
      await prefs.setString(_keyLastRegistroId, r.id);
      unawaited(_retrySync(r));
      // Registrar diagnóstico con el error visible
      await CallDiagnosticService.record(
        registroId: r.id,
        nombreContactado: r.nombreContactado,
        duracionMinutos: r.duracionMinutos,
        guardadoEnApi: false,
        merged: false,
        audioPath: audioPath,
        errorMsg: '⚠️ API ERROR: $errMsg\n\nLa llamada se guardó localmente y se reintentará. Verifique que la tabla "registro_llamadas" exista en el servidor.',
      );
      
      await prefs.setString(_keyLastProcessedId, entry.id ?? entry.timestamp.toString());
      await _notifyUser(finalId, r.nombreContactado, r.duracionMinutos, merged, env);
      CallSavingProgressService.notifyListo();
      return;
    }
    
    await prefs.setString(_keyLastProcessedId, entry.id ?? entry.timestamp.toString());
    await _notifyUser(finalId, r.nombreContactado, r.duracionMinutos, merged, env);
    
    // Registrar diagnóstico para mostrar en la UI
    await CallDiagnosticService.record(
      registroId: finalId,
      nombreContactado: r.nombreContactado,
      duracionMinutos: r.duracionMinutos,
      guardadoEnApi: env == 'API',
      merged: merged,
      audioPath: audioPath,
    );
    
    CallSavingProgressService.notifyListo();
  }

  static Future<CallLogEntry?> _pollForCallLog() async {
    for (var i = 0; i < 4; i++) {
      final entries = await CallLog.get();
      if (entries.isNotEmpty) {
        final last = entries.first;
        final diff = (DateTime.now().millisecondsSinceEpoch - (last.timestamp ?? 0)).abs();
        if (diff < 60000) return last;
      }
      if (i < 3) await Future.delayed(const Duration(seconds: 1));
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
    
    final results = await Future.wait([
      LocationService.getCurrentPosition().timeout(const Duration(seconds: 8)).catchError((_) => null),
      IpService.getPublicIp().timeout(const Duration(seconds: 6)).catchError((_) => null),
      supId != null ? DataService.getSupervisor(supId).catchError((_) => null) : Future.value(null),
      venId != null ? DataService.getVendedor(venId).catchError((_) => null) : Future.value(null),
    ]);

    final pos = results[0] as Position?;
    final ip = results[1] as String?;
    final sup = results[2] as Supervisor?;
    final ven = results[3] as Vendedor?;

    final name = sup?.nombre ?? ven?.nombre ?? prefs.getString('user_name') ?? 'Usuario';
    final p = sup?.telefono ?? ven?.telefono ?? prefs.getString('numero_telefono_propietario');
    final c = sup?.cargo ?? NivelCargo.values.firstWhere((e) => e.valor == prefs.getString('user_cargo'), orElse: () => NivelCargo.coach);

    return RegistroLlamada(
      id: 'llamada_${ts}_${PhoneUtils.normalize(p ?? "")}_${PhoneUtils.normalize(entry.number ?? "")}',
      fecha: DateTime.fromMillisecondsSinceEpoch(ts),
      horaInicio: DateTime.now().subtract(Duration(seconds: entry.duration ?? 0)),
      horaFin: DateTime.now(),
      duracionMinutos: dur,
      tipoLlamada: TipoLlamada.manana,
      cargoLider: c,
      zona: sup?.zona ?? ven?.zona ?? prefs.getString('user_zona') ?? '',
      nombreLider: name,
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

  static Future<void> _retrySync(RegistroLlamada r) async {
    unawaited(Future.delayed(const Duration(minutes: 1), () async {
      try { await DataService.insertRegistroLlamadaWithCorrelation(r); } catch (_) {}
    }));
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
