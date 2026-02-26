import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'data_service.dart';

class TranscriptionService {
  static const String _apiKey = 'AIzaSyAtI2xz5kiSnxUn6vejkAeUnN2hAxOlxZ8';
  static const List<String> _models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static Future<String?> transcribeAndSave({
    required String registroId,
    required String rutaAudio,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final file = File(rutaAudio);
      if (!await file.exists()) {
        debugPrint('TranscriptionService: archivo no existe $rutaAudio');
        return null;
      }
      final size = await file.length();
      if (size <= 0) {
        debugPrint('TranscriptionService: archivo vacío');
        return null;
      }

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = rutaAudio.toLowerCase().endsWith('.m4a')
          ? 'audio/mp4'
          : 'audio/aac';

      String? text;
      for (final model in _models) {
        text = await _callGemini(model: model, audioBase64: b64, mimeType: mime);
        if (text != null && text.isNotEmpty) break;
      }

      if (text == null || text.isEmpty) return null;

      try {
        await DataService.updateRegistroLlamadaTranscripcion(registroId, text);
      } catch (e) {
        debugPrint('TranscriptionService: error guardando transcripción: $e');
      }
      return text;
    } catch (e) {
      debugPrint('TranscriptionService error: $e');
      return null;
    }
  }

  static Future<String?> _callGemini({
    required String model,
    required String audioBase64,
    required String mimeType,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

    final body = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': audioBase64,
              },
            },
            {
              'text':
                  'Transcribe esta grabación de llamada telefónica a texto. '
                  'Incluye todo lo que se dice, tanto del usuario como de la otra persona. '
                  'Si no se entiende algo, pon [inaudible]. '
                  'Devuelve solo la transcripción, sin explicaciones adicionales.',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 4096,
      },
    };

    try {
      final r = await http
          .post(
            Uri.parse(url),
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 60));

      if (r.statusCode != 200) {
        debugPrint('Gemini $model error ${r.statusCode}: ${r.body.length > 200 ? r.body.substring(0, 200) : r.body}');
        return null;
      }

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      if (content == null) return null;

      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts[0]['text'] as String?;
      return (text != null && text.trim().isNotEmpty) ? text.trim() : null;
    } catch (e) {
      debugPrint('Gemini $model exception: $e');
      return null;
    }
  }
}
