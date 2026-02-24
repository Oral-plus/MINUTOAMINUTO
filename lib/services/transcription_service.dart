import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'data_service.dart';

/// Transcribe audio con IA (Gemini) vía API.
class TranscriptionService {
  static String get _base => ApiConfig.baseUrl;

  /// Transcribe el archivo de audio y guarda el resultado en el registro.
  static Future<String?> transcribeAndSave({
    required String registroId,
    required String rutaAudio,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final file = File(rutaAudio);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = rutaAudio.endsWith('.m4a') ? 'audio/mp4' : 'audio/mpeg';
      final r = await http.post(
        Uri.parse('$_base/transcribe'),
        body: jsonEncode({'audioBase64': b64, 'mimeType': mime}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final text = data['text'] as String?;
      if (text == null || text.isEmpty) return null;
      await DataService.updateRegistroLlamadaTranscripcion(registroId, text);
      return text;
    } catch (e) {
      debugPrint('TranscriptionService error: $e');
      return null;
    }
  }
}
