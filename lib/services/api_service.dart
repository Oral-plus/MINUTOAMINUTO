import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';

class ApiService {
  static String get _base => ApiConfig.baseUrl;

  static Future<List<Vendedor>> getVendedores() async {
    final r = await http.get(Uri.parse('$_base/vendedores'));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Vendedor.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Vendedor?> getVendedor(String id) async {
    final r = await http.get(Uri.parse('$_base/vendedores/$id'));
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Vendedor.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Supervisor>> getSupervisores() async {
    final r = await http.get(Uri.parse('$_base/supervisores'));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Supervisor.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Supervisor?> getSupervisor(String id) async {
    final r = await http.get(Uri.parse('$_base/supervisores/$id'));
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Supervisor.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> insertSupervisor(Supervisor s) async {
    final body = s.toMap();
    final r = await http.post(Uri.parse('$_base/supervisores'),
        body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> insertVendedor(Vendedor v) async {
    final body = v.toMap();
    final r = await http.post(Uri.parse('$_base/vendedores'),
        body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> deleteSupervisor(String id) async {
    final r = await http.delete(Uri.parse('$_base/supervisores/$id'));
    if (r.statusCode != 200 && r.statusCode != 204) throw Exception('Error ${r.statusCode}: ${r.body}');
  }

  static Future<void> deleteVendedor(String id) async {
    final r = await http.delete(Uri.parse('$_base/vendedores/$id'));
    if (r.statusCode != 200 && r.statusCode != 204) throw Exception('Error ${r.statusCode}: ${r.body}');
  }

  static Future<List<RegistroLlamada>> getRegistroLlamadas({
    DateTime? desde,
    DateTime? hasta,
    String? zona,
    String? nombreContactado,
  }) async {
    var url = '$_base/llamadas?';
    if (desde != null) url += 'desde=${desde.toIso8601String().split('T')[0]}&';
    if (hasta != null) url += 'hasta=${hasta.toIso8601String().split('T')[0]}&';
    if (zona != null) url += 'zona=$zona&';
    if (nombreContactado != null) url += 'nombreContactado=$nombreContactado&';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => _registroFromJson(m as Map)).toList();
  }

  static RegistroLlamada _registroFromJson(Map m) {
    final map = Map<String, dynamic>.from(m);
    map['geolocalizacionActiva'] = 0;
    return RegistroLlamada.fromMap(map);
  }

  static Future<void> insertRegistroLlamada(RegistroLlamada r) async {
    final body = {
      'id': r.id,
      'fecha': r.fecha.toIso8601String().split('T')[0],
      'horaInicio': r.horaInicio.toIso8601String(),
      'horaFin': r.horaFin.toIso8601String(),
      'duracionMinutos': r.duracionMinutos,
      'tipoLlamada': r.tipoLlamada.valor,
      'cargoLider': r.cargoLider.valor,
      'zona': r.zona,
      'nombreLider': r.nombreLider,
      'nombreContactado': r.nombreContactado,
      'clientesProgramados': r.clientesProgramados,
      'clientesVisitados': r.clientesVisitados,
      'ventaDia': r.ventaDia,
      'recaudoDia': r.recaudoDia,
      'cumplioMeta': r.cumplioMeta ? 1 : 0,
      'coincidenciaPpvcRvc': r.coincidenciaPpvcRvc ? 1 : 0,
      'conversion60': r.conversion60,
      'recuperacionPerdidos': r.recuperacionPerdidos,
      'observaciones': r.observaciones,
      'confirmacionVeracidad': r.confirmacionVeracidad ? 1 : 0,
      'rutaGrabacion': r.rutaGrabacion,
      'transcripcionTexto': r.transcripcionTexto,
    };
    final res = await http.post(Uri.parse('$_base/llamadas'), body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<List<RegistroLlamada>> getLlamadasHoy(String? contactadoId) async {
    final hoy = DateTime.now();
    final list = await getRegistroLlamadas(desde: hoy, hasta: hoy, nombreContactado: contactadoId);
    return list;
  }

  static Future<Ppvc?> getPpvcHoy(String vendedorId) async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final r = await http.get(Uri.parse('$_base/ppvc?vendedorId=$vendedorId&fecha=$hoy'));
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Ppvc.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) async {
    final f = fecha.toIso8601String().split('T')[0];
    final r = await http.get(Uri.parse('$_base/ppvc?fecha=$f'));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Ppvc.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Rvc?> getRvcHoy(String vendedorId) async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final r = await http.get(Uri.parse('$_base/rvc?vendedorId=$vendedorId&fecha=$hoy'));
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Rvc.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) async {
    final f = fecha.toIso8601String().split('T')[0];
    final r = await http.get(Uri.parse('$_base/rvc?fecha=$f'));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Rvc.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<void> insertAlerta(Alerta a) async {
    final body = {
      'id': a.id,
      'tipo': a.tipo.name,
      'fecha': a.fecha.toIso8601String(),
      'mensaje': a.mensaje,
      'vendedorId': a.vendedorId,
      'supervisorId': a.supervisorId,
      'zona': a.zona,
      'resuelta': a.resuelta ? 1 : 0,
    };
    final r = await http.post(Uri.parse('$_base/alertas'), body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<List<Alerta>> getAlertasPendientes() async {
    final r = await http.get(Uri.parse('$_base/alertas?resuelta=0'));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      return Alerta(
        id: map['id'] as String,
        tipo: TipoAlerta.values.firstWhere((e) => e.name == map['tipo'], orElse: () => TipoAlerta.sinLlamada12m),
        fecha: DateTime.parse(map['fecha'] as String),
        mensaje: map['mensaje'] as String,
        vendedorId: map['vendedorId'] as String?,
        supervisorId: map['supervisorId'] as String?,
        zona: map['zona'] as String? ?? '',
        resuelta: (map['resuelta'] ?? 0) == 1,
      );
    }).toList();
  }

  static Future<void> guardarUbicacion({required String vendedorId, required double lat, required double lng}) async {
    final body = {
      'vendedorId': vendedorId,
      'fecha': DateTime.now().toIso8601String().split('T')[0],
      'latitud': lat,
      'longitud': lng,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final r = await http.post(Uri.parse('$_base/ubicaciones'), body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<bool> testConnection() async {
    try {
      final r = await http.get(Uri.parse('$_base/test')).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map;
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
