import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'api_service.dart';
import '../models/registro_llamada.dart';

class SyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;

  static void init() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => syncPendingData());
    // Primera ejecución tras un breve delay
    Future.delayed(const Duration(seconds: 30), () => syncPendingData());
    debugPrint('SyncService: iniciado (cada 5 minutos)');
  }

  static Future<void> syncPendingData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      await _syncLlamadas();
      await _syncAudios();
    } catch (e) {
      debugPrint('SyncService Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _syncLlamadas() async {
    final pending = await DatabaseService.getPendingLlamadas();
    if (pending.isEmpty) return;

    debugPrint('SyncService: Sincronizando ${pending.length} llamadas pendientes...');
    
    for (final map in pending) {
      try {
        final r = RegistroLlamada.fromMap(map);
        // Intentar insertar en API
        await ApiService.insertRegistroLlamada(r);
        // Marcar como sincronizado localmente
        await DatabaseService.markAsSincronizado(r.id);
        debugPrint('SyncService: Llamada ${r.id} sincronizada');
      } catch (e) {
        debugPrint('SyncService: Error sincronizando llamada ${map['id']}: $e');
        // No marcamos como sincronizado para reintentar después
      }
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
        // Si no hay path, marcar como sincronizado (o ignorar)
        await DatabaseService.markAudioAsSincronizado(id);
        continue;
      }

      try {
        final audioUrl = await ApiService.uploadAudioFile(id, path);
        if (audioUrl != null && audioUrl.isNotEmpty) {
          await ApiService.updateRegistroLlamadaRutaGrabacion(id, audioUrl);
          await DatabaseService.markAudioAsSincronizado(id);
          debugPrint('SyncService: Audio de llamada $id sincronizado');
        }
      } catch (e) {
        debugPrint('SyncService: Error sincronizando audio de llamada $id: $e');
      }
    }
  }
}
