import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el permiso y la grabación de audio del sistema via MediaProjection.
///
/// MediaProjection captura el audio de reproducción del sistema (voz remota)
/// y lo mezcla con el micrófono (tu voz) en un único archivo WAV.
///
/// El usuario debe aprobar el diálogo del sistema UNA SOLA VEZ.
/// El permiso se recuerda en memoria durante la sesión de la app.
class MediaProjectionService {
  static const _channel = MethodChannel('minutoaminuto/audio_route');
  static const _keyGranted = 'media_projection_granted';

  static bool _hasPermission = false;
  static bool get hasPermission => _hasPermission;

  /// Verifica si ya se concedió el permiso (en memoria, en prefs nativas o en prefs Flutter).
  static Future<bool> checkPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    if (_hasPermission) return true;
    try {
      // Primero preguntar al nativo (que también revisa prefs persistidas)
      final result = await _channel.invokeMethod<bool>('hasMediaProjectionPermission');
      if (result == true) { _hasPermission = true; return true; }
    } catch (_) {}
    try {
      // Fallback: leer de SharedPreferences Flutter
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_keyGranted) ?? false;
      if (saved) { _hasPermission = true; return true; }
    } catch (_) {}
    return false;
  }

  /// Muestra el diálogo del sistema para solicitar permiso MediaProjection.
  /// Retorna `true` si el usuario aprobó, `false` si rechazó.
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestMediaProjectionPermission');
      _hasPermission = result ?? false;
      if (_hasPermission) {
        // Guardar que el usuario aprobó para no volver a pedir
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyGranted, true);
      }
      return _hasPermission;
    } catch (e) {
      debugPrint('MediaProjectionService.requestPermission: $e');
      return false;
    }
  }

  /// Inicia la grabación con MediaProjection para el número dado.
  static Future<void> startRecording(String number) async {
    try {
      await _channel.invokeMethod('startMediaProjectionRecorder', {'number': number});
    } catch (e) {
      debugPrint('MediaProjectionService.startRecording: $e');
    }
  }

  /// Detiene la grabación.
  static Future<void> stopRecording() async {
    try {
      await _channel.invokeMethod('stopMediaProjectionRecorder');
    } catch (e) {
      debugPrint('MediaProjectionService.stopRecording: $e');
    }
  }

  /// Retorna true si el usuario ya aprobó el permiso en alguna sesión anterior.
  static Future<bool> wasEverGranted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyGranted) ?? false;
    } catch (_) {
      return false;
    }
  }
}
