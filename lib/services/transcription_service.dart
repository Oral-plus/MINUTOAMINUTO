import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'data_service.dart';

class TranscriptionService {
  static const String _apiKey = 'AIzaSyAtI2xz5kiSnxUn6vejkAeUnN2hAxOlxZ8';

  // Modelos en orden de preferencia (los más capaces primero)
  static const List<String> _models = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
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

      // Determinar MIME type correcto según extensión
      final ext = rutaAudio.toLowerCase().split('.').last;
      final mime = switch (ext) {
        'wav' => 'audio/wav',
        'mp3' => 'audio/mpeg',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac',
        _ => 'audio/mp4', // m4a y otros
      };

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      debugPrint('TranscriptionService: transcribiendo ${(size / 1024).toStringAsFixed(0)} KB, mime=$mime');

      String? text;
      for (final model in _models) {
        text = await _callGemini(model: model, audioBase64: b64, mimeType: mime);
        if (text != null && text.isNotEmpty) {
          debugPrint('TranscriptionService: éxito con modelo $model (${text.length} chars)');
          break;
        }
      }

      if (text == null || text.isEmpty) {
        debugPrint('TranscriptionService: todos los modelos fallaron');
        return null;
      }

      try {
        await DataService.updateRegistroLlamadaTranscripcion(registroId, text);
        debugPrint('TranscriptionService: transcripción guardada en registro $registroId');
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
                  'Transcribe esta grabación de llamada telefónica al español. '
                  'Incluye todo lo que dicen ambas personas. '
                  'Usa formato: "Persona 1: [texto]" y "Persona 2: [texto]" si puedes distinguir las voces. '
                  'Si no se entiende algo, escribe [inaudible]. '
                  'Devuelve únicamente la transcripción, sin explicaciones ni comentarios.',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.0,
        'maxOutputTokens': 8192,
      },
    };

    try {
      final r = await http
          .post(
            Uri.parse(url),
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 120));

      if (r.statusCode != 200) {
        debugPrint(
          'Gemini $model HTTP ${r.statusCode}: '
          '${r.body.length > 300 ? r.body.substring(0, 300) : r.body}',
        );
        return null;
      }

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('Gemini $model: sin candidatos en respuesta');
        return null;
      }

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
