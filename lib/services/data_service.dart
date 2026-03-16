import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import '../config/api_config.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'demo_data_service.dart';
import 'debug_alert_service.dart';

/// Abstraction to use either SQLite (local) or API (SQL Server)
/// useDemoData = true → datos de demostración para presentaciones
class DataService {
  static bool useDemoData = false;
  static bool get _useApi => ApiConfig.useRemoteApi;
  static String get userRegistrationDestination =>
      _useApi
          ? 'API remota (${ApiConfig.baseUrl})'
          : 'SQLite local (base interna del dispositivo)';

  static Future<void> init() async {
    if (_useApi) {
      DebugAlertService.info('Fuente de datos: API remota (${ApiConfig.baseUrl})');
      return;
    }
    DebugAlertService.warning('Fuente de datos: SQLite local');
    await DatabaseService.database;
  }

  static Future<List<Vendedor>> getVendedores() async {
    if (useDemoData) return DemoDataService.getVendedores();
    if (!_useApi) return DatabaseService.getVendedores();
    try {
      final list = await ApiService.getVendedores();
      // Refresh local cache with latest from API
      if (list.isNotEmpty) {
        for (final v in list) {
          try { await DatabaseService.insertVendedor(v); } catch (_) {}
        }
      }
      return list;
    } catch (e) {
      DebugAlertService.warning('API caída, usando caché local: ${e.toString().split('\n').first}');
      return DatabaseService.getVendedores();
    }
  }

  static Future<Vendedor?> getVendedor(String id) async {
    if (useDemoData) {
      final list = DemoDataService.getVendedores();
      try { return list.firstWhere((v) => v.id == id); } catch (_) { return null; }
    }
    if (!_useApi) return DatabaseService.getVendedor(id);
    try {
      return await ApiService.getVendedor(id);
    } catch (e) {
      DebugAlertService.warning('API caída, usando caché local para vendedor $id');
      return DatabaseService.getVendedor(id);
    }
  }

  static Future<List<Supervisor>> getSupervisores() async {
    if (useDemoData) return DemoDataService.getSupervisores();
    if (!_useApi) return DatabaseService.getSupervisores();
    try {
      final list = await ApiService.getSupervisores();
      // Refresh local cache with latest from API
      if (list.isNotEmpty) {
        for (final s in list) {
          try { await DatabaseService.insertSupervisor(s); } catch (_) {}
        }
      }
      return list;
    } catch (e) {
      DebugAlertService.warning('API caída, usando caché local: ${e.toString().split('\n').first}');
      return DatabaseService.getSupervisores();
    }
  }

  static Future<Supervisor?> getSupervisor(String id) async {
    if (useDemoData) {
      final list = DemoDataService.getSupervisores();
      try { return list.firstWhere((s) => s.id == id); } catch (_) { return null; }
    }
    if (!_useApi) return DatabaseService.getSupervisor(id);
    try {
      return await ApiService.getSupervisor(id);
    } catch (e) {
      DebugAlertService.warning('API caída, usando caché local para supervisor $id');
      return DatabaseService.getSupervisor(id);
    }
  }

  static Future<void> insertSupervisor(Supervisor s) async {
    final destino = _useApi
        ? 'API ${ApiConfig.baseUrl}/supervisores'
        : 'SQLite local (tabla supervisores)';
    DebugAlertService.info('Registrando ${s.cargo.displayName} en: $destino');
    if (_useApi) {
      try {
        await ApiService.insertSupervisor(s);
        await DatabaseService.insertSupervisor(s);
      } catch (e) {
        // Cache local para no perder el alta aunque la API tarde/falle.
        await DatabaseService.insertSupervisor(s);
        DebugAlertService.warning('API inactiva, guardado offline: ${e.toString().split('\n').first}');
      }
    } else {
      await DatabaseService.insertSupervisor(s);
    }
    DebugAlertService.success('${s.cargo.displayName} guardado en: $destino');
  }

  static Future<void> insertVendedor(Vendedor v) async {
    final destino = _useApi
        ? 'API ${ApiConfig.baseUrl}/vendedores'
        : 'SQLite local (tabla vendedores)';
    DebugAlertService.info('Registrando vendedor en: $destino');
    if (_useApi) {
      try {
        await ApiService.insertVendedor(v);
        await DatabaseService.insertVendedor(v);
      } catch (e) {
        // Cache local para no perder el alta aunque la API tarde/falle.
        await DatabaseService.insertVendedor(v);
        DebugAlertService.warning('API inactiva, guardado offline: ${e.toString().split('\n').first}');
      }
    } else {
      await DatabaseService.insertVendedor(v);
    }
    DebugAlertService.success('Vendedor guardado en: $destino');
  }

  static Future<void> deleteSupervisor(String id) =>
      _useApi ? ApiService.deleteSupervisor(id) : DatabaseService.deleteSupervisor(id);

  static Future<void> deleteVendedor(String id) =>
      _useApi ? ApiService.deleteVendedor(id) : DatabaseService.deleteVendedor(id);

