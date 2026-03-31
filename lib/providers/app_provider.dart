import 'dart:async';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/alerta.dart';
import '../models/contacto_cartera.dart';
import '../config/api_config.dart';
import '../services/data_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/call_monitor_service.dart';
import '../services/media_projection_service.dart';
import '../services/alertas_service.dart';
import '../services/post_call_notification_service.dart';
import '../services/debug_alert_service.dart';
import '../services/battery_optimization_service.dart';
import '../services/sync_service.dart';
import '../utils/kpi_calculator.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/samsung_setup_wizard.dart';

class AppProvider with ChangeNotifier {
  List<Vendedor> _vendedores = [];
  List<Supervisor> _supervisores = [];
  List<RegistroLlamada> _llamadas = [];
  List<Alerta> _alertas = [];
  List<ContactoCartera> _contactosCartera = [];
  List<String> _vendedoresSap = [];
  List<dynamic> _equipoJerarquico = [];
  Supervisor? _usuarioActual;
  Vendedor? _vendedorActual;
  String? _storedSupervisorId;
  String? _storedVendedorId;
  bool _geolocalizacionActiva = false;
  bool _monitorLlamadasActivo = false;
  double? _lastGpsLat;
  double? _lastGpsLng;
  DateTime? _lastGpsEnvio;
  String? _lastGpsError;
  bool _batteryOptimizationDisabled = true;
  StreamSubscription? _locationSub;
  Timer? _permCheckTimer;
  Timer? _gpsBackgroundTimer;
  bool _isInitialized = false;
  bool _sessionResolved = false; // true cuando sabemos si hay sesión o no
  String? _initError;
  static const Duration _initTimeout = Duration(seconds: 8);

