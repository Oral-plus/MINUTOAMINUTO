import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Obtiene la IP pública desde donde se realiza/contesta la llamada.
class IpService {
  static bool get _isWeb => kIsWeb;
  static const _timeout = Duration(seconds: 4);

  static Future<String?> getPublicIp() async {
    if (_isWeb) return null;
    try {
      final resp = await http
          .get(Uri.parse('https://api.ipify.org'))
          .timeout(_timeout);
      if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
        return resp.body.trim();
      }
    } catch (e) {
      debugPrint('IpService: $e');
    }
    return null;
  }
}