  static Future<List<RegistroLlamada>> getRegistroLlamadas({
    DateTime? desde,
    DateTime? hasta,
    String? zona,
    String? nombreContactado,
  }) async {
    if (useDemoData) {
      return DemoDataService.getRegistroLlamadas(desde: desde, hasta: hasta);
    }
    if (!_useApi) {
      return DatabaseService.getRegistroLlamadas(
        desde: desde,
        hasta: hasta,
        zona: zona,
        nombreContactado: nombreContactado,
      );
    }
    List<RegistroLlamada> apiList = [];
    List<RegistroLlamada> localList = [];
    try {
      apiList = await ApiService.getRegistroLlamadas(
        desde: desde,
        hasta: hasta,
        zona: zona,
        nombreContactado: nombreContactado,
      );
    } catch (e) {
      DebugAlertService.warning('API llamadas falló: $e');
    }
    try {
      localList = await DatabaseService.getRegistroLlamadas(
        desde: desde,
        hasta: hasta,
        zona: zona,
        nombreContactado: nombreContactado,
      );
    } catch (e) {
      DebugAlertService.warning('SQLite llamadas: $e');
    }
    final apiIds = apiList.map((l) => l.id).toSet();
    final soloLocales = localList.where((l) => !apiIds.contains(l.id)).toList();
    final merged = [...apiList, ...soloLocales];
    merged.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
    return merged;
  }

  static Future<void> insertRegistroLlamada(RegistroLlamada r) async {
    final destino = _useApi ? 'API ${ApiConfig.baseUrl}/llamadas' : 'SQLite local';
    DebugAlertService.info('Intentando guardar llamada en: $destino');
    if (_useApi) {
      try {
        await ApiService.insertRegistroLlamada(r);
        // También guardamos localmente como backup proactivo
        await DatabaseService.insertRegistroLlamada(r);
        DebugAlertService.success('Llamada registrada: ${r.nombreContactado}');
      } catch (e) {
        final errorMsg = e.toString().contains('Exception:') 
            ? e.toString().split('Exception:').last 
            : e.toString();
        DebugAlertService.error('Fallo API: $errorMsg');
        DebugAlertService.warning('Guardando en SQLite local como backup...');
        await DatabaseService.insertRegistroLlamada(r);
      }
    } else {
      await DatabaseService.insertRegistroLlamada(r);
      DebugAlertService.success('Llamada registrada localmente');
    }
  }

  /// Inserta con correlación dual (punto A + punto B). Retorna (registroId, merged).
  static Future<({String registroId, bool merged})> insertRegistroLlamadaWithCorrelation(RegistroLlamada r) async {
    if (_useApi) {
      try {
        final result = await ApiService.insertRegistroLlamadaWithCorrelation(r);
        if (result.merged && r.rutaGrabacion != null && r.rutaGrabacion!.isNotEmpty) {
          try {
            await ApiService.uploadAudioPuntoB(result.registroId, r.rutaGrabacion!);
          } catch (e) {
            DebugAlertService.warning('No se pudo subir audio punto B: $e');
          }
        }
        return result;
      } catch (e) {
        final errorMsg = e.toString().contains('Exception:') 
            ? e.toString().split('Exception:').last 
            : e.toString();
        DebugAlertService.error('Error Correlación API: $errorMsg');
        rethrow;
      }
    }
    await DatabaseService.insertRegistroLlamada(r);
    return (registroId: r.id, merged: false);
  }

  static Future<RegistroLlamada?> getRegistroLlamada(String id) =>
      _useApi ? ApiService.getRegistroLlamada(id) : DatabaseService.getRegistroLlamada(id);

  static Future<void> updateRegistroLlamadaObservaciones(
      String id, String observaciones) async {
    final destino = _useApi ? 'API ${ApiConfig.baseUrl}/llamadas/$id' : 'SQLite local';
    DebugAlertService.info('Actualizando observaciones en: $destino');
    await (_useApi
        ? ApiService.updateRegistroLlamadaObservaciones(id, observaciones)
        : DatabaseService.updateRegistroLlamadaObservaciones(id, observaciones));
    DebugAlertService.success('Observaciones guardadas');
  }

  static Future<void> updateRegistroLlamadaTranscripcion(
      String id, String transcripcionTexto) async {
    await (_useApi
        ? ApiService.updateRegistroLlamadaTranscripcion(id, transcripcionTexto)
        : DatabaseService.updateRegistroLlamadaTranscripcion(id, transcripcionTexto));
  }

  static Future<void> updateRegistroLlamadaRutaGrabacion(
      String id, String rutaGrabacion) async {
    await (_useApi
        ? ApiService.updateRegistroLlamadaRutaGrabacion(id, rutaGrabacion)
        : DatabaseService.updateRegistroLlamadaRutaGrabacion(id, rutaGrabacion));
  }

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) async {
    if (useDemoData) return DemoDataService.getPpvcByFecha(fecha);
    return _useApi ? ApiService.getPpvcByFecha(fecha) : DatabaseService.getPpvcByFecha(fecha);
  }

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) async {
    if (useDemoData) return DemoDataService.getRvcByFecha(fecha);
    return _useApi ? ApiService.getRvcByFecha(fecha) : DatabaseService.getRvcByFecha(fecha);
  }

  static Future<List<Alerta>> getAlertasPendientes() async {
    if (useDemoData) return DemoDataService.getAlertasPendientes();
    return _useApi ? ApiService.getAlertasPendientes() : DatabaseService.getAlertasPendientes();
  }

  static Future<void> insertAlerta(Alerta a) =>
      _useApi ? ApiService.insertAlerta(a) : DatabaseService.insertAlerta(a);

  static Future<void> guardarUbicacion({
    required String vendedorId,
    required double lat,
    required double lng,
  }) async {
    await (_useApi
        ? ApiService.guardarUbicacion(vendedorId: vendedorId, lat: lat, lng: lng)
        : DatabaseService.guardarUbicacion(vendedorId: vendedorId, lat: lat, lng: lng));
  }

  static Future<void> uploadAudioPuntoB(String registroId, String rutaAudio) async {
    if (_useApi) {
      await ApiService.uploadAudioPuntoB(registroId, rutaAudio);
    }
  }
}
