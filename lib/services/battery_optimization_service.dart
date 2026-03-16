import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('minutoaminuto/audio_route');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (e) {
      debugPrint('BatteryOptimizationService error: $e');
      return true;
    }
  }

  static Future<void> stopOptimizingBatteryUsage() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopOptimizingBatteryUsage');
    } catch (e) {
      debugPrint('BatteryOptimizationService stop error: $e');
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('BatteryOptimizationService open error: $e');
    }
  }
}

// Helper to check platform safely
class Platform {
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
}
