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
  // Caché del texto de transcripción para acceso inmediato sin recargar de la BD
  final Map<String, String> _texts = {};

  bool isPending(String id) => _progress.containsKey(id) && (_progress[id]! >= 0);
  bool isDone(String id) => _done.contains(id);
  bool isError(String id) => (_progress[id] ?? 0) < 0;
  double getProgress(String id) => (_progress[id] ?? 0).clamp(0.0, 1.0);
  int get pendingCount => _progress.values.where((v) => v >= 0).length;

  /// Devuelve el texto de transcripción cacheado en memoria (si existe).
  String? getText(String id) {
    final t = _texts[id];
    return (t != null && t.isNotEmpty) ? t : null;
  }

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
    _done.remove(registroId);
    _texts.remove(registroId);
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

      String? text;
      // Reintentar hasta 3 veces con delays crecientes
      for (var attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          debugPrint('TranscriptionManager: reintento $attempt para $registroId');
          await Future.delayed(Duration(seconds: 5 + attempt * 10));
        }
        try {
          text = await TranscriptionService.transcribeAndSave(
            registroId: registroId,
            rutaAudio: rutaAudio,
          );
          if (text != null && text.isNotEmpty) break;
          debugPrint('TranscriptionManager: intento $attempt devolvió null/vacío para $registroId');
        } catch (e) {
          debugPrint('TranscriptionManager: error intento $attempt para $registroId: $e');
          if (attempt == 2) rethrow;
        }
      }

      timer.cancel();
      if (text != null && text.isNotEmpty) {
        _progress.remove(registroId);
        _done.add(registroId);
        _texts[registroId] = text;
        debugPrint('TranscriptionManager: ✅ transcripción guardada para $registroId (${text.length} chars)');
      } else {
        debugPrint('TranscriptionManager: ❌ sin resultado tras 3 intentos para $registroId');
        _progress[registroId] = -1.0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('TranscriptionManager: ❌ error fatal para $registroId: $e');
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