  List<Vendedor> get vendedores => _vendedores;
  List<Supervisor> get supervisores => _supervisores;
  List<RegistroLlamada> get llamadas => _llamadas;
  List<Alerta> get alertas => _alertas;
  List<ContactoCartera> get contactosCartera => _contactosCartera;
  List<String> get vendedoresSap => _vendedoresSap;
  List<dynamic> get equipoJerarquico => _equipoJerarquico;
  bool get isInitialized => _isInitialized && _sessionResolved;
  String? get initError => _initError;
  Supervisor? get usuarioActual => _usuarioActual;
  Vendedor? get vendedorActual => _vendedorActual;
  bool get hasStoredSession =>
      _storedSupervisorId != null || _storedVendedorId != null;
  bool get geolocalizacionActiva => _geolocalizacionActiva;
  bool get monitorLlamadasActivo => _monitorLlamadasActivo;
  double? get lastGpsLat => _lastGpsLat;
  double? get lastGpsLng => _lastGpsLng;
  DateTime? get lastGpsEnvio => _lastGpsEnvio;
  String? get lastGpsError => _lastGpsError;
  bool get batteryOptimizationDisabled => _batteryOptimizationDisabled;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool get esCoach => _usuarioActual?.esCoach ?? false;
  bool get esKam => _usuarioActual?.esKam ?? false;
  bool get esJefe => _usuarioActual?.esJefe ?? false;
  bool get esVendedor => _vendedorActual != null;

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_theme_mode',
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> init({bool force = false}) async {
    if (_isInitialized && !force) return;
    if (force) {
      _sessionResolved = false;
      _initError = null;
      _vendedores = [];
      _supervisores = [];
      _llamadas = [];
      _alertas = [];
      _contactosCartera = [];
      _vendedoresSap = [];
      _equipoJerarquico = [];
      _usuarioActual = null;
      _vendedorActual = null;
      notifyListeners();
    }
    await runZonedGuarded(
      () async {
        try {
          DebugAlertService.info('Inicializando app...');
          await DataService.init().timeout(
            const Duration(seconds: 10),
            onTimeout: () {},
          );
          SyncService.init();
          await _readStoredSessionIds().timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              _storedSupervisorId = null;
              _storedVendedorId = null;
            },
          );
          DebugAlertService.success('Inicio instantáneo completado');
        } catch (e, st) {
          debugPrint('Error init Minuto a Minuto: $e\n$st');
          if (e is TimeoutException ||
              e.toString().contains('Tiempo de espera')) {
            _storedSupervisorId = null;
            _storedVendedorId = null;
            _initError = null;
          } else {
            DebugAlertService.error('Error al iniciar: $e');
            _initError = 'Error al cargar: $e';
            if (!ApiConfig.useRemoteApi) {
              _initError =
                  '$_initError\n\n¿Ejecutando en Web? Use Android/iOS.';
            }
          }
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
      },
      (error, stack) {
        debugPrint('AppProvider zone: $error\n$stack');
        _initError = 'Error inesperado: $error';
        _isInitialized = true;
        _sessionResolved = true;
        notifyListeners();
      },
    );
  }

  Future<void> _warmUpPostInit() async {
    // Resolver usuario guardado con timeout máximo de 12s
    try {
      await Future.any([
        _runInitStep(
          'resolver sesión guardada',
          _resolverUsuarioGuardado,
          timeout: const Duration(seconds: 12),
        ),
        Future.delayed(const Duration(seconds: 12)),
      ]);
    } catch (_) {}

    // Siempre marcar como resuelto para no bloquear la app
    if (!_sessionResolved) {
      _sessionResolved = true;
      notifyListeners();
    }

    // Pedir permisos necesarios en cada arranque (si no están concedidos)
    unawaited(_requestAllPermissions());
    // Calentar GPS en cada arranque
    unawaited(_warmupGps());

    // Cargar listas EN SECUENCIA con un pequeño delay para evitar 429
    try {
      _vendedores = await _loadListOrEmpty<Vendedor>(
        DataService.getVendedores,
        'vendedores (background)',
        timeout: _initTimeout,
      );

      await Future.delayed(const Duration(milliseconds: 250));

      _supervisores = await _loadListOrEmpty<Supervisor>(
        DataService.getSupervisores,
        'supervisores (background)',
        timeout: _initTimeout,
      );
    } catch (e) {
      debugPrint('_warmUpPostInit error cargando listas: $e');
    }

    notifyListeners();
  }

  Future<List<T>> _loadListOrEmpty<T>(
    Future<List<T>> Function() loader,
    String label, {
    Duration? timeout,
  }) async {
    try {
      return await _withTimeout(loader(), label, timeout: timeout);
    } catch (e) {
      DebugAlertService.warning('Init parcial: no se cargó $label ($e)');
      return <T>[];
    }
  }

  Future<void> _runInitStep(
    String label,
    Future<void> Function() action, {
    Duration? timeout,
  }) async {
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
    final savedTheme = prefs.getString('app_theme_mode');
    _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
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
      // Sin context, se salta el wizard visual.
      unawaited(asegurarMonitorConWizardOpcional(null));
      // Arrancar GPS en restauración de sesión
      unawaited(iniciarGeolocalizacion());
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
      if (_usuarioActual!.telefono != null &&
          _usuarioActual!.telefono!.trim().isNotEmpty) {
        await prefs.setString(
          'numero_telefono_propietario',
          _usuarioActual!.telefono!.trim(),
        );
      }
      // Calentar GPS y arrancar stream para que el monitor tenga coordenadas frescas
      unawaited(iniciarGeolocalizacion());
    }
    notifyListeners();
    // NOTA: EL WIZARD SE LLAMARÁ EXPLÍCITAMENTE EN LA PANTALLA DE LOGIN
    // unawaited(_asegurarMonitorConWizardOpcional(context));
  }

  Future<void> loginVendedor(String id) async {
    _vendedorActual = await DataService.getVendedor(id);
    _usuarioActual = null;
    if (_vendedorActual != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vendedor_id', id);
      await prefs.remove('supervisor_id');
      await prefs.setString('user_cargo', 'VENDEDOR');
      _storedVendedorId = id;
      _storedSupervisorId = null;
      if (_vendedorActual!.telefono != null &&
          _vendedorActual!.telefono!.trim().isNotEmpty) {
        await prefs.setString(
          'numero_telefono_propietario',
          _vendedorActual!.telefono!.trim(),
        );
      }
      // Calentar GPS y arrancar stream (siempre, independiente del telefono)
      unawaited(iniciarGeolocalizacion());
    }
    notifyListeners();
    // NOTA: EL WIZARD SE LLAMARÁ EXPLÍCITAMENTE EN LA PANTALLA DE LOGIN
    // unawaited(_asegurarMonitorConWizardOpcional(context));
  }

  // Cambiado: Solo la lógica base de encendido. La invocación se hace tras revisar el Wizard.
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

  /// Nuevo: Llama al Wizard Visual del Samsung (si aplica) y luego enciende el monitor
  Future<void> asegurarMonitorConWizardOpcional(BuildContext? context) async {
    if (context != null && context.mounted) {
      // Si es Samsung y nunca vio el aviso, mostrarlo ahora (bloquea hasta que cierre)
      await SamsungSetupWizard.checkAndShow(context);
    }
    await _asegurarMonitorActivo();
  }

  Future<void> actualizarTelefonoActual(String numero) async {
    final prefs = await SharedPreferences.getInstance();
    final numLimpio = numero.trim();

    // 1. Guardar en SharedPreferences para la lógica de correlación nativa
    if (numLimpio.isEmpty) {
      await prefs.remove('numero_telefono_propietario');
    } else {
      await prefs.setString('numero_telefono_propietario', numLimpio);
    }

    // 2. Actualizar en memoria y sincronizar teléfono con servidor
    if (_usuarioActual != null) {
      _usuarioActual = _usuarioActual!.copyWith(telefono: numLimpio);
      // PATCH directo (servidor con fix desplegado)
      unawaited(
        ApiService.updateTelefono(
          _usuarioActual!.id,
          numLimpio,
          isSupervisor: true,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // POST upsert como garantía (funciona con cualquier versión del servidor)
      try {
        await DataService.insertSupervisor(_usuarioActual!);
      } catch (e) {
        debugPrint('actualizarTelefonoActual: error upsert supervisor: $e');
      }
    } else if (_vendedorActual != null) {
      _vendedorActual = _vendedorActual!.copyWith(telefono: numLimpio);
      unawaited(
        ApiService.updateTelefono(
          _vendedorActual!.id,
          numLimpio,
          isSupervisor: false,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      try {
        await DataService.insertVendedor(_vendedorActual!);
      } catch (e) {
        debugPrint('actualizarTelefonoActual: error upsert vendedor: $e');
      }
    }

    notifyListeners();
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

  /// Limpia datos de sesión/caché local para reintentar inicio limpio.
  Future<void> forceClearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _storedSupervisorId = null;
      _storedVendedorId = null;
      _usuarioActual = null;
      _vendedorActual = null;
      _vendedores = [];
      _supervisores = [];
      _llamadas = [];
      _alertas = [];
      _contactosCartera = [];
      _vendedoresSap = [];
      _equipoJerarquico = [];
      _isInitialized = false;
      _sessionResolved = false;
      _initError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('forceClearCache error: $e');
      rethrow;
    }
  }

  Future<void> cargarEquipo() async {
    _vendedores = await DataService.getVendedores();
    _supervisores = await DataService.getSupervisores();
    notifyListeners();
  }

  Future<void> cargarDatosHoy() async {
    final hoy = DateTime.now();
    _llamadas = await DataService.getRegistroLlamadas(desde: hoy, hasta: hoy);
    notifyListeners();
  }

  Future<void> recargarDashboard() async {
    final hoy = DateTime.now();
    _llamadas = await DataService.getRegistroLlamadas(desde: hoy, hasta: hoy);

    // Pequeño retardo para evitar ráfagas que disparen el error 429 en el servidor/proxy
    await Future.delayed(const Duration(milliseconds: 100));

    if (!DataService.useDemoData) {
      try {
        await AlertasService.verificarAlertasDiarias();
      } catch (e) {
        debugPrint('recargarDashboard verificarAlertas: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 100));

    // Coaches ven solo sus alertas; jefe/KAM ven todas
    final String? filtroSupervisor = esCoach ? _usuarioActual?.id : null;
    _alertas = await DataService.getAlertasPendientes(
      supervisorId: filtroSupervisor,
    );

    if (!DataService.useDemoData) {
      await _notificarCoachAlertas8am();
    }

    await Future.delayed(const Duration(milliseconds: 100));
    await _cargarDatosSapParaDashboard();
    notifyListeners();
  }

  String _mapCargoSap() {
    if (_usuarioActual == null) return '';
    if (_usuarioActual!.esCoach) return 'COACH';
    if (_usuarioActual!.esKam) return 'KAM';
    if (_usuarioActual!.esJefe) return 'JEFE DE VENTAS';
    return '';
  }

  Future<void> _cargarDatosSapParaDashboard() async {
    if (_usuarioActual == null) {
      _contactosCartera = [];
      _vendedoresSap = [];
      _equipoJerarquico = [];
      return;
    }
    final cargoSap = _mapCargoSap();
    if (cargoSap.isEmpty) return;
    final nombre = _usuarioActual!.nombre;
    try {
      _contactosCartera = await ApiService.getContactosCartera(
        cargo: cargoSap,
        nombre: nombre,
      );
    } catch (_) {
      _contactosCartera = [];
    }

    await Future.delayed(const Duration(milliseconds: 150));

    try {
      if (cargoSap == 'COACH' || cargoSap == 'KAM') {
        _vendedoresSap = await ApiService.getVendedoresSap(cargoSap, nombre);
      } else {
        _vendedoresSap = [];
      }
    } catch (_) {
      _vendedoresSap = [];
    }

    await Future.delayed(const Duration(milliseconds: 150));

    try {
      // Cargar jerarquía para cualquier supervisor (JEFE, KAM, COACH)
      if (cargoSap == 'JEFE DE VENTAS' ||
          cargoSap == 'KAM' ||
          cargoSap == 'COACH') {
        _equipoJerarquico = await ApiService.getEquipoJerarquico();
      } else {
        _equipoJerarquico = [];
      }
    } catch (_) {
      _equipoJerarquico = [];
    }
  }

  /// Activa datos de demostración para presentaciones. Carga todo el dashboard con datos de prueba.
  Future<void> cargarDatosDemo() async {
    DataService.useDemoData = true;
    _vendedores = await DataService.getVendedores();
    _supervisores = await DataService.getSupervisores();
    final coach = _supervisores.isNotEmpty ? _supervisores.first : null;
    if (coach != null && _usuarioActual == null) {
      _usuarioActual = coach;
    }
    await recargarDashboard();
    notifyListeners();
  }

  /// Desactiva modo demo y recarga datos reales.
  Future<void> salirModoDemo() async {
    DataService.useDemoData = false;
    await cargarEquipo();
    await recargarDashboard();
    notifyListeners();
  }

  bool get modoDemoActivo => DataService.useDemoData;

  /// Muestra notificaciones locales para todas las alertas pendientes del usuario.
  /// Evita duplicados usando claves por alerta + día.
  Future<void> _notificarCoachAlertas8am() async {
    if (_usuarioActual == null) return;
    final coachId = _usuarioActual!.id;
    final hoy = DateTime.now();
    final claveHoy =
        '${hoy.year}${hoy.month.toString().padLeft(2, '0')}${hoy.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();

    for (final a in _alertas) {
      // Solo alertas del coach actual (o sin filtro de supervisor para JEFE/KAM)
      if (a.supervisorId != null && a.supervisorId != coachId) continue;

      final key = 'notif_${a.id}_$claveHoy';
      if (prefs.getBool(key) == true) continue;

      // Usar el servicio específico para 8am o el genérico para el resto
      if (a.tipo == TipoAlerta.vendedorSinLlamada8am && a.vendedorId != null) {
        final nombre = a.mensaje.replaceAll(
          ' no ha hecho ninguna llamada antes de las 8:20',
          '',
        );
        await PostCallNotificationService.showAlertaVendedorSinLlamada8am(nombre);
      } else {
        await PostCallNotificationService.showAlertaGeneral(
          titulo: a.titulo,
          cuerpo: a.mensaje,
          claveUnica: '${a.id}_$claveHoy',
        );
      }
      await prefs.setBool(key, true);
    }
  }

  List<Vendedor> vendedoresPorCoach(String coachId) {
    return _vendedores.where((v) => v.coachId == coachId).toList();
  }

  List<RegistroLlamada> llamadasDelContactado(String nombre) {
    return _llamadas.where((l) => l.nombreContactado == nombre).toList();
  }

  Future<({String savedTo, String registroId, bool hasGps, bool retrying})>
  registrarLlamada(RegistroLlamada r) async {
    if (r.duracionMinutos < AppConstants.duracionMinimaLlamada) {
      throw Exception(
        'La duración mínima debe ser ${AppConstants.duracionMinimaLlamada} minutos',
      );
    }
    if (!r.confirmacionVeracidad) {
      throw Exception('Debe confirmar la veracidad del registro');
    }
    final result = await DataService.insertRegistroLlamada(r);
    await cargarDatosHoy();
    notifyListeners();
    return result;
  }

  /// Revisa y solicita todos los permisos requeridos por la app en cada arranque.
  Future<void> _requestAllPermissions() async {
    final permisos = [
      Permission.location,
      Permission.locationAlways,
      Permission.phone,
      Permission.contacts,
      Permission.microphone,
      Permission.notification,
      Permission.storage,
      Permission.manageExternalStorage,
    ];
    for (final p in permisos) {
      try {
        final status = await p.status;
        if (!status.isGranted) await p.request();
      } catch (_) {}
    }
    // Iniciar loop de verificación persistente
    _startPermissionCheckLoop();
  }

  /// Inicia el loop que verifica permisos cada 5 minutos y muestra notificación persistente si faltan.
  void _startPermissionCheckLoop() {
    _permCheckTimer?.cancel();
    // Verificar de inmediato, luego repetir cada 5 minutos
    unawaited(_checkAndNotifyPermissions());
    _permCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_checkAndNotifyPermissions());
    });
  }

  /// Comprueba qué permisos faltan y muestra/cancela la notificación persistente.
  Future<void> _checkAndNotifyPermissions() async {
    if (kIsWeb) return;
    try {
      final missing = await _getMissingPermissions();
      if (missing.isEmpty) {
        await PostCallNotificationService.cancelPermissosFaltantes();
      } else {
        await PostCallNotificationService.showPermissosFaltantes(missing);
      }
    } catch (_) {}
  }

  /// Devuelve la lista de nombres de permisos críticos que no están concedidos.
  Future<List<String>> _getMissingPermissions() async {
    final missing = <String>[];
    try {
      if (!await Permission.phone.isGranted) missing.add('Teléfono');
      if (!await Permission.microphone.isGranted) missing.add('Micrófono');
      if (!await Permission.notification.isGranted) missing.add('Notificaciones');
      final locOk = await Permission.locationAlways.isGranted ||
          await Permission.locationWhenInUse.isGranted;
      if (!locOk) missing.add('Ubicación');
      if (!await Permission.manageExternalStorage.isGranted &&
          !await Permission.storage.isGranted) {
        missing.add('Almacenamiento');
      }
    } catch (_) {}
    return missing;
  }

  /// Solicita permiso de ubicación y obtiene una posición inicial en background.
  Future<void> _warmupGps() async {
    try {
      await LocationService.requestPermission();
      // Intentar caché primero (funciona aunque el GPS esté apagado)
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
      if (pos == null) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.reduced,
            ),
          ).timeout(const Duration(seconds: 20));
        } catch (_) {}
      }
      if (pos != null) LocationService.updateFromStream(pos);
    } catch (_) {}
  }

  Future<void> iniciarGeolocalizacion() async {
    _geolocalizacionActiva = await LocationService.requestPermission();
    if (_geolocalizacionActiva) {
      _locationSub?.cancel();
      _locationSub = LocationService.positionStream.listen((pos) {
        LocationService.updateFromStream(pos);
        _lastGpsLat = pos.latitude;
        _lastGpsLng = pos.longitude;
        notifyListeners();
        _enviarUbicacionActual(pos).catchError((_) {});
      });
      _gpsBackgroundTimer?.cancel();
      _gpsBackgroundTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        final pos = LocationService.lastKnown;
        if (pos != null) _enviarUbicacionActual(pos).catchError((_) {});
      });
      // Primer envío inmediato con lastKnown si ya hay posición
      final posInicial = LocationService.lastKnown;
      if (posInicial != null) {
        _lastGpsLat = posInicial.latitude;
        _lastGpsLng = posInicial.longitude;
        notifyListeners();
        _enviarUbicacionActual(posInicial).catchError((_) {});
      } else {
        // Sin lastKnown: esperar primera señal del stream
        LocationService.getCurrentPosition().then((pos) {
          if (pos != null) {
            _lastGpsLat = pos.latitude;
            _lastGpsLng = pos.longitude;
            notifyListeners();
            _enviarUbicacionActual(pos).catchError((_) {});
          }
        }).catchError((_) {});
      }
    }
    notifyListeners();
  }

  /// Envía la posición dada al servidor para el usuario activo.
  Future<void> _enviarUbicacionActual(Position pos) async {
    try {
      final userId = _vendedorActual?.id ?? _usuarioActual?.id;
      final nombre = _vendedorActual?.nombre ?? _usuarioActual?.nombre ?? '';
      final cargo = _vendedorActual != null ? 'VENDEDOR' : (_usuarioActual?.cargo.valor ?? '');
      if (userId == null) return;
      await DataService.guardarUbicacion(
        vendedorId: userId,
        lat: pos.latitude,
        lng: pos.longitude,
        nombre: nombre,
        cargo: cargo,
      );
      _lastGpsEnvio = DateTime.now();
      _lastGpsError = null;
      notifyListeners();
    } catch (e) {
      _lastGpsError = e.toString();
      notifyListeners();
    }
  }

  Future<void> detenerGeolocalizacion() async {
    _locationSub?.cancel();
    _gpsBackgroundTimer?.cancel();
    _gpsBackgroundTimer = null;
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

  Future<void> verificarOptimizacionBateria() async {
    try {
      _batteryOptimizationDisabled =
          await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    } catch (_) {
      _batteryOptimizationDisabled = true;
    }
    notifyListeners();
  }

  Future<void> solicitarIgnorarBateria() async {
    await BatteryOptimizationService.stopOptimizingBatteryUsage();
    await verificarOptimizacionBateria();
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
        'score':
            pctPresup * 0.4 +
            (llamadasCount >= 2 ? 30 : 0) +
            (r.clientesVisitados * 2),
      });
    }

    resultados.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    return resultados;
  }
}
