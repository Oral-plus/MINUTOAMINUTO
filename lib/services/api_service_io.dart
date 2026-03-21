import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'debug_alert_service.dart';
import 'api_service.dart';

/// Implementación nativa (Android/iOS/Desktop) de subida de audio.
Future<String?> uploadAudioFileImpl(String registroId, String rutaAudio, {bool isPuntoB = false}) async {
  final file = File(rutaAudio);
  if (!await file.exists()) {
    debugPrint('uploadAudioFile: archivo no existe: $rutaAudio');
    return null;
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  final b64 = base64Encode(bytes);
  final ext = rutaAudio.toLowerCase().split('.').last;
  final mime = switch (ext) {
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    'aac' => 'audio/aac',
    'm4a' => 'audio/mp4',
    _ => 'audio/mp4',
  };
  final suffix = isPuntoB ? 'audio-punto-b' : 'audio';
  final sizeKb = (bytes.length / 1024).toStringAsFixed(0);
  DebugAlertService.info('Subiendo audio $suffix ($sizeKb KB)');
  try {
    final base = ApiConfig.baseUrl;
    final res = await http.post(
      Uri.parse('$base/llamadas/$registroId/$suffix'),
      body: jsonEncode({
        'audioBase64': b64,
        'mimeType': mime,
        'filename': 'audio_${registroId}_${isPuntoB ? "B" : "A"}.$ext'
      }),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'MinutoAMinuto/2.2.1 (Android)',
      },
    ).timeout(const Duration(seconds: 90));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final parsed = jsonDecode(res.body);
      String? url = parsed?['audioUrl'] as String? ?? parsed?['url'] as String?;
      // Si la URL es relativa, convertirla a absoluta
      if (url != null && url.isNotEmpty && !url.startsWith('http')) {
        url = '${ApiConfig.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
      }
      final msg = url != null ? 'Audio subido: $url' : 'Audio subido correctamente';
      DebugAlertService.success(msg);
      return url;
    }
    debugPrint('uploadAudioFile: HTTP ${res.statusCode}: ${res.body}');
  } catch (e) {
    debugPrint('uploadAudioFile error: $e');
  }
  return null;
}

Future<void> uploadAudioPuntoBImpl(String registroId, String rutaAudio) async {
  final file = File(rutaAudio);
  if (!await file.exists()) return;
  final bytes = await file.readAsBytes();
  final b64 = base64Encode(bytes);
  final ext = rutaAudio.toLowerCase().split('.').last;
  final mime = switch (ext) {
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    'aac' => 'audio/aac',
    _ => 'audio/mp4',
  };
  final body = {'audioBase64': b64, 'mimeType': mime};
  final base = ApiConfig.baseUrl;
  final res = await http.post(
    Uri.parse('$base/llamadas/$registroId/audio-punto-b'),
    body: jsonEncode(body),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'MinutoAMinuto/2.2.1 (Android)',
    },
  ).timeout(ApiService.writeRequestTimeout);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('API Error ${res.statusCode}: ${res.body}');
  }
  DebugAlertService.success('Audio punto B subido correctamente');
}
