import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'api_service.dart';
import '../models/registro_llamada.dart';

class SyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  // Contador en memoria: ID → número de fallos consecutivos. Tras 10 fallos se salta.
  static final Map<String, int> _failCount = {};

  static void init() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) => syncPendingData());
    // Primera ejecución: repara + sube todo (limpia contadores de fallos)
    Future.delayed(const Duration(seconds: 5), () => repararYSincronizar());
    debugPrint('SyncService: iniciado (cada 1 minuto)');
  }

  static Future<int> getPendingCount() async {
    final pending = await DatabaseService.getPendingLlamadas();
    final audios = await DatabaseService.getPendingAudios();
    return pending.length + audios.length;
  }

  static Future<void> syncPendingData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // Reparar campos vacíos antes de intentar subir
      final reparadas = await DatabaseService.repararPendientes();
      if (reparadas > 0) debugPrint('SyncService: $reparadas llamadas reparadas antes de sync');
      await _syncLlamadas();
      await _syncAudios();
    } catch (e) {
      debugPrint('SyncService Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Repara + sube todo forzado, ignorando el contador de fallos.
  static Future<int> repararYSincronizar() async {
    _failCount.clear();
    await DatabaseService.repararPendientes();
    await syncPendingData();
    return await getPendingCount();
  }

  static Future<void> _syncLlamadas() async {
    final pending = await DatabaseService.getPendingLlamadas();
    if (pending.isEmpty) return;

    debugPrint('SyncService: Sincronizando ${pending.length} llamadas pendientes...');

    for (final map in pending) {
      final id = map['id'] as String? ?? '';
      if ((_failCount[id] ?? 0) >= 10) {
        debugPrint('SyncService: Llamada $id ignorada tras 10 fallos');
        continue;
      }
      bool synced = false;
      for (int attempt = 0; attempt < 3 && !synced; attempt++) {
        try {
          final r = RegistroLlamada.fromMap(map);
          await ApiService.insertRegistroLlamada(r);
          await DatabaseService.markAsSincronizado(r.id);
          _failCount.remove(id);
          debugPrint('SyncService: Llamada $id sincronizada (intento ${attempt + 1})');
          synced = true;
        } catch (e) {
          debugPrint('SyncService: Intento ${attempt + 1} fallido para $id: $e');
          if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
        }
      }
      if (!synced) _failCount[id] = (_failCount[id] ?? 0) + 1;
    }
  }

  static Future<void> _syncAudios() async {
    final pending = await DatabaseService.getPendingAudios();
    if (pending.isEmpty) return;

    debugPrint('SyncService: Sincronizando ${pending.length} audios pendientes...');

    for (final map in pending) {
      final id = map['id'] as String;
      final path = map['rutaGrabacion'] as String?;

      if (path == null || path.isEmpty) {
        await DatabaseService.markAudioAsSincronizado(id);
        continue;
      }

      bool synced = false;
      for (int attempt = 0; attempt < 3 && !synced; attempt++) {
        try {
          final audioUrl = await ApiService.uploadAudioFile(id, path);
          if (audioUrl != null && audioUrl.isNotEmpty) {
            await ApiService.updateRegistroLlamadaRutaGrabacion(id, audioUrl);
            await DatabaseService.markAudioAsSincronizado(id);
            debugPrint('SyncService: Audio de llamada $id sincronizado (intento ${attempt + 1})');
            synced = true;
          }
        } catch (e) {
          debugPrint('SyncService: Intento ${attempt + 1} fallido audio $id: $e');
          if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }
}
