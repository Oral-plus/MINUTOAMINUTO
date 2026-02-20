// API Minuto a Minuto - Desplegable en la nube (como Node.js)
// Ejecutar: dart run bin/server.dart
// Puerto: variable PORT (cloud) o 8080 local. Si 8080 ocupado, prueba 8081.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() async {
  final server = ApiServer();
  await server.start();
  print('API Minuto a Minuto en http://localhost:${server.port}');
  if (server.address == InternetAddress.anyIPv4) {
    print('Escuchando en 0.0.0.0 (listo para despliegue en nube)');
  }
  print('Presiona Ctrl+C para detener.');
}

class ApiServer {
  final _vendedores = <Map<String, dynamic>>[];
  final _supervisores = <Map<String, dynamic>>[];
  final _llamadas = <Map<String, dynamic>>[];
  final _ppvc = <Map<String, dynamic>>[];
  final _rvc = <Map<String, dynamic>>[];
  final _alertas = <Map<String, dynamic>>[];
  HttpServer? _server;
  late int port;
  InternetAddress address = InternetAddress.loopbackIPv4;

  ApiServer() {
    port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  }

  Future<void> start() async {
    // En nube (PORT definido): escuchar en 0.0.0.0
    if (Platform.environment.containsKey('PORT')) {
      address = InternetAddress.anyIPv4;
    }
    for (var p = port; p < port + 10; p++) {
      try {
        _server = await HttpServer.bind(address, p);
        port = p;
        break;
      } on SocketException catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('10048') || msg.contains('in use') || msg.contains('already')) {
          print('Puerto $p en uso, intentando ${p + 1}...');
          continue;
        }
        rethrow;
      }
    }
    if (_server == null) throw SocketException('No se pudo iniciar en puertos $port-${port + 9}');
    await for (final req in _server!) {
      unawaited(_handleRequest(req));
    }
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final path = req.uri.path.replaceFirst('/', '').split('/');
    final resource = path.isEmpty ? '' : path[0];
    final id = path.length > 1 ? path[1] : null;

    _addCors(req.response);

    if (req.method == 'OPTIONS') {
      req.response.statusCode = 200;
      req.response.close();
      return;
    }

    try {
      switch (resource) {
        case '':
          req.response.write(jsonEncode({'status': 'ok', 'api': 'Minuto a Minuto'}));
          break;
        case 'test':
          req.response.write(jsonEncode({'success': true, 'message': 'Conexión exitosa'}));
          break;
        case 'vendedores':
          if (req.method == 'GET') {
            if (id != null) {
              try {
                final v = _vendedores.firstWhere((x) => x['id'] == id);
                req.response.write(jsonEncode(v));
              } catch (_) {
                req.response.write('null');
              }
            } else {
              req.response.write(jsonEncode(_vendedores));
            }
          } else if (req.method == 'POST') {
            final decoded = await json.fuse(utf8).decoder.bind(req).single;
            final body = Map<String, dynamic>.from(decoded as Map);
            body['id'] ??= 'ven_${DateTime.now().millisecondsSinceEpoch}';
            body['geolocalizacionActiva'] ??= 0;
            body['presupuestoMensual'] ??= 0;
            body['presupuestoDiario'] ??= 0;
            _vendedores.add(body);
            req.response.write(jsonEncode({'success': true, 'id': body['id']}));
          } else if (req.method == 'DELETE' && id != null) {
            _vendedores.removeWhere((x) => x['id'] == id);
            req.response.write(jsonEncode({'success': true}));
          }
          break;
        case 'supervisores':
          if (req.method == 'GET') {
            if (id != null) {
              try {
                final s = _supervisores.firstWhere((x) => x['id'] == id);
                req.response.write(jsonEncode(s));
              } catch (_) {
                req.response.write('null');
              }
            } else {
              req.response.write(jsonEncode(_supervisores));
            }
          } else if (req.method == 'POST') {
            final decoded = await json.fuse(utf8).decoder.bind(req).single;
            final body = Map<String, dynamic>.from(decoded as Map);
            body['id'] ??= 'sup_${DateTime.now().millisecondsSinceEpoch}';
            body['subordinadosIds'] ??= '';
            _supervisores.add(body);
            req.response.write(jsonEncode({'success': true, 'id': body['id']}));
          } else if (req.method == 'DELETE' && id != null) {
            _supervisores.removeWhere((x) => x['id'] == id);
            req.response.write(jsonEncode({'success': true}));
          }
          break;
        case 'llamadas':
          if (req.method == 'GET') {
            final desde = req.uri.queryParameters['desde'] ?? DateTime.now().toIso8601String().split('T')[0];
            final hasta = req.uri.queryParameters['hasta'] ?? DateTime.now().toIso8601String().split('T')[0];
            var list = _llamadas.where((l) {
              final f = (l['fecha'] ?? '').toString().split('T')[0].split(' ')[0];
              return f.compareTo(desde) >= 0 && f.compareTo(hasta) <= 0;
            }).toList();
            list.sort((a, b) => (b['horaInicio'] ?? '').toString().compareTo((a['horaInicio'] ?? '').toString()));
            req.response.write(jsonEncode(list));
          } else if (req.method == 'POST') {
            final decoded = await json.fuse(utf8).decoder.bind(req).single;
            final body = Map<String, dynamic>.from(decoded as Map);
            body['id'] ??= 'll_${DateTime.now().millisecondsSinceEpoch}';
            _llamadas.add(body);
            req.response.write(jsonEncode({'success': true, 'id': body['id']}));
          }
          break;
        case 'ppvc':
          if (req.method == 'GET') {
            final fecha = req.uri.queryParameters['fecha'] ?? DateTime.now().toIso8601String().split('T')[0];
            final vid = req.uri.queryParameters['vendedorId'];
            var list = _ppvc.where((p) => p['fecha'] == fecha).toList();
            if (vid != null) list = list.where((p) => p['vendedorId'] == vid).toList();
            req.response.write(vid != null && list.isEmpty ? 'null' : jsonEncode(vid != null ? list.first : list));
          } else if (req.method == 'POST') {
            req.response.write(jsonEncode({'success': true}));
          }
          break;
        case 'rvc':
          if (req.method == 'GET') {
            final fecha = req.uri.queryParameters['fecha'] ?? DateTime.now().toIso8601String().split('T')[0];
            final vid = req.uri.queryParameters['vendedorId'];
            var list = _rvc.where((r) => r['fecha'] == fecha).toList();
            if (vid != null) list = list.where((r) => r['vendedorId'] == vid).toList();
            req.response.write(vid != null && list.isEmpty ? 'null' : jsonEncode(vid != null ? list.first : list));
          } else if (req.method == 'POST') {
            req.response.write(jsonEncode({'success': true}));
          }
          break;
        case 'alertas':
          if (req.method == 'GET') {
            req.response.write(jsonEncode(_alertas));
          } else if (req.method == 'POST') {
            final decoded = await json.fuse(utf8).decoder.bind(req).single;
            final body = Map<String, dynamic>.from(decoded as Map);
            _alertas.add(body);
            req.response.write(jsonEncode({'success': true}));
          }
          break;
        case 'ubicaciones':
          if (req.method == 'POST') {
            req.response.write(jsonEncode({'success': true}));
          }
          break;
        default:
          req.response.statusCode = 404;
          req.response.write(jsonEncode({'error': 'No encontrado'}));
      }
    } catch (e) {
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'error': e.toString()}));
    }
    req.response.close();
  }

  void _addCors(HttpResponse res) {
    res.headers.add('Access-Control-Allow-Origin', '*');
    res.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    res.headers.add('Content-Type', 'application/json; charset=utf-8');
  }
}
