import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/phone_utils.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import '../models/contacto_cartera.dart';
import 'debug_alert_service.dart';

// Importación condicional de dart:io para File (no disponible en web)
import 'api_service_io.dart'
    if (dart.library.html) 'api_service_web.dart'
    as platform_io;

class ApiService {
  static const Duration _readRequestTimeout = Duration(seconds: 12);
  static const Duration _writeRequestTimeout = Duration(seconds: 25);
  /// Exposed for platform-specific implementations (api_service_io.dart)
  static const Duration writeRequestTimeout = _writeRequestTimeout;
  static const int _transientRetries = 1;
  static String get _base => ApiConfig.baseUrl;

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'MinutoAMinuto/2.2.1 (Android)',
  };

  static Future<http.Response> _get(String path) async {
    return _requestWithRetry(
      (base) => http.get(Uri.parse('$base$path'), headers: _defaultHeaders),
      timeout: _readRequestTimeout,
    );
  }

  static Future<http.Response> _delete(String path) async {
    return _requestWithRetry(
      (base) => http.delete(Uri.parse('$base$path'), headers: _defaultHeaders),
      timeout: _writeRequestTimeout,
    );
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    return _requestWithRetry(
      (base) => http.post(
        Uri.parse('$base$path'),
        body: jsonEncode(body),
        headers: _defaultHeaders,
      ),
      timeout: _writeRequestTimeout,
    );
  }

  static Future<http.Response> _patch(String path, Map<String, dynamic> body) async {
    return _requestWithRetry(
      (base) => http.patch(
        Uri.parse('$base$path'),
        body: jsonEncode(body),
        headers: _defaultHeaders,
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
    const bases = [ApiConfig.baseUrl, ApiConfig.fallbackBaseUrl];

    for (var attempt = 0; attempt <= _transientRetries; attempt++) {
      for (final base in bases) {
        if (base.isEmpty) continue;
        try {
          return await requestBuilder(base).timeout(timeout);
        } on TimeoutException catch (e, st) {
          lastError = e;
          lastStack = st;
        } on http.ClientException catch (e, st) {
          lastError = e;
          lastStack = st;
        } on Exception catch (e, st) {
          // Si es un error de formato o algo interno, no reintentamos
          if (e.toString().contains('uri') || e.toString().contains('Argument')) {
             rethrow;
          }
          lastError = e;
          lastStack = st;
        }
      }
      if (attempt < _transientRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    if (lastError != null) {
      String userMessage = 'Error de conexión. Verifique su internet.';
      if (lastError is TimeoutException) {
        userMessage = 'El servidor tarda demasiado en responder. Reintentando...';
      } else if (lastError.toString().contains('SocketException')) {
        userMessage = 'No hay conexión con el servidor. ¿Está conectado a internet?';
      }
      
      if (lastStack != null) {
        debugPrint('API Error Detail: $lastError\n$lastStack');
        // Lanzamos un error que contenga el mensaje amigable pero preserve el tipo si es posible
        throw Exception(userMessage);
      }
      throw Exception(userMessage);
    }
    throw Exception('Error de red persistente. Verifique su conexión.');
  }

  static void _checkResponse(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    
    debugPrint('API Error Detail [${r.statusCode}]: ${r.body}');
    
    String err = r.body.trim();
    final lower = err.toLowerCase();
    if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
      err = 'Error del servidor (${r.statusCode}). Verifique la conexión o intente más tarde.';
    } else {
      try {
        final j = jsonDecode(err);
        if (j is Map && j['message'] != null) {
          err = j['message'].toString();
        } else if (j is Map && j['error'] != null) {
          err = j['error'].toString();
        }
      } catch (_) {}
    }
    
    // Si el error es un 400 o 500, adjuntar el código para diagnóstico rápido
    final finalMsg = 'API Error ${r.statusCode}: $err';
    throw Exception(finalMsg.length > 250 ? '${finalMsg.substring(0, 250)}...' : finalMsg);
  }

  /// Extrae una lista de la respuesta — soporta `[...]` y `{"data":[...]}` / `{"rows":[...]}`.
  static List<dynamic> _extractList(http.Response r) {
    final decoded = jsonDecode(r.body);
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['data', 'rows', 'items', 'results', 'records']) {
        if (decoded[key] is List) return decoded[key] as List<dynamic>;
      }
    }
    return [];
  }

  /// Extrae un mapa de la respuesta — soporta `{...}` y `{"data":{...}}`.
  static Map<String, dynamic>? _extractMap(http.Response r) {
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    if (decoded is Map) {
      if (decoded.containsKey('data') && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  static Future<bool> _existsResource(String path) async {
    for (var i = 0; i < 3; i++) {
      try {
        final r = await _requestWithRetry(
          (base) => http.get(Uri.parse('$base$path')),
          timeout: _readRequestTimeout,
        );
        if (r.statusCode == 200) return true;
        if (r.statusCode == 404) return false;
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
    }
    return false;
  }

  static Future<List<Vendedor>> getVendedores() async {
    final r = await _get('/vendedores');
    _checkResponse(r);
    final list = _extractList(r);
    return list.map((item) => Vendedor.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  static Future<Vendedor?> getVendedor(String id) async {
    final r = await _get('/vendedores/$id');
    _checkResponse(r);
    final data = _extractMap(r);
    return data == null ? null : Vendedor.fromMap(data);
  }

  static Future<List<Supervisor>> getSupervisores() async {
    final r = await _get('/supervisores');
    _checkResponse(r);
    final list = _extractList(r);
    return list.map((item) => Supervisor.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  static Future<Supervisor?> getSupervisor(String id) async {
    final r = await _get('/supervisores/$id');
    _checkResponse(r);
    final data = _extractMap(r);
    return data == null ? null : Supervisor.fromMap(data);
  }

  static Future<void> insertSupervisor(Supervisor s) async {
    final body = s.toMap();
    try {
      final r = await _post('/supervisores', body);
      _checkResponse(r);
    } on TimeoutException {
      if (!await _existsResource('/supervisores/${s.id}')) rethrow;
    } on http.ClientException {
      if (!await _existsResource('/supervisores/${s.id}')) rethrow;
    }
  }

  static Future<void> insertVendedor(Vendedor v) async {
    final body = v.toMap();
    try {
      final r = await _post('/vendedores', body);
      _checkResponse(r);
    } on TimeoutException {
      if (!await _existsResource('/vendedores/${v.id}')) rethrow;
    } on http.ClientException {
      if (!await _existsResource('/vendedores/${v.id}')) rethrow;
    }
  }

  static Future<void> deleteSupervisor(String id) async {
    final r = await _delete('/supervisores/$id');
    _checkResponse(r);
  }

  static Future<void> deleteVendedor(String id) async {
    final r = await _delete('/vendedores/$id');
    _checkResponse(r);
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
    _checkResponse(r);
  }

  static Future<void> updateRegistroLlamadaTranscripcion(String id, String transcripcionTexto) async {
    final r = await _patch('/llamadas/$id', {'transcripcionTexto': transcripcionTexto});
    _checkResponse(r);
  }

  static Future<void> updateRegistroLlamadaCumplioMeta(String id, bool cumplioMeta) async {
    final r = await _patch('/llamadas/$id', {'cumplioMeta': cumplioMeta ? 1 : 0});
    _checkResponse(r);
  }

  /// Transcribe audio usando el endpoint /transcribe del servidor (Gemini).
  /// Reintenta una vez en errores 5xx o timeout (fallos transitorios de la API).
  static Future<String?> transcribeAudio(String audioBase64, String mimeType) async {
    try {
      final r = await _post('/transcribe', {
        'audioBase64': audioBase64,
        'mimeType': mimeType
      });
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return data['text'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Actualiza el telefono del perfil en el servidor (para correlación dual).
  /// [isSupervisor] determina si se patchea /supervisores/:id o /vendedores/:id.
  static Future<void> updateTelefono(String userId, String telefono, {bool isSupervisor = true}) async {
    final endpoint = isSupervisor ? '/supervisores/$userId' : '/vendedores/$userId';
    try {
      final res = await _patch(endpoint, {'telefono': telefono});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        DebugAlertService.success('Teléfono sincronizado en servidor: $telefono');
      } else {
        DebugAlertService.warning('No se pudo sincronizar teléfono: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      DebugAlertService.error('Error sincronizando teléfono: $e');
      rethrow;
    }
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
    _checkResponse(r);
    // Server returns {value: [...], Count: N} — use _extractList to handle both List and Map formats
    final list = _extractList(r);
    DebugAlertService.success('API OK /llamadas (${list.length} registros)');
    return list.map((item) => _registroFromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  /// Retorna los nombres únicos de COACHes o KAMs desde SAP (para el dropdown en login).
  static Future<List<String>> getSupervisoresSap(String cargo) async {
    final r = await _requestWithRetry(
      (base) => http.get(
        Uri.parse('$base/cartera/supervisores').replace(
          queryParameters: {'cargo': cargo.toUpperCase()},
        ),
      ),
      timeout: const Duration(seconds: 15),
    );
    _checkResponse(r);
    final parsed = jsonDecode(r.body) as Map<String, dynamic>;
    return List<String>.from(parsed['data'] as List<dynamic>? ?? []);
  }

  /// Carga los contactos de cartera SAP filtrados por cargo del usuario.
  /// [cargo]: 'COACH', 'KAM' o 'JEFE DE VENTAS'
  /// [nombre]: nombre del usuario logueado (ignorado para JEFE)
  static Future<List<ContactoCartera>> getContactosCartera({
    required String cargo,
    required String nombre,
  }) async {
    final params = <String, String>{'cargo': cargo};
    if (nombre.isNotEmpty && cargo != 'JEFE DE VENTAS') params['nombre'] = nombre;
    final r = await _requestWithRetry(
      (base) {
        final u = Uri.parse('$base/cartera/contactos').replace(queryParameters: params);
        return http.get(u);
      },
      timeout: const Duration(seconds: 20),
    );
    _checkResponse(r);
    final parsed = jsonDecode(r.body) as Map<String, dynamic>;
    final list   = (parsed['data'] as List<dynamic>? ?? []);
    return list.map((item) => ContactoCartera.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  /// Trae la lista de nombres de vendedores (SlpName) asignados a un Coach o KAM en SAP.
  static Future<List<String>> getVendedoresSap(String cargo, String nombre) async {
    final r = await _requestWithRetry(
      (base) => http.get(Uri.parse('$base/cartera/vendedores?cargo=$cargo&nombre=$nombre')),
      timeout: const Duration(seconds: 15),
    );
    _checkResponse(r);
    final parsed = jsonDecode(r.body) as Map<String, dynamic>;
    final data = parsed['data'] as List<dynamic>? ?? [];
    return data.map((e) => e.toString()).toList();
  }

  /// Trae la jerarquía completa de equipo (Solo para Jefe de Ventas).
  static Future<List<dynamic>> getEquipoJerarquico() async {
    final r = await _requestWithRetry(
      (base) => http.get(Uri.parse('$base/cartera/equipo-jerarquico')),
      timeout: const Duration(seconds: 30),
    );
    _checkResponse(r);
    final parsed = jsonDecode(r.body) as Map<String, dynamic>;
    return parsed['data'] as List<dynamic>? ?? [];
  }

  /// Lanza la sincronización masiva de usuarios desde SAP.
  static Future<Map<String, dynamic>> syncUsers() async {
    final r = await _requestWithRetry(
      (base) => http.get(Uri.parse('$base/sap/sync-users')),
      timeout: const Duration(minutes: 2),
    );
    _checkResponse(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static RegistroLlamada _registroFromJson(Map m) {
    final map = Map<String, dynamic>.from(m);
    map['geolocalizacionActiva'] = 0;
    return RegistroLlamada.fromMap(map);
  }

  /// Convierte DateTime a formato ISO-8601 compatible con JavaScript/Node.js
  /// (UTC, 3 decimales): "2026-03-21T12:39:00.123Z"
  static String _dt(DateTime dt) {
    final u = dt.toUtc();
    final ms = u.millisecond.toString().padLeft(3, '0');
    return '${u.year.toString().padLeft(4,'0')}-'
        '${u.month.toString().padLeft(2,'0')}-'
        '${u.day.toString().padLeft(2,'0')}T'
        '${u.hour.toString().padLeft(2,'0')}:'
        '${u.minute.toString().padLeft(2,'0')}:'
        '${u.second.toString().padLeft(2,'0')}.'
        '${ms}Z';
  }

  static Future<void> insertRegistroLlamada(RegistroLlamada r) async {
    final body = {
      'id': r.id,
      'fecha': r.fecha.toIso8601String().split('T')[0],
      'horaInicio': _dt(r.horaInicio),
      'horaFin': _dt(r.horaFin),
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
      'rutaGrabacionPuntoB': r.rutaGrabacionPuntoB,
      'transcripcionTexto': r.transcripcionTexto,
      'latitud': r.latitud,
      'longitud': r.longitud,
    };
    final uri = Uri.parse('$_base/llamadas');
    DebugAlertService.info('API POST: $uri');
    final res = await _post('/llamadas', body);
    _checkResponse(res);
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
      'horaInicio': _dt(r.horaInicio),
      'horaFin': _dt(r.horaFin),
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
      'rutaGrabacionPuntoB': r.rutaGrabacionPuntoB,
      'transcripcionTexto': r.transcripcionTexto,
      'latitud': r.latitud,
      'longitud': r.longitud,
    };
    final uri = Uri.parse('$_base/llamadas');
    DebugAlertService.info('API POST (correlacion): $uri');
    final res = await _post('/llamadas', body);

    _checkResponse(res);
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

  /// Sube el audio principal de la llamada al servidor.
  /// Envía el archivo como base64 a POST /llamadas/:id/audio (o audio-punto-b).
  static Future<String?> uploadAudioFile(String registroId, String rutaAudio, {bool isPuntoB = false}) async {
    if (kIsWeb) {
      debugPrint('uploadAudioFile: no disponible en web');
      return null;
    }
    return platform_io.uploadAudioFileImpl(registroId, rutaAudio, isPuntoB: isPuntoB);
  }

  /// Actualiza el campo rutaGrabacion o rutaGrabacionPuntoB en el servidor con la URL del audio subido.
  static Future<void> updateRegistroLlamadaRutaGrabacion(String registroId, String audioUrl, {bool isPuntoB = false}) async {
    final field = isPuntoB ? 'rutaGrabacionPuntoB' : 'rutaGrabacion';
    final res = await _patch('/llamadas/$registroId', {field: audioUrl});
    _checkResponse(res);
  }

  static Future<void> uploadAudioPuntoB(String registroId, String rutaAudio) async {
    if (kIsWeb) {
      debugPrint('uploadAudioPuntoB: no disponible en web');
      return;
    }
    await platform_io.uploadAudioPuntoBImpl(registroId, rutaAudio);
  }

  static Future<List<RegistroLlamada>> getLlamadasHoy(String? contactadoId) async {
    final hoy = DateTime.now();
    final list = await getRegistroLlamadas(desde: hoy, hasta: hoy, nombreContactado: contactadoId);
    return list;
  }

  static Future<Ppvc?> getPpvcHoy(String vendedorId) async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final r = await _get('/ppvc?vendedorId=$vendedorId&fecha=$hoy');
    _checkResponse(r);
    final data = jsonDecode(r.body);
    return data == null ? null : Ppvc.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) async {
    final f = fecha.toIso8601String().split('T')[0];
    final r = await _get('/ppvc?fecha=$f');
    _checkResponse(r);
    final list = jsonDecode(r.body) as List;
    return list.map((m) => Ppvc.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  static Future<Rvc?> getRvcHoy(String vendedorId) async {
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final r = await _get('/rvc?vendedorId=$vendedorId&fecha=$hoy');
    _checkResponse(r);
    final data = jsonDecode(r.body);
    return data == null ? null : Rvc.fromMap(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) async {
    final f = fecha.toIso8601String().split('T')[0];
    final r = await _get('/rvc?fecha=$f');
    _checkResponse(r);
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
    _checkResponse(r);
  }

  static Future<List<Alerta>> getAlertasPendientes({String? supervisorId}) async {
    final qs = supervisorId != null && supervisorId.isNotEmpty
        ? '/alertas?resuelta=0&supervisorId=${Uri.encodeComponent(supervisorId)}'
        : '/alertas?resuelta=0';
    final r = await _get(qs);
    _checkResponse(r);
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
    _checkResponse(r);
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
