import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../screens/mis_llamadas_screen.dart';

/// Muestra notificación "Datos guardados" al terminar una llamada.
/// Al tocar, abre la app para editar observaciones.
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

  /// Notificación única: llamada grabada y registrada en Mis Llamadas (con duración).
  /// [correlacionada] = true cuando el audio se unió a un registro existente (punto A + punto B).
  /// [guardadoEn] = 'API' o 'local' para indicar dónde se insertó.
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
      final duracionTexto =
          duracionMinutos == 1 ? '1 min' : '$duracionMinutos min';
      final destino = guardadoEn == 'local'
          ? ' (guardada en dispositivo local)'
          : guardadoEn == 'API'
              ? ' (subida a servidor)'
              : '';
      final titulo = correlacionada
          ? 'Llamada correlacionada (punto A + punto B)'
          : 'Llamada grabada y registrada';
      final body = correlacionada
          ? 'Tu audio se unió al registro con $contacto. Duración: $duracionTexto. Ambos lados grabados.$destino'
          : 'Con $contacto. Duración: $duracionTexto.$destino Toca para ver en Mis Llamadas.';
      final android = AndroidNotificationDetails(
        'llamada_registrada',
        'Llamadas grabadas',
        channelDescription:
            'Notificación cuando una llamada se graba y registra en Mis Llamadas',
        importance: Importance.defaultImportance,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );
      await _instance.show(
        registroId.hashCode.abs() % 100000,
        titulo,
        body,
        NotificationDetails(android: android),
        payload: registroId,
      );
    } catch (e) {
      debugPrint('PostCallNotification showLlamadaGrabadaYRegistrada: $e');
    }
  }

  /// Notificación al coach: vendedor sin llamada antes de las 8:20.
  /// Se muestra en el celular del coach cuando abre/refresca el dashboard.
  static Future<void> showAlertaVendedorSinLlamada8am(String vendedorNombre) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final android = AndroidNotificationDetails(
        'alerta_8am',
        'Alerta 8:20',
        channelDescription:
            'Vendedores que no han hecho llamada antes de las 8:20',
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );
      final id = '8am_${vendedorNombre}_${DateTime.now().day}'.hashCode.abs() % 100000;
      await _instance.show(
        id,
        'Alerta 8:20',
        '$vendedorNombre no ha hecho ninguna llamada antes de las 8:20',
        NotificationDetails(android: android),
      );
    } catch (e) {
      debugPrint('PostCallNotification showAlertaVendedorSinLlamada8am: $e');
    }
  }

  /// Notificación cuando se guardó el registro completo en BD/API (legacy).
  static Future<void> showDatosGuardados(
    String registroId,
    String contacto,
  ) async {
    if (!_isAndroid || !_initialized) return;
    try {
      final logo = await _loadLogoBytes();
      final android = AndroidNotificationDetails(
        'datos_guardados',
        'Datos guardados',
        channelDescription: 'Notificación cuando se guarda una llamada',
        importance: Importance.defaultImportance,
        largeIcon: logo != null ? ByteArrayAndroidBitmap(logo) : null,
      );
      await _instance.show(
        registroId.hashCode.abs() % 100000,
        'Datos guardados',
        'Llamada con $contacto registrada. Toca para editar observaciones.',
        NotificationDetails(android: android),
        payload: registroId,
      );
    } catch (e) {
      debugPrint('PostCallNotification error: $e');
    }
  }
}
