import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../screens/mis_llamadas_screen.dart';

/// Muestra notificaciones profesionales al terminar una llamada,
/// al detectar errores de sincronización o alertas de gestión.
class PostCallNotificationService {
  static const _keyPendingEditId = 'pending_edit_registro_id';
  static const _logoAsset = 'assets/images/LLAMADA.png';
  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;
  static Uint8List? _logoBytes;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static FlutterLocalNotificationsPlugin get _instance {
    _plugin ??= FlutterLocalNotificationsPlugin();
    return _plugin!;
  }

  static Future<void> init() async {
    if (_initialized || !_isAndroid) return;
    try {
      const android = AndroidInitializationSettings(
        '@drawable/ic_notification_logo',
      );
      const settings = InitializationSettings(android: android);
      await _instance.initialize(
        settings,
        onDidReceiveNotificationResponse: _onTap,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('PostCallNotificationService init error: $e');
    }
  }

  static void _onTap(NotificationResponse res) {
    final id = res.payload;
    if (id != null && id.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_keyPendingEditId, id);
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        final nav = AppKeys.navigatorKey.currentState;
        if (nav != null) {
          nav.push(
            MaterialPageRoute(builder: (_) => const MisLlamadasScreen()),
          );
        }
      });
    }
  }

  static Future<String?> getPendingEditRegistroId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyPendingEditId);
    if (id != null) await prefs.remove(_keyPendingEditId);
    return id;
  }

  static Future<Uint8List?> _loadLogoBytes() async {
    if (_logoBytes != null) return _logoBytes;
    try {
      _logoBytes = (await rootBundle.load(_logoAsset)).buffer.asUint8List();
      return _logoBytes;
    } catch (_) {
      return null;
    }
  }

  // ─── helper: crea AndroidNotificationDetails profesional (B&W) ─────────────
  static AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String bigText,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    ByteArrayAndroidBitmap? largeIcon,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: channelName, // Agregado para robustez
        summaryText: 'Minuto a Minuto',
      ),
      largeIcon: largeIcon,
      playSound: true,
      enableVibration: true,
    );
  }

  // ─── 1. Llamada grabada y registrada ───────────────────────────────────────
  /// [correlacionada] = true cuando se unió punto A + punto B.
  /// [guardadoEn] = 'API' | 'local'.
  static Future<void> showLlamadaGrabadaYRegistrada(
    String registroId,
    String contacto,
    int duracionMinutos, {
    bool correlacionada = false,
    String? guardadoEn,
  }) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final durTexto = duracionMinutos == 1 ? '1 minuto' : '$duracionMinutos minutos';
      final destino = guardadoEn == 'API' ? 'Registro disponible en el servidor.' : '';

      final titulo = correlacionada
          ? 'Llamada completa registrada'
          : 'Llamada registrada correctamente';

      final cuerpo = correlacionada
          ? 'La llamada con $contacto fue registrada completa (ambos lados). Duración: $durTexto. $destino'
          : 'La llamada con $contacto fue guardada. Duración: $durTexto. $destino Toca para revisar el registro.';

      final android = _androidDetails(
        channelId: 'llamada_registrada',
        channelName: 'Llamadas registradas',
        channelDescription: 'Confirmación al guardar una llamada en Mis Llamadas',
        bigText: cuerpo,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );

      await _instance.show(
        registroId.hashCode.abs() % 100000,
        titulo,
        cuerpo,
        NotificationDetails(android: android),
        payload: registroId,
      );
    } catch (e) {
      debugPrint('PostCallNotification showLlamadaGrabadaYRegistrada: $e');
    }
  }

  // ─── 2. Alerta 8:20 AM — vendedor sin llamada ──────────────────────────────
  static Future<void> showAlertaVendedorSinLlamada8am(String vendedorNombre) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final cuerpo =
          '$vendedorNombre no ha registrado ninguna llamada antes de las 8:20 a.m. Verifica el estado de su gestión.';

      final android = _androidDetails(
        channelId: 'alerta_8am',
        channelName: 'Alertas de gestión',
        channelDescription: 'Vendedores sin llamadas registradas antes de las 8:20 a.m.',
        bigText: cuerpo,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );

      final id = '8am_${vendedorNombre}_${DateTime.now().day}'.hashCode.abs() % 100000;
      await _instance.show(
        id,
        'Sin llamadas registradas — 8:20 a.m.',
        cuerpo,
        NotificationDetails(android: android),
      );
    } catch (e) {
      debugPrint('PostCallNotification showAlertaVendedorSinLlamada8am: $e');
    }
  }

  // ─── 3. Error de sincronización ────────────────────────────────────────────
  static Future<void> showSyncError(String registroId, String contacto, String motivo) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final cuerpo =
          'La llamada con $contacto no pudo sincronizarse con el servidor. '
          'Motivo: $motivo. El registro permanece guardado localmente y se reintentará de forma automática.';

      final android = _androidDetails(
        channelId: 'sync_error',
        channelName: 'Errores de sincronización',
        channelDescription: 'Alertas cuando una llamada no se pudo enviar al servidor',
        bigText: cuerpo,
        importance: Importance.high,
        priority: Priority.high,
        // Sin color rojo — solo blanco/negro
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );

      await _instance.show(
        ('err_$registroId').hashCode.abs() % 100000,
        'No se pudo sincronizar la llamada',
        cuerpo,
        NotificationDetails(android: android),
        payload: registroId,
      );
    } catch (e) {
      debugPrint('showSyncError: $e');
    }
  }

  // ─── 4. Permisos faltantes (persistente hasta que se activen) ─────────────
  static const _idPermissosFaltantes = 999001;
  static Future<void> showPermissosFaltantes(List<String> nombresPermisos) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final lista = nombresPermisos.join(', ');
      final cuerpo =
          'Minuto a Minuto necesita estos permisos para funcionar correctamente: $lista. '
          'Toca aquí para abrirlos en Ajustes.';

      final android = AndroidNotificationDetails(
        'permisos_faltantes',
        'Permisos requeridos',
        channelDescription: 'Recordatorio persistente de permisos faltantes',
        importance: Importance.max,
        priority: Priority.max,
        ongoing: true,
        autoCancel: false,
        styleInformation: BigTextStyleInformation(
          cuerpo,
          htmlFormatBigText: false,
          contentTitle: '⚠️ Permisos requeridos (${nombresPermisos.length})',
          summaryText: 'Minuto a Minuto',
        ),
        playSound: false,
        enableVibration: false,
      );

      await _instance.show(
        _idPermissosFaltantes,
        '⚠️ Permisos requeridos',
        cuerpo,
        NotificationDetails(android: android),
        payload: 'permisos',
      );
    } catch (e) {
      debugPrint('showPermissosFaltantes: $e');
    }
  }

  static Future<void> cancelPermissosFaltantes() async {
    if (!_isAndroid || !_initialized) return;
    try {
      await _instance.cancel(_idPermissosFaltantes);
    } catch (_) {}
  }

  // ─── 5. Alerta general (cualquier tipo de alerta del sistema) ──────────────
  static Future<void> showAlertaGeneral({
    required String titulo,
    required String cuerpo,
    required String claveUnica,
  }) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final android = _androidDetails(
        channelId: 'alertas_gestion',
        channelName: 'Alertas de gestión',
        channelDescription: 'Alertas automáticas del sistema de gestión',
        bigText: cuerpo,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );
      final id = claveUnica.hashCode.abs() % 100000;
      await _instance.show(
        id,
        titulo,
        cuerpo,
        NotificationDetails(android: android),
      );
    } catch (e) {
      debugPrint('showAlertaGeneral: $e');
    }
  }

  // ─── 6. Sincronización exitosa (reintento en background) ───────────────────
  static Future<void> showSyncOk(String registroId, String contacto, int attempt) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final cuerpo =
          'La llamada con $contacto se sincronizó correctamente con el servidor'
          '${attempt > 1 ? ' (intento $attempt)' : ''}. El registro ya está disponible en el panel.';

      final android = _androidDetails(
        channelId: 'sync_ok',
        channelName: 'Sincronización exitosa',
        channelDescription: 'Confirmación cuando una llamada pendiente se envía al servidor',
        bigText: cuerpo,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );

      await _instance.show(
        ('ok_$registroId').hashCode.abs() % 100000,
        'Llamada sincronizada con el servidor',
        cuerpo,
        NotificationDetails(android: android),
        payload: registroId,
      );
    } catch (e) {
      debugPrint('showSyncOk: $e');
    }
  }
}
