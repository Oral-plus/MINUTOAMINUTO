import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import 'debug_alert_service.dart';

class ApiService {
  static String _activeBase = ApiConfig.baseUrl;
  static bool _fallbackTried = false;
  static String get _base => _activeBase;

  static Future<http.Response> _get(String path) async {
    return _requestWithFallback(() => http.get(Uri.parse('$_base$path')));
  }

  static Future<http.Response> _delete(String path) async {
    return _requestWithFallback(() => http.delete(Uri.parse('$_base$path')));
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return _requestWithFallback(
      () => http.post(
        Uri.parse('$_base$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  static Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    return _requestWithFallback(
      () => http.patch(
        Uri.parse('$_base$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  static Future<http.Response> _requestWithFallback(
    Future<http.Response> Function() request,
  ) async {
    try {
      final r = await request().timeout(const Duration(seconds: 8));
      if (_shouldSwitchToFallback(r.statusCode)) {
        await _switchToFallbackBase();
        return request().timeout(const Duration(seconds: 8));
      }
      return r;
    } catch (e) {
      if (!_fallbackTried) {
        await _switchToFallbackBase();
        return request().timeout(const Duration(seconds: 8));
      }
      rethrow;
    }
  }

  static bool _shouldSwitchToFallback(int statusCode) {
    return !_fallbackTried && (statusCode == 404 || statusCode == 502 || statusCode == 503);
  }

  static Future<void> _switchToFallbackBase() async {
    if (_fallbackTried) return;
    _fallbackTried = true;
    _activeBase = ApiConfig.fallbackBaseUrl;
    DebugAlertService.warning('API fallback activado: $_activeBase');
  }

  static Future<List<Vendedor>> getVendedores() async {
    final r = await _get('/vendedores');
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Vendedor.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Vendedor?> getVendedor(String id) async {
    final r = await _get('/vendedores/$id');
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Vendedor.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Supervisor>> getSupervisores() async {
    final r = await _get('/supervisores');
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Supervisor.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Supervisor?> getSupervisor(String id) async {
    final r = await _get('/supervisores/$id');
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Supervisor.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> insertSupervisor(Supervisor s) async {
    final body = s.toMap();
    final r = await _post('/supervisores', body);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> insertVendedor(Vendedor v) async {
    final body = v.toMap();
    final r = await _post('/vendedores', body);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> deleteSupervisor(String id) async {
    final r = await _delete('/supervisores/$id');
    if (r.statusCode != 200 && r.statusCode != 204) throw Exception('Error ${r.statusCode}: ${r.body}');
  }

  static Future<void> deleteVendedor(String id) async {
    final r = await _delete('/vendedores/$id');
    if (r.statusCode != 200 && r.statusCode != 204) throw Exception('Error ${r.statusCode}: ${r.body}');
  }

  static Future<RegistroLlamada?> getRegistroLlamada(String id) async {
    final hoy = DateTime.now();
    final list = await getRegistroLlamadas(desde: hoy, hasta: hoy);
    try {
      return list.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateRegistroLlamadaObservaciones(String id, String observaciones) async {
    final r = await _patch('/llamadas/$id', {'observaciones': observaciones});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> updateRegistroLlamadaTranscripcion(String id, String transcripcionTexto) async {
    final r = await _patch('/llamadas/$id', {'transcripcionTexto': transcripcionTexto});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> updateRegistroLlamadaRutaGrabacion(String id, String rutaGrabacion) async {
    final r = await _patch('/llamadas/$id', {'rutaGrabacion': rutaGrabacion});
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<List<RegistroLlamada>> getRegistroLlamadas({
    DateTime? desde,
    DateTime? hasta,
    String? zona,
    String? nombreContactado,
  }) async {
    final qp = <String, String>{};
    if (desde != null) qp['desde'] = desde.toIso8601String().split('T')[0];
    if (hasta != null) qp['hasta'] = hasta.toIso8601String().split('T')[0];
    if (zona != null && zona.isNotEmpty) qp['zona'] = zona;
    if (nombreContactado != null && nombreContactado.isNotEmpty) {
      qp['nombreContactado'] = nombreContactado;
    }
    final uri = Uri.parse('$_base/llamadas').replace(
      queryParameters: qp.isEmpty ? null : qp,
    );
    DebugAlertService.info('API GET: $uri');
    final r = await _requestWithFallback(() => http.get(uri));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    DebugAlertService.success('API OK /llamadas (${list.length} registros)');
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
    final uri = Uri.parse('$_base/llamadas');
    DebugAlertService.info('API POST: $uri');
    final res = await _requestWithFallback(
      () => http.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final parsed = jsonDecode(res.body);
    if (parsed is! Map || parsed['success'] != true) {
      throw Exception('Respuesta invalida al guardar llamada: ${res.body}');
    }
    DebugAlertService.success('API OK: llamada guardada');
  }

  static Future<List<RegistroLlamada>> getLlamadasHoy(String? contactadoId) async {
    final hoy = DateTime.now();
    final list = await getRegistroLlamadas(desde: hoy, hasta: hoy, nombreContactado: contactadoId);
    return list;
  }

  static Future<Ppvc?> getPpvcHoy(String vendedorId) async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final r = await _get('/ppvc?vendedorId=$vendedorId&fecha=$hoy');
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Ppvc.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) async {
    final f = fecha.toIso8601String().split('T')[0];
    final r = await _get('/ppvc?fecha=$f');
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Ppvc.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Rvc?> getRvcHoy(String vendedorId) async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final r = await _get('/rvc?vendedorId=$vendedorId&fecha=$hoy');
    if (r.statusCode != 200) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data == null ? null : Rvc.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) async {
    final f = fecha.toIso8601String().split('T')[0];
    final r = await _get('/rvc?fecha=$f');
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
    final r = await _post('/alertas', body);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<List<Alerta>> getAlertasPendientes() async {
    final r = await _get('/alertas?resuelta=0');
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
    final r = await _post('/ubicaciones', body);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<bool> testConnection() async {
    try {
      DebugAlertService.info('Probando conexión API: $_base/health/db');
      final r = await _get('/health/db');
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map;
        final ok = data['success'] == true;
        if (ok) {
          DebugAlertService.success('Conexión API exitosa');
        } else {
          DebugAlertService.error('API respondió sin éxito');
        }
        return ok;
      }
      DebugAlertService.error('API error HTTP ${r.statusCode}');
      return false;
    } catch (e) {
      DebugAlertService.error('Error conexión API: $e');
      return false;
    }
  }
}
