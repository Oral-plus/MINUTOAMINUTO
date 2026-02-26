import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import '../config/api_config.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'debug_alert_service.dart';

/// Abstraction to use either SQLite (local) or API (SQL Server)
class DataService {
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

  static Future<List<Vendedor>> getVendedores() =>
      _useApi ? ApiService.getVendedores() : DatabaseService.getVendedores();

  static Future<Vendedor?> getVendedor(String id) =>
      _useApi ? ApiService.getVendedor(id) : DatabaseService.getVendedor(id);

  static Future<List<Supervisor>> getSupervisores() =>
      _useApi ? ApiService.getSupervisores() : DatabaseService.getSupervisores();

  static Future<Supervisor?> getSupervisor(String id) =>
      _useApi ? ApiService.getSupervisor(id) : DatabaseService.getSupervisor(id);

  static Future<void> insertSupervisor(Supervisor s) async {
    final destino = _useApi
        ? 'API ${ApiConfig.baseUrl}/supervisores'
        : 'SQLite local (tabla supervisores)';
    DebugAlertService.info('Registrando ${s.cargo.displayName} en: $destino');
    if (_useApi) {
      try {
        await ApiService.insertSupervisor(s);
        await DatabaseService.insertSupervisor(s);
      } catch (_) {
        // Cache local para no perder el alta aunque la API tarde/falle.
        await DatabaseService.insertSupervisor(s);
        rethrow;
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
      } catch (_) {
        // Cache local para no perder el alta aunque la API tarde/falle.
        await DatabaseService.insertVendedor(v);
        rethrow;
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
  }) =>
      _useApi
          ? ApiService.getRegistroLlamadas(desde: desde, hasta: hasta, zona: zona, nombreContactado: nombreContactado)
          : DatabaseService.getRegistroLlamadas(desde: desde, hasta: hasta, zona: zona, nombreContactado: nombreContactado);

  static Future<void> insertRegistroLlamada(RegistroLlamada r) async {
    final destino = _useApi ? 'API ${ApiConfig.baseUrl}/llamadas' : 'SQLite local';
    DebugAlertService.info('Guardando llamada en: $destino');
    await (_useApi
        ? ApiService.insertRegistroLlamada(r)
        : DatabaseService.insertRegistroLlamada(r));
    DebugAlertService.success('Llamada registrada: ${r.nombreContactado}');
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

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) =>
      _useApi ? ApiService.getPpvcByFecha(fecha) : DatabaseService.getPpvcByFecha(fecha);

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) =>
      _useApi ? ApiService.getRvcByFecha(fecha) : DatabaseService.getRvcByFecha(fecha);

  static Future<List<Alerta>> getAlertasPendientes() =>
      _useApi ? ApiService.getAlertasPendientes() : DatabaseService.getAlertasPendientes();

  static Future<void> insertAlerta(Alerta a) =>
      _useApi ? ApiService.insertAlerta(a) : DatabaseService.insertAlerta(a);

  static Future<void> guardarUbicacion({
    required String vendedorId,
    required double lat,
    required double lng,
  }) async {
    final destino = _useApi ? 'API ${ApiConfig.baseUrl}/ubicaciones' : 'SQLite local';
    DebugAlertService.info('Guardando ubicación en: $destino');
    await (_useApi
        ? ApiService.guardarUbicacion(vendedorId: vendedorId, lat: lat, lng: lng)
        : DatabaseService.guardarUbicacion(vendedorId: vendedorId, lat: lat, lng: lng));
  }
}
