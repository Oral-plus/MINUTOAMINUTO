import 'dart:collection';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Alertas temporales para pruebas de conectividad y guardado.
/// Desactivar en producción: `DebugAlertService.enabled = false`.
class DebugAlertService {
  static bool enabled = false;

  static final Queue<_DebugToast> _queue = Queue<_DebugToast>();
  static final Map<String, DateTime> _lastByMessage = <String, DateTime>{};
  static bool _showing = false;

  static void info(String message) => _enqueue(message, Colors.black87);
  static void success(String message) => _enqueue(message, Colors.black54);
  static void warning(String message) => _enqueue(message, Colors.black54);
  static void error(String message) => _enqueue(message, Colors.black);

  static void _enqueue(String message, Color color) {
    if (!enabled) return;
    final now = DateTime.now();
    final prev = _lastByMessage[message];
    if (prev != null && now.difference(prev).inMilliseconds < 1500) return;
    _lastByMessage[message] = now;
    _queue.add(_DebugToast(message, color));
    _drain();
  }

  static void _drain() {
    if (_showing || _queue.isEmpty) return;
    final messenger = AppKeys.scaffoldMessengerKey.currentState;
    if (messenger == null) {
      Future.delayed(const Duration(milliseconds: 350), _drain);
      return;
    }
    final item = _queue.removeFirst();
    try {
      _showing = true;
      messenger
          .showSnackBar(
            SnackBar(
              content: Text(item.message),
              backgroundColor: item.color,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          )
          .closed
          .whenComplete(() {
            _showing = false;
            _drain();
          });
    } catch (_) {
      // Si todavía no hay Scaffold montado, reintenta luego sin romper el init.
      _showing = false;
      _queue.addFirst(item);
      Future.delayed(const Duration(milliseconds: 350), _drain);
    }
  }
}

class _DebugToast {
  final String message;
  final Color color;
  const _DebugToast(this.message, this.color);
}
