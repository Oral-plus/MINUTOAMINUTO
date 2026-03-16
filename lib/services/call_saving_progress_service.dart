import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Etapas del proceso de guardado post-llamada.
enum SavingStage {
  idle,
  finalizandoGrabacion,
  guardandoDatos,
  subiendoAudio,
  transcribiendo,
  listo,
  error,
}

class CallSavingProgress {
  final SavingStage stage;
  final double percent; // 0.0 – 1.0
  final String message;

  const CallSavingProgress({
    required this.stage,
    required this.percent,
    required this.message,
  });

  bool get isActive =>
      stage != SavingStage.idle &&
      stage != SavingStage.listo &&
      stage != SavingStage.error;

  bool get isDone =>
      stage == SavingStage.listo || stage == SavingStage.error;
}

/// Servicio singleton que emite el progreso de guardado de la llamada.
/// CallMonitorService lo actualiza; la UI lo escucha.
class CallSavingProgressService {
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static final _controller =
      StreamController<CallSavingProgress>.broadcast();

  static Stream<CallSavingProgress> get stream => _controller.stream;

  static CallSavingProgress _current = const CallSavingProgress(
    stage: SavingStage.idle,
    percent: 0,
    message: '',
  );

  static CallSavingProgress get current => _current;

  static void _emit(CallSavingProgress p) {
    if (!_isAndroid) return;
    _current = p;
    if (!_controller.isClosed) _controller.add(p);
  }

  static void reset() => _emit(const CallSavingProgress(
        stage: SavingStage.idle,
        percent: 0,
        message: '',
      ));

  static void notifyFinalizandoGrabacion() => _emit(const CallSavingProgress(
        stage: SavingStage.finalizandoGrabacion,
        percent: 0.10,
        message: 'Finalizando grabación...',
      ));

  static void notifyGuardandoDatos() => _emit(const CallSavingProgress(
        stage: SavingStage.guardandoDatos,
        percent: 0.35,
        message: 'Guardando datos de la llamada...',
      ));

  static void notifySubiendoAudio(double progress, {String? cruceCon}) {
    final base = cruceCon != null && cruceCon.isNotEmpty
        ? 'Cruce con $cruceCon - Subiendo tu audio'
        : 'Subiendo grabación';
    _emit(CallSavingProgress(
      stage: SavingStage.subiendoAudio,
      percent: 0.40 + (progress * 0.45).clamp(0, 0.45),
      message: '$base... ${(progress * 100).toInt()}%',
    ));
  }

  /// Indica que se detectó cruce (la otra persona también tiene la app).
  static void notifyCruceDetectado(String contacto) => _emit(CallSavingProgress(
        stage: SavingStage.guardandoDatos,
        percent: 0.50,
        message: 'Cruce detectado con $contacto — ambas partes con la app',
      ));

  static void notifyTranscribiendo() => _emit(const CallSavingProgress(
        stage: SavingStage.transcribiendo,
        percent: 0.90,
        message: 'Transcribiendo con IA...',
      ));

  static void notifyListo({bool cruce = false}) {
    final msg = cruce
        ? '¡Llamada guardada! Cruce A+B completado (ambas partes con la app)'
        : '¡Llamada guardada!';
    _emit(CallSavingProgress(
      stage: SavingStage.listo,
      percent: 1.0,
      message: msg,
    ));
    // Auto-reset después de 3 segundos
    Future.delayed(const Duration(seconds: 3), reset);
  }

  static void notifyError(String msg) {
    _emit(CallSavingProgress(
      stage: SavingStage.error,
      percent: 0,
      message: msg,
    ));
    Future.delayed(const Duration(seconds: 4), reset);
  }

  static void dispose() {
    _controller.close();
  }
}
