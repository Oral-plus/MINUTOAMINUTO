import 'package:flutter/foundation.dart';
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
    return ApiService.getVendedores();
  }

  static Future<Vendedor?> getVendedor(String id) async {
    if (useDemoData) {
      final list = DemoDataService.getVendedores();
      try { return list.firstWhere((v) => v.id == id); } catch (_) { return null; }
    }
    if (!_useApi) return DatabaseService.getVendedor(id);
    return ApiService.getVendedor(id);
  }

  static Future<List<Supervisor>> getSupervisores() async {
    if (useDemoData) return DemoDataService.getSupervisores();
    if (!_useApi) return DatabaseService.getSupervisores();
    return ApiService.getSupervisores();
  }

  static Future<Supervisor?> getSupervisor(String id) async {
    if (useDemoData) {
      final list = DemoDataService.getSupervisores();
      try { return list.firstWhere((s) => s.id == id); } catch (_) { return null; }
    }
    if (!_useApi) return DatabaseService.getSupervisor(id);
    return ApiService.getSupervisor(id);
  }

  static Future<void> insertSupervisor(Supervisor s) async {
    final destino = _useApi
        ? 'API ${ApiConfig.baseUrl}/supervisores'
        : 'SQLite local (tabla supervisores)';
    DebugAlertService.info('Registrando ${s.cargo.displayName} en: $destino');
    if (_useApi) {
      await ApiService.insertSupervisor(s);
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
      await ApiService.insertVendedor(v);
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
    // Intentar API primero, luego combinar con local
    List<RegistroLlamada> apiList = [];
    List<RegistroLlamada> localList = [];
    bool apiSuccess = false;
    
    if (_useApi) {
      try {
        apiList = await ApiService.getRegistroLlamadas(
          desde: desde,
          hasta: hasta,
          zona: zona,
          nombreContactado: nombreContactado,
        );
        apiSuccess = true;
      } catch (e) {
        debugPrint('DataService: Error al cargar llamadas de API: $e');
        apiSuccess = false;
      }
    }
    
    // Siempre cargar locales
    try {
      localList = await DatabaseService.getRegistroLlamadas(
        desde: desde,
        hasta: hasta,
        zona: zona,
        nombreContactado: nombreContactado,
      );
    } catch (_) {}
    
    if (apiSuccess) {
      // SI LA API FUNCIONA, ELLA ES LA FUENTE DE VERDAD.
      // 1. Tomamos todo lo de la API (son las sincronizadas)
      //    — pero si el registro API no tiene transcripción y la local sí, la fusionamos.
      // 2. Agregamos de local SOLO las que no están sincronizadas aún (sincronizado == 0)
      //    Esto permite ver las llamadas recién hechas "fuera de línea" pero oculta
      //    caché vieja que ya no existe en el servidor.
      final localById = { for (final e in localList) e.id: e };
      final idsApi = apiList.map((e) => e.id).toSet();
      final merged = [
        ...apiList.map((a) {
          final local = localById[a.id];
          if (local == null) return a;
          // Fusionar campos que la local puede tener y la API no
          final m = a.toMap();
          bool changed = false;
          // Transcripción
          if ((a.transcripcionTexto == null || a.transcripcionTexto!.isEmpty) &&
              local.transcripcionTexto != null && local.transcripcionTexto!.isNotEmpty) {
            m['transcripcionTexto'] = local.transcripcionTexto;
            changed = true;
          }
          // Coordenadas GPS
          if ((a.latitud == null || a.latitud == 0) && local.latitud != null && local.latitud != 0) {
            m['latitud'] = local.latitud;
            m['longitud'] = local.longitud;
            changed = true;
          }
          // Ruta de grabación (la local puede tener la ruta de archivo mientras
          // la API aún no recibió el upload o solo tiene la URL del servidor)
          if ((a.rutaGrabacion == null || a.rutaGrabacion!.isEmpty) &&
              local.rutaGrabacion != null && local.rutaGrabacion!.isNotEmpty) {
            m['rutaGrabacion'] = local.rutaGrabacion;
            changed = true;
          }
          // Ruta punto B
          if ((a.rutaGrabacionPuntoB == null || a.rutaGrabacionPuntoB!.isEmpty) &&
              local.rutaGrabacionPuntoB != null && local.rutaGrabacionPuntoB!.isNotEmpty) {
            m['rutaGrabacionPuntoB'] = local.rutaGrabacionPuntoB;
            changed = true;
          }
          return changed ? RegistroLlamada.fromMap(m) : a;
        }),
        ...localList.where((e) => e.sincronizado == 0 && !idsApi.contains(e.id)),
      ];
      merged.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
      return merged;
    } else {
      // Si la API falla, mostramos todo lo local (mejor ver algo a nada)
      final ids = apiList.map((e) => e.id).toSet();
      final merged = [...apiList, ...localList.where((e) => !ids.contains(e.id))];
      merged.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
      return merged;
    }
  }

  static Future<({String savedTo, String registroId, bool hasGps, bool retrying})> insertRegistroLlamada(RegistroLlamada r) async {
    final destino = _useApi ? 'API ${ApiConfig.baseUrl}/llamadas' : 'SQLite local';
    DebugAlertService.info('Guardando llamada en: $destino');
    if (_useApi) {
      try {
        await ApiService.insertRegistroLlamada(r);
        await DatabaseService.insertRegistroLlamada(r, sincronizado: 1);
        DebugAlertService.success('Llamada guardada en servidor: ${r.nombreContactado}');
        return (
          savedTo: ApiConfig.baseUrl,
          registroId: r.id,
          hasGps: r.latitud != null,
          retrying: false,
        );
      } catch (e) {
        // API falló → guardar localmente como pendiente de sincronización
        DebugAlertService.warning('API no disponible, guardando localmente (pendiente): $e');
        await DatabaseService.insertRegistroLlamada(r, sincronizado: 0);
        DebugAlertService.success('Llamada guardada localmente');
        return (savedTo: 'SQLite local (pendiente)', registroId: r.id, hasGps: r.latitud != null, retrying: false);
      }
    } else {
      await DatabaseService.insertRegistroLlamada(r);
      DebugAlertService.success('Llamada registrada localmente');
      return (savedTo: 'SQLite local', registroId: r.id, hasGps: r.latitud != null, retrying: false);
    }
  }

  /// Inserta con correlación dual (punto A + punto B). Retorna (registroId, merged).
  /// Solo guarda en la API remota. Si no hay API configurada, lanza error.
  static Future<({String registroId, bool merged})> insertRegistroLlamadaWithCorrelation(RegistroLlamada r) async {
    if (!_useApi) {
      // Sin API, guardar localmente
      await DatabaseService.insertRegistroLlamada(r);
      DebugAlertService.success('Llamada guardada localmente (sin API)');
      return (registroId: r.id, merged: false);
    }
    try {
      final result = await ApiService.insertRegistroLlamadaWithCorrelation(r);
      // Guardar localmente como sincronizado.
      // CLAVE: si hubo merge, guardar con el ID del merge target para que
      // las actualizaciones posteriores (transcripción, audio URL) lo encuentren.
      final localRecord = result.merged
          ? RegistroLlamada.fromMap({...r.toMap(), 'id': result.registroId})
          : r;
      try {
        await DatabaseService.insertRegistroLlamada(localRecord, sincronizado: 1);
      } catch (_) {
        // Si ya existe (ej: el punto A ya lo guardó), actualizar campos clave
        try {
          if (r.latitud != null && r.latitud != 0) {
            final db = await DatabaseService.database;
            await db.update('registro_llamadas',
              {'latitud': r.latitud, 'longitud': r.longitud, 'rutaGrabacion': r.rutaGrabacion},
              where: 'id = ?', whereArgs: [result.registroId]);
          }
        } catch (_) {}
      }
      
      if (result.merged && r.rutaGrabacion != null && r.rutaGrabacion!.isNotEmpty) {
        try {
          await ApiService.uploadAudioPuntoB(result.registroId, r.rutaGrabacion!);
          await DatabaseService.markAudioAsSincronizado(result.registroId);
        } catch (e) {
          DebugAlertService.warning('No se pudo subir audio punto B: $e');
        }
      }
      return result;
    } catch (e) {
      // API falló → fallback a local pendiente
      DebugAlertService.warning('API no disponible para correlación, guardando localmente (pendiente)');
      try {
        await DatabaseService.insertRegistroLlamada(r, sincronizado: 0);
        DebugAlertService.success('Llamada guardada localmente');
        return (registroId: r.id, merged: false);
      } catch (localErr) {
        DebugAlertService.error('Error guardando localmente: $localErr');
        rethrow;
      }
    }
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
    // Always save locally for offline access and fast reload
    try {
      await DatabaseService.updateRegistroLlamadaTranscripcion(id, transcripcionTexto);
    } catch (e) {
      debugPrint('DataService: error guardando transcripcion en DB local: $e');
    }
    if (_useApi) {
      try {
        await ApiService.updateRegistroLlamadaTranscripcion(id, transcripcionTexto);
      } catch (e) {
        debugPrint('DataService: error guardando transcripcion en API: $e');
      }
    }
  }

  static Future<void> updateRegistroLlamadaRutaGrabacion(
      String id, String rutaGrabacion) async {
    // Always save locally for offline playback
    try {
      await DatabaseService.updateRegistroLlamadaRutaGrabacion(id, rutaGrabacion);
    } catch (e) {
      debugPrint('DataService: error guardando rutaGrabacion en DB local: $e');
    }
    if (_useApi) {
      try {
        await ApiService.updateRegistroLlamadaRutaGrabacion(id, rutaGrabacion);
      } catch (e) {
        debugPrint('DataService: error guardando rutaGrabacion en API: $e');
      }
    }
  }

  static Future<void> updateRegistroLlamadaCumplioMeta(
      String id, bool cumplioMeta) async {
    if (!_useApi) return;
    await ApiService.updateRegistroLlamadaCumplioMeta(id, cumplioMeta);
  }

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) async {
    if (useDemoData) return DemoDataService.getPpvcByFecha(fecha);
    return _useApi ? ApiService.getPpvcByFecha(fecha) : DatabaseService.getPpvcByFecha(fecha);
  }

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) async {
    if (useDemoData) return DemoDataService.getRvcByFecha(fecha);
    return _useApi ? ApiService.getRvcByFecha(fecha) : DatabaseService.getRvcByFecha(fecha);
  }

  static Future<List<Alerta>> getAlertasPendientes({String? supervisorId}) async {
    if (useDemoData) return DemoDataService.getAlertasPendientes();
    return _useApi
        ? ApiService.getAlertasPendientes(supervisorId: supervisorId)
        : DatabaseService.getAlertasPendientes();
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
