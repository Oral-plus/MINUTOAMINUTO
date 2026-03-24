import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'transcription_service.dart';

/// Singleton que gestiona la cola de transcripciones automáticas.
/// Rastrea el progreso por registroId y actualiza la notificación
/// del servicio en primer plano para que Android no mate el proceso.
class TranscriptionManager extends ChangeNotifier {
  static final instance = TranscriptionManager._();
  TranscriptionManager._();

  // 0.0–1.0 mientras procesa, -1.0 si error
  final Map<String, double> _progress = {};
  // IDs completados exitosamente en esta sesión
  final Set<String> _done = {};

  bool isPending(String id) => _progress.containsKey(id) && (_progress[id]! >= 0);
  bool isDone(String id) => _done.contains(id);
  bool isError(String id) => (_progress[id] ?? 0) < 0;
  double getProgress(String id) => (_progress[id] ?? 0).clamp(0.0, 1.0);
  int get pendingCount => _progress.values.where((v) => v >= 0).length;

  /// Encola una transcripción. No hace nada si ya está en cola o completada.
  void enqueue(String registroId, String rutaAudio) {
    if (_progress.containsKey(registroId) || _done.contains(registroId)) return;
    _progress[registroId] = 0.05;
    notifyListeners();
    _run(registroId, rutaAudio);
  }

  /// Vuelve a intentar un registro que falló.
  void retry(String registroId, String rutaAudio) {
    _progress.remove(registroId);
    enqueue(registroId, rutaAudio);
  }

  Future<void> _run(String registroId, String rutaAudio) async {
    _updateNotification('Transcribiendo grabación en segundo plano...');
    Timer? timer;
    try {
      timer = Timer.periodic(const Duration(seconds: 5), (_) {
        final cur = _progress[registroId];
        if (cur != null && cur >= 0 && cur < 0.88) {
          _progress[registroId] = (cur + 0.05).clamp(0.0, 0.88);
          notifyListeners();
        }
      });

      await TranscriptionService.transcribeAndSave(
        registroId: registroId,
        rutaAudio: rutaAudio,
      );

      timer.cancel();
      _progress.remove(registroId);
      _done.add(registroId);
      notifyListeners();
    } catch (_) {
      timer?.cancel();
      _progress[registroId] = -1.0;
      notifyListeners();
    } finally {
      if (pendingCount == 0) {
        _updateNotification('Registrando y grabando llamadas automáticamente.');
      }
    }
  }

  static Future<void> _updateNotification(String text) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Minuto a Minuto',
          notificationText: text,
        );
      }
    } catch (_) {}
  }
}
