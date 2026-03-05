import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/phone_utils.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import 'debug_alert_service.dart';

class ApiService {
  static const Duration _readRequestTimeout = Duration(seconds: 12);
  static const Duration _writeRequestTimeout = Duration(seconds: 25);
  static const int _transientRetries = 1;
  static String get _base => ApiConfig.baseUrl;

  static Future<http.Response> _get(String path) async {
    return _requestWithRetry(
      (base) => http.get(Uri.parse('$base$path')),
      timeout: _readRequestTimeout,
    );
  }

  static Future<http.Response> _delete(String path) async {
    return _requestWithRetry(
      (base) => http.delete(Uri.parse('$base$path')),
      timeout: _writeRequestTimeout,
    );
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return _requestWithRetry(
      (base) => http.post(
        Uri.parse('$base$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
      timeout: _writeRequestTimeout,
    );
  }

  static Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    return _requestWithRetry(
      (base) => http.patch(
        Uri.parse('$base$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
      timeout: _writeRequestTimeout,
    );
  }

  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(String base) requestBuilder,
    {required Duration timeout}
  ) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 0; attempt <= _transientRetries; attempt++) {
      try {
        return await requestBuilder(_base).timeout(timeout);
      } on TimeoutException catch (e, st) {
        lastError = e;
        lastStack = st;
      } on http.ClientException catch (e, st) {
        lastError = e;
        lastStack = st;
      }

      if (attempt < _transientRetries) {
        await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    if (lastError != null && lastStack != null) {
      Error.throwWithStackTrace(lastError, lastStack);
    }
    throw Exception('Error de conexión con API LAN');
  }

  static Future<bool> _existsSupervisor(String id) async {
    for (var i = 0; i < 3; i++) {
      try {
        final r = await _requestWithRetry(
          (base) => http.get(Uri.parse('$base/supervisores/$id')),
          timeout: _readRequestTimeout,
        );
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body);
          if (data != null) return true;
        }
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
    }
    return false;
  }

  static Future<bool> _existsVendedor(String id) async {
    for (var i = 0; i < 3; i++) {
      try {
        final r = await _requestWithRetry(
          (base) => http.get(Uri.parse('$base/vendedores/$id')),
          timeout: _readRequestTimeout,
        );
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body);
          if (data != null) return true;
        }
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
    }
    return false;
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
    try {
      final r = await _post('/supervisores', body);
      if (r.statusCode != 200) throw Exception(r.body);
    } on TimeoutException {
      final exists = await _existsSupervisor(s.id);
      if (!exists) rethrow;
    } on http.ClientException {
      final exists = await _existsSupervisor(s.id);
      if (!exists) rethrow;
    }
  }

  static Future<void> insertVendedor(Vendedor v) async {
    final body = v.toMap();
    try {
      final r = await _post('/vendedores', body);
      if (r.statusCode != 200) throw Exception(r.body);
    } on TimeoutException {
      final exists = await _existsVendedor(v.id);
      if (!exists) rethrow;
    } on http.ClientException {
      final exists = await _existsVendedor(v.id);
      if (!exists) rethrow;
    }
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
    final r = await _requestWithRetry(
      (base) {
        final targetUri = Uri.parse('$base/llamadas').replace(
          queryParameters: qp.isEmpty ? null : qp,
        );
        return http.get(targetUri);
      },
      timeout: _readRequestTimeout,
    );
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
      'numeroContacto': r.numeroContacto,
      'numeroPropietario': r.numeroPropietario,
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
      'numeroContacto': r.numeroContacto,
      'numeroPropietario': r.numeroPropietario,
      'transcripcionTexto': r.transcripcionTexto,
    };
    final uri = Uri.parse('$_base/llamadas');
    DebugAlertService.info('API POST: $uri');
    final res = await _requestWithRetry(
      (base) => http.post(
        Uri.parse('$base/llamadas'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
      timeout: _writeRequestTimeout,
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final parsed = jsonDecode(res.body);
    if (parsed is! Map || parsed['success'] != true) {
      throw Exception('Respuesta invalida al guardar llamada: ${res.body}');
    }
    DebugAlertService.success('API OK: llamada guardada');
  }

  /// Inserta con correlación dual (punto A + punto B). Si existe registro coincidente, retorna mergeTarget.
  static Future<({String registroId, bool merged})> insertRegistroLlamadaWithCorrelation(RegistroLlamada r) async {
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
      'numeroContacto': r.numeroContacto != null ? PhoneUtils.normalize(r.numeroContacto!) : null,
      'numeroPropietario': r.numeroPropietario != null ? PhoneUtils.normalize(r.numeroPropietario!) : null,
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
    final res = await _requestWithRetry(
      (base) => http.post(
        Uri.parse('$base/llamadas'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
      timeout: _writeRequestTimeout,
    );
    if (res.statusCode != 200) throw Exception(res.body);
    final parsed = jsonDecode(res.body) as Map<String, dynamic>;
    if (parsed['success'] != true) {
      throw Exception('Respuesta invalida al guardar llamada: ${res.body}');
    }
    final mergeTarget = parsed['mergeTarget'] as String?;
    final merged = mergeTarget != null;
    final registroId = merged ? mergeTarget : (parsed['id'] as String? ?? r.id);
    DebugAlertService.success(merged ? 'API OK: audio correlacionado (punto B)' : 'API OK: llamada guardada');
    return (registroId: registroId, merged: merged);
  }

  static Future<void> uploadAudioPuntoB(String registroId, String rutaAudio) async {
    final file = File(rutaAudio);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    final ext = rutaAudio.toLowerCase().split('.').last;
    final mime = switch (ext) {
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      'aac' => 'audio/aac',
      _ => 'audio/mp4',
    };
    final body = {'audioBase64': b64, 'mimeType': mime};
    final res = await _requestWithRetry(
      (base) => http.post(
        Uri.parse('$base/llamadas/$registroId/audio-punto-b'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ),
      timeout: _writeRequestTimeout,
    );
    if (res.statusCode != 200) throw Exception(res.body);
    DebugAlertService.success('Audio punto B subido correctamente');
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
      var r = await _get('/health/db');
      if (r.statusCode != 200) {
        DebugAlertService.warning(
          'health/db no disponible (${r.statusCode}), probando /test',
        );
        r = await _get('/test');
      }
      if (r.statusCode != 200) {
        DebugAlertService.error('API error HTTP ${r.statusCode}');
        return false;
      }

      final data = jsonDecode(r.body);
      if (data is! Map) {
        DebugAlertService.error('Respuesta inválida de API');
        return false;
      }
      final ok = data['success'] == true;
      if (!ok) {
        DebugAlertService.error('API respondió sin éxito');
        return false;
      }
      // Si responde metadata de DB, confirmamos puente real.
      final hasDbFingerprint =
          data.containsKey('database') || data.containsKey('driver');
      if (!hasDbFingerprint) {
        DebugAlertService.warning(
          'Conectada API sin verificación de DB (falta health/db).',
        );
      } else {
        DebugAlertService.success('Conexión API + DB exitosa');
      }
      return true;
    } catch (e) {
      DebugAlertService.error('Error conexión API: $e');
      return false;
    }
  }
}
