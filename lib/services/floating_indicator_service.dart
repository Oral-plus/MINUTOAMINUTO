import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Maneja la burbuja flotante que indica monitor activo.
class FloatingIndicatorService {
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static Future<bool> requestPermissionIfNeeded() async {
    if (!_isAndroid) return false;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (granted) return true;
      final requested = await FlutterOverlayWindow.requestPermission();
      return requested == true;
    } catch (e) {
      debugPrint('FloatingIndicator permission error: $e');
      return false;
    }
  }

  static Future<void> showIfAllowed() async {
    if (!_isAndroid) return;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) return;
      final active = await FlutterOverlayWindow.isActive();
      if (active) return;
      await FlutterOverlayWindow.showOverlay(
        width: 74,
        height: 74,
        alignment: OverlayAlignment.centerLeft,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Minuto a Minuto activo',
        overlayContent: 'Toque: Mis Llamadas | Sostener: Home',
      );
    } catch (e) {
      debugPrint('FloatingIndicator show error: $e');
    }
  }

  static Future<void> close() async {
    if (!_isAndroid) return;
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (!active) return;
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('FloatingIndicator close error: $e');
    }
  }
}
