import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/alerta.dart';
import '../config/api_config.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';
import '../services/call_monitor_service.dart';
import '../services/media_projection_service.dart';
import '../services/debug_alert_service.dart';
import '../utils/kpi_calculator.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider with ChangeNotifier {
  List<Vendedor> _vendedores = [];
  List<Supervisor> _supervisores = [];
  List<RegistroLlamada> _llamadas = [];
  List<Alerta> _alertas = [];
  Supervisor? _usuarioActual;
  Vendedor? _vendedorActual;
  String? _storedSupervisorId;
  String? _storedVendedorId;
  bool _geolocalizacionActiva = false;
  bool _monitorLlamadasActivo = false;
  StreamSubscription? _locationSub;
  bool _isInitialized = false;
  bool _sessionResolved = false; // true cuando sabemos si hay sesión o no
  String? _initError;
  static const Duration _initTimeout = Duration(seconds: 4);

  List<Vendedor> get vendedores => _vendedores;
  List<Supervisor> get supervisores => _supervisores;
  List<RegistroLlamada> get llamadas => _llamadas;
  List<Alerta> get alertas => _alertas;
  bool get isInitialized => _isInitialized && _sessionResolved;
  String? get initError => _initError;
  Supervisor? get usuarioActual => _usuarioActual;
  Vendedor? get vendedorActual => _vendedorActual;
  bool get hasStoredSession =>
      _storedSupervisorId != null || _storedVendedorId != null;
  bool get geolocalizacionActiva => _geolocalizacionActiva;
  bool get monitorLlamadasActivo => _monitorLlamadasActivo;

  bool get esCoach => _usuarioActual?.esCoach ?? false;
  bool get esKam => _usuarioActual?.esKam ?? false;
  bool get esJefe => _usuarioActual?.esJefe ?? false;
  bool get esVendedor => _vendedorActual != null;

  Future<void> init() async {
    await runZonedGuarded(() async {
      try {
        DebugAlertService.info('Inicializando app...');
        // Solo operaciones locales rápidas — la UI aparece en < 1s
        await DataService.init();
        await _withTimeout(
          _readStoredSessionIds(),
          'lectura de sesión local',
          timeout: const Duration(seconds: 1),
        );
        DebugAlertService.success('Inicio instantáneo completado');
      } catch (e, st) {
        debugPrint('Error init Minuto a Minuto: $e\n$st');
        DebugAlertService.error('Error al iniciar: $e');
        _initError = 'Error al cargar: $e';
        if (!ApiConfig.useRemoteApi) _initError = '$_initError\n\n¿Ejecutando en Web? Use Android/iOS.';
      } finally {
        _isInitialized = true;
        // Si no hay sesión guardada localmente, mostrar login de inmediato
        if (_storedSupervisorId == null && _storedVendedorId == null) {
          _sessionResolved = true;
          notifyListeners();
        } else {
          notifyListeners();
        }
      }
      // Resolver sesión en red y cargar datos (puede tardar, pero con timeout corto)
      unawaited(_warmUpPostInit());
    }, (error, stack) {
      debugPrint('AppProvider zone: $error\n$stack');
      _initError = 'Error inesperado: $error';
      _isInitialized = true;
      _sessionResolved = true;
      notifyListeners();
    });
  }

  Future<void> _warmUpPostInit() async {
    // Resolver usuario guardado con timeout máximo de 3s
    // Si tarda más, mostrar login y seguir en segundo plano
    await Future.any([
      _runInitStep(
        'resolver sesión guardada',
        _resolverUsuarioGuardado,
        timeout: const Duration(seconds: 3),
      ),
      Future.delayed(const Duration(seconds: 3)),
    ]);
    // Siempre marcar como resuelto tras el timeout
    if (!_sessionResolved) {
      _sessionResolved = true;
      notifyListeners();
    }
    // Cargar listas en paralelo en segundo plano
    final results = await Future.wait([
      _loadListOrEmpty<Vendedor>(
        DataService.getVendedores,
        'vendedores (background)',
        timeout: _initTimeout,
      ),
      _loadListOrEmpty<Supervisor>(
        DataService.getSupervisores,
        'supervisores (background)',
        timeout: _initTimeout,
      ),
    ]);
    _vendedores = results[0] as List<Vendedor>;
    _supervisores = results[1] as List<Supervisor>;
    notifyListeners();
  }

  Future<List<T>> _loadListOrEmpty<T>(
    Future<List<T>> Function() loader,
    String label,
    {Duration? timeout}
  ) async {
    try {
      return await _withTimeout(loader(), label, timeout: timeout);
    } catch (e) {
      DebugAlertService.warning('Init parcial: no se cargó $label ($e)');
      return <T>[];
    }
  }

  Future<void> _runInitStep(
    String label,
    Future<void> Function() action,
    {Duration? timeout}
  ) async {
    try {
      await _withTimeout(action(), label, timeout: timeout);
    } catch (e) {
      DebugAlertService.warning('Init parcial: fallo en $label ($e)');
    }
  }

  Future<T> _withTimeout<T>(
    Future<T> future,
    String label, {
    Duration? timeout,
  }) async {
    final limit = timeout ?? _initTimeout;
    try {
      return await future.timeout(limit);
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado en: $label');
    }
  }

  Future<void> _readStoredSessionIds() async {
    final prefs = await SharedPreferences.getInstance();
    _storedSupervisorId = prefs.getString('supervisor_id');
    _storedVendedorId = prefs.getString('vendedor_id');
  }

  Future<void> _resolverUsuarioGuardado() async {
    await _readStoredSessionIds();
    final supervisorId = _storedSupervisorId;
    final vendedorId = _storedVendedorId;

    Supervisor? s;
    Vendedor? v;
    if (supervisorId != null) {
      try {
        s = await DataService.getSupervisor(supervisorId);
      } catch (_) {}
    }
    if (vendedorId != null) {
      try {
        v = await DataService.getVendedor(vendedorId);
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    if (supervisorId != null && s == null) {
      await prefs.remove('supervisor_id');
      _storedSupervisorId = null;
    }
    if (vendedorId != null && v == null) {
      await prefs.remove('vendedor_id');
      _storedVendedorId = null;
    }
    _usuarioActual = s;
    _vendedorActual = v;
    notifyListeners();
    if (s != null || v != null) {
      unawaited(_asegurarMonitorActivo());
    }
  }

  Future<void> loginSupervisor(String id) async {
    _usuarioActual = await DataService.getSupervisor(id);
    _vendedorActual = null;
    if (_usuarioActual != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supervisor_id', id);
      await prefs.remove('vendedor_id');
      _storedSupervisorId = id;
      _storedVendedorId = null;
      if (_usuarioActual!.telefono != null && _usuarioActual!.telefono!.trim().isNotEmpty) {
        await prefs.setString('numero_telefono_propietario', _usuarioActual!.telefono!.trim());
      }
    }
    notifyListeners();
    unawaited(_asegurarMonitorActivo());
  }

  Future<void> loginVendedor(String id) async {
    _vendedorActual = await DataService.getVendedor(id);
    _usuarioActual = null;
    if (_vendedorActual != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vendedor_id', id);
      await prefs.remove('supervisor_id');
      _storedVendedorId = id;
      _storedSupervisorId = null;
      if (_vendedorActual!.telefono != null && _vendedorActual!.telefono!.trim().isNotEmpty) {
        await prefs.setString('numero_telefono_propietario', _vendedorActual!.telefono!.trim());
      }
    }
    notifyListeners();
    unawaited(_asegurarMonitorActivo());
  }

  Future<void> _asegurarMonitorActivo() async {
    try {
      final activo = await CallMonitorService.isActive();
      if (!activo) {
        await CallMonitorService.start();
      }
      _monitorLlamadasActivo = await CallMonitorService.isActive();
      notifyListeners();
    } catch (e) {
      debugPrint('_asegurarMonitorActivo: $e');
    }
  }

  Future<void> logout() async {
    _usuarioActual = null;
    _vendedorActual = null;
    _storedSupervisorId = null;
    _storedVendedorId = null;
    _geolocalizacionActiva = false;
    _locationSub?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supervisor_id');
    await prefs.remove('vendedor_id');
    notifyListeners();
  }

  Future<void> cargarEquipo() async {
    _vendedores = await DataService.getVendedores();
    _supervisores = await DataService.getSupervisores();
    notifyListeners();
  }

  Future<void> cargarDatosHoy() async {
    final hoy = DateTime.now();
    _llamadas = await DataService.getRegistroLlamadas(
      desde: hoy,
      hasta: hoy,
    );
    notifyListeners();
  }

  Future<void> recargarDashboard() async {
    final hoy = DateTime.now();
    _llamadas = await DataService.getRegistroLlamadas(
      desde: hoy,
      hasta: hoy,
    );
    _alertas = await DataService.getAlertasPendientes();
    notifyListeners();
  }

  List<Vendedor> vendedoresPorCoach(String coachId) {
    return _vendedores.where((v) => v.coachId == coachId).toList();
  }

  List<RegistroLlamada> llamadasDelContactado(String nombre) {
    return _llamadas.where((l) => l.nombreContactado == nombre).toList();
  }

  Future<void> registrarLlamada(RegistroLlamada r) async {
    if (r.duracionMinutos < AppConstants.duracionMinimaLlamada) {
      throw Exception(
          'La duración mínima debe ser ${AppConstants.duracionMinimaLlamada} minutos');
    }
    if (!r.confirmacionVeracidad) {
      throw Exception('Debe confirmar la veracidad del registro');
    }
    await DataService.insertRegistroLlamada(r);
    await cargarDatosHoy();
    notifyListeners();
  }

  Future<void> iniciarGeolocalizacion() async {
    if (_vendedorActual == null) return;
    _geolocalizacionActiva = await LocationService.requestPermission();
    if (_geolocalizacionActiva) {
      await LocationService.registrarUbicacionVendedor(_vendedorActual!.id);
      _locationSub = LocationService.positionStream.listen((pos) {
        LocationService.registrarUbicacionVendedor(_vendedorActual!.id);
      });
    }
    notifyListeners();
  }

  Future<void> detenerGeolocalizacion() async {
    _locationSub?.cancel();
    _geolocalizacionActiva = false;
    notifyListeners();
  }

  Future<void> iniciarMonitorLlamadas() async {
    _monitorLlamadasActivo = false;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      await CallMonitorService.start();
      _monitorLlamadasActivo = await CallMonitorService.isActive();
    } catch (e, st) {
      debugPrint('iniciarMonitorLlamadas: $e\n$st');
      _monitorLlamadasActivo = false;
    }
    notifyListeners();
  }

  /// Solicita el permiso de MediaProjection al usuario.
  /// Debe llamarse desde un contexto con BuildContext (UI).
  Future<bool> solicitarPermisoMediaProjection() async {
    try {
      final granted = await MediaProjectionService.requestPermission();
      return granted;
    } catch (e) {
      debugPrint('solicitarPermisoMediaProjection: $e');
      return false;
    }
  }

  bool get mediaProjectionGranted => MediaProjectionService.hasPermission;

  Future<void> detenerMonitorLlamadas() async {
    try {
      await CallMonitorService.stop();
    } catch (e) {
      debugPrint('detenerMonitorLlamadas: $e');
    }
    _monitorLlamadasActivo = false;
    notifyListeners();
  }

  // KPIs Dashboard
  double get porcentajeLlamadasCoach {
    final coaches = _supervisores.where((s) => s.esCoach).toList();
    if (coaches.isEmpty) return 0;
    int realizadas = 0;
    int esperadas = 0;
    for (final c in coaches) {
      final vends = vendedoresPorCoach(c.id);
      esperadas += vends.length * 2; // 2 llamadas por vendedor
      for (final v in vends) {
        final count = llamadasDelContactado(v.nombre).length;
        realizadas += count > 2 ? 2 : count;
      }
    }
    return KpiCalculator.cumplimientoLlamadasCoach(
      realizadas: realizadas,
      esperadas: esperadas,
    );
  }

  double get porcentajeInicioJornada {
    int puntuales = 0;
    for (final v in _vendedores) {
      if (v.horaInicioJornada != null) {
        if (v.horaInicioJornada!.hour < 8 ||
            (v.horaInicioJornada!.hour == 8 &&
                v.horaInicioJornada!.minute <= 30)) {
          puntuales++;
        }
      }
    }
    return KpiCalculator.cumplimientoInicioJornada(
      puntuales: puntuales,
      total: _vendedores.length,
    );
  }

  double get porcentajeGeolocalizacion {
    final activos = _vendedores.where((v) => v.geolocalizacionActiva).length;
    return KpiCalculator.cumplimientoGeolocalizacion(
      activos: activos,
      total: _vendedores.length,
    );
  }

  int get semaforoDisciplina {
    final pct = (porcentajeLlamadasCoach + porcentajeInicioJornada) / 2;
    return KpiCalculator.semaforoPorcentaje(pct);
  }

  Future<Map<String, dynamic>> obtenerMetricasProductividad() async {
    final hoy = DateTime.now();
    final rvcList = await DataService.getRvcByFecha(hoy);
    double ventaTotal = 0;
    double recaudoTotal = 0;
    int clientesVisitados = 0;
    double presupuestoTotal = 0;

    for (final r in rvcList) {
      ventaTotal += r.ventaTotal;
      recaudoTotal += r.recaudoTotal;
      clientesVisitados += r.clientesVisitados;
      final v = await DataService.getVendedor(r.vendedorId);
      if (v != null) presupuestoTotal += v.presupuestoDiario;
    }

    final ppvcList = await DataService.getPpvcByFecha(hoy);
    int clientesProgramados = 0;
    for (final p in ppvcList) {
      clientesProgramados += p.clientesProgramados;
    }

    return {
      'ventaTotal': ventaTotal,
      'recaudoTotal': recaudoTotal,
      'clientesVisitados': clientesVisitados,
      'clientesProgramados': clientesProgramados,
      'presupuestoTotal': presupuestoTotal,
      'porcentajePresupuesto': presupuestoTotal > 0
          ? (ventaTotal / presupuestoTotal) * 100
          : 0,
      'ticketPromedio': clientesVisitados > 0
          ? ventaTotal / clientesVisitados
          : 0,
    };
  }

  Future<List<Map<String, dynamic>>> obtenerRankingVendedores() async {
    final hoy = DateTime.now();
    final rvcList = await DataService.getRvcByFecha(hoy);
    final resultados = <Map<String, dynamic>>[];

    for (final r in rvcList) {
      final v = await DataService.getVendedor(r.vendedorId);
      if (v == null) continue;
      final pctPresup = v.presupuestoDiario > 0
          ? (r.ventaTotal / v.presupuestoDiario) * 100
          : 0;
      final llamadasCount = llamadasDelContactado(v.nombre).length;
      resultados.add({
        'vendedor': v,
        'venta': r.ventaTotal,
        'recaudo': r.recaudoTotal,
        'clientesVisitados': r.clientesVisitados,
        'pctPresupuesto': pctPresup,
        'llamadasRecibidas': llamadasCount,
        'score': pctPresup * 0.4 + (llamadasCount >= 2 ? 30 : 0) + (r.clientesVisitados * 2),
      });
    }

    resultados.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return resultados;
  }
}
