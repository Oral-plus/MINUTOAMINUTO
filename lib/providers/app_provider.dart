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
  bool _geolocalizacionActiva = false;
  bool _monitorLlamadasActivo = false;
  StreamSubscription? _locationSub;
  bool _isInitialized = false;
  String? _initError;
  static const Duration _initTimeout = Duration(seconds: 12);

  List<Vendedor> get vendedores => _vendedores;
  List<Supervisor> get supervisores => _supervisores;
  List<RegistroLlamada> get llamadas => _llamadas;
  List<Alerta> get alertas => _alertas;
  bool get isInitialized => _isInitialized;
  String? get initError => _initError;
  Supervisor? get usuarioActual => _usuarioActual;
  Vendedor? get vendedorActual => _vendedorActual;
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
        await DataService.init();
        final results = await Future.wait([
          _withTimeout(DataService.getVendedores(), 'vendedores'),
          _withTimeout(DataService.getSupervisores(), 'supervisores'),
          _withTimeout(_cargarUsuarioGuardado(), 'usuario guardado'),
        ]);
        _vendedores = results[0] as List<Vendedor>;
        _supervisores = results[1] as List<Supervisor>;
        await _withTimeout(recargarDashboard(), 'dashboard');
        try {
          _monitorLlamadasActivo = await _withTimeout(
            CallMonitorService.isEnabled(),
            'estado del monitor',
          );
        } catch (e) {
          debugPrint('CallMonitor isEnabled: $e');
          _monitorLlamadasActivo = false;
        }
        DebugAlertService.success('Inicio completado');
      } catch (e, st) {
        debugPrint('Error init Minuto a Minuto: $e\n$st');
        DebugAlertService.error('Error al iniciar: $e');
        _initError = 'Error al cargar: $e';
        if (!ApiConfig.useRemoteApi) _initError = '$_initError\n\n¿Ejecutando en Web? Use Android/iOS.';
      } finally {
        _isInitialized = true;
        notifyListeners();
      }
    }, (error, stack) {
      debugPrint('AppProvider zone: $error\n$stack');
      _initError = 'Error inesperado: $error';
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<T> _withTimeout<T>(Future<T> future, String label) async {
    try {
      return await future.timeout(_initTimeout);
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado en: $label');
    }
  }

  Future<void> _cargarUsuarioGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final supervisorId = prefs.getString('supervisor_id');
    final vendedorId = prefs.getString('vendedor_id');
    Supervisor? s;
    Vendedor? v;
    if (supervisorId != null) s = await DataService.getSupervisor(supervisorId);
    if (vendedorId != null) v = await DataService.getVendedor(vendedorId);
    _usuarioActual = s;
    _vendedorActual = v;
  }

  Future<void> loginSupervisor(String id) async {
    _usuarioActual = await DataService.getSupervisor(id);
    _vendedorActual = null;
    if (_usuarioActual != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supervisor_id', id);
      await prefs.remove('vendedor_id');
    }
    notifyListeners();
  }

  Future<void> loginVendedor(String id) async {
    _vendedorActual = await DataService.getVendedor(id);
    _usuarioActual = null;
    if (_vendedorActual != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vendedor_id', id);
      await prefs.remove('supervisor_id');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _usuarioActual = null;
    _vendedorActual = null;
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
      _monitorLlamadasActivo = await CallMonitorService.isEnabled();
    } catch (e, st) {
      debugPrint('iniciarMonitorLlamadas: $e\n$st');
      _monitorLlamadasActivo = false;
    }
    notifyListeners();
  }

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
