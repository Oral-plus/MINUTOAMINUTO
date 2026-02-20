import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import '../config/api_config.dart';
import 'database_service.dart';
import 'api_service.dart';

/// Abstraction to use either SQLite (local) or API (SQL Server)
class DataService {
  static bool get _useApi => ApiConfig.useRemoteApi;

  static Future<void> init() async {
    if (!_useApi) await DatabaseService.database;
  }

  static Future<List<Vendedor>> getVendedores() =>
      _useApi ? ApiService.getVendedores() : DatabaseService.getVendedores();

  static Future<Vendedor?> getVendedor(String id) =>
      _useApi ? ApiService.getVendedor(id) : DatabaseService.getVendedor(id);

  static Future<List<Supervisor>> getSupervisores() =>
      _useApi ? ApiService.getSupervisores() : DatabaseService.getSupervisores();

  static Future<Supervisor?> getSupervisor(String id) =>
      _useApi ? ApiService.getSupervisor(id) : DatabaseService.getSupervisor(id);

  static Future<void> insertSupervisor(Supervisor s) =>
      _useApi ? ApiService.insertSupervisor(s) : DatabaseService.insertSupervisor(s);

  static Future<void> insertVendedor(Vendedor v) =>
      _useApi ? ApiService.insertVendedor(v) : DatabaseService.insertVendedor(v);

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

  static Future<void> insertRegistroLlamada(RegistroLlamada r) =>
      _useApi ? ApiService.insertRegistroLlamada(r) : DatabaseService.insertRegistroLlamada(r);

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) =>
      _useApi ? ApiService.getPpvcByFecha(fecha) : DatabaseService.getPpvcByFecha(fecha);

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) =>
      _useApi ? ApiService.getRvcByFecha(fecha) : DatabaseService.getRvcByFecha(fecha);

  static Future<List<Alerta>> getAlertasPendientes() =>
      _useApi ? ApiService.getAlertasPendientes() : DatabaseService.getAlertasPendientes();

  static Future<void> insertAlerta(Alerta a) =>
      _useApi ? ApiService.insertAlerta(a) : DatabaseService.insertAlerta(a);

  static Future<void> guardarUbicacion({required String vendedorId, required double lat, required double lng}) =>
      _useApi ? ApiService.guardarUbicacion(vendedorId: vendedorId, lat: lat, lng: lng) : DatabaseService.guardarUbicacion(vendedorId: vendedorId, lat: lat, lng: lng);
}
