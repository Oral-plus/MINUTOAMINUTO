import 'dart:async';
import 'dart:io' show Platform;
import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_phone_call_state/flutter_phone_call_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/registro_llamada.dart';
import '../models/supervisor.dart';
import '../models/tipo_llamada.dart';
import '../models/nivel_cargo.dart';
import 'data_service.dart';

/// Mantiene la app en segundo plano y detecta llamadas del marcador del teléfono.
/// Al terminar una llamada, crea automáticamente un registro.
class CallMonitorService {
  static const _keyEnabled = 'call_monitor_enabled';
  static const _keyLastProcessedId = 'call_monitor_last_id';
  static StreamSubscription? _callStateSub;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    final p1 = await Permission.phone.request();
    final p2 = await Permission.callLog.request();
    return p1.isGranted && p2.isGranted;
  }

  static Future<bool> hasPermissions() async {
    if (!Platform.isAndroid) return false;
    return await Permission.phone.isGranted && await Permission.callLog.isGranted;
  }

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    final enabled = await isEnabled();
    if (!enabled) return;
    await _startMonitoring();
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    final ok = await requestPermissions();
    if (!ok) {
      debugPrint('CallMonitor: permisos denegados');
      return;
    }
    await setEnabled(true);
    await _startMonitoring();
  }

  static Future<void> stop() async {
    await setEnabled(false);
    await _callStateSub?.cancel();
    _callStateSub = null;
    await FlutterForegroundTask.stopService();
  }

  static Future<void> _startMonitoring() async {
    _initForegroundTask();
    FlutterForegroundTask.startService(
      notificationTitle: 'Minuto a Minuto',
      notificationText: 'Monitoreando llamadas del teléfono',
    );
    if (Platform.isAndroid) {
      PhoneCallState.instance.startMonitorService();
    }
    _listenToCallState();
  }

  static void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'minutoaminuto_call_monitor',
        channelName: 'Monitor de llamadas',
        channelDescription: 'Mantiene la app activa para detectar llamadas del teléfono',
      ),
    );
  }

  static void _listenToCallState() {
    _callStateSub?.cancel();
    _callStateSub = PhoneCallState.instance.phoneStateChange.listen((event) {
      if (event.state == CallState.end) {
        _onCallEnded();
      }
    });
  }

  static Future<void> _onCallEnded() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final entries = await CallLog.get();
      if (entries.isEmpty) return;
      final last = entries.first;
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_keyLastProcessedId);
      final id = '${last.timestamp}_${last.number}_${last.duration}';
      if (lastId == id) return;
      await prefs.setString(_keyLastProcessedId, id);

      final duration = last.duration != null && last.duration! > 0
          ? (last.duration! / 60).ceil()
          : 1;
      if (duration < 1) return;

      final ts = last.timestamp ?? DateTime.now().millisecondsSinceEpoch;
      final fecha = DateTime.fromMillisecondsSinceEpoch(ts);
      final fin = DateTime.now();
      final inicio = fin.subtract(Duration(seconds: last.duration ?? 60));

      final nombreContactado = (last.name?.isNotEmpty == true)
          ? last.name!
          : (last.number ?? 'Desconocido');

      Supervisor? sup;
      final supId = prefs.getString('supervisor_id');
      if (supId != null) sup = await DataService.getSupervisor(supId);

      final r = RegistroLlamada(
        id: const Uuid().v4(),
        fecha: fecha,
        horaInicio: inicio,
        horaFin: fin,
        duracionMinutos: duration,
        tipoLlamada: TipoLlamada.manana,
        cargoLider: sup?.cargo ?? NivelCargo.coach,
        zona: sup?.zona ?? '',
        nombreLider: sup?.nombre ?? 'Supervisor',
        nombreContactado: nombreContactado,
        confirmacionVeracidad: true,
        observaciones: 'Llamada detectada del marcador del teléfono',
      );

      await DataService.insertRegistroLlamada(r);
      debugPrint('CallMonitor: registro creado para $nombreContactado');
    } catch (e, st) {
      debugPrint('CallMonitor error: $e $st');
    }
  }
}
