import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'data_service.dart';

class TranscriptionService {
  // Modelos para Gemini directo (fallback cuando la API remota no está disponible)
  static const List<String> _models = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-exp',
    'gemini-1.5-flash-8b',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  /// Resuelve la ruta real del archivo de audio, buscando en múltiples ubicaciones
  static Future<String?> _resolveAudioPath(String originalPath) async {
    // 1. Ruta original exacta
    final originalFile = File(originalPath);
    if (await originalFile.exists()) {
      final size = await originalFile.length();
      if (size > 0) return originalPath;
    }

    // 2. Extraer nombre del archivo
    final fileName = originalPath.split('/').last.split('\\').last;
    if (fileName.isEmpty) return null;

    final searchDirs = <String>[];
    try {
      final appDir = await getApplicationDocumentsDirectory();
      searchDirs.add('${appDir.path}/call_recordings');
      searchDirs.add('${appDir.parent.path}/app_flutter/call_recordings');
      searchDirs.add('${appDir.parent.path}/files/call_recordings');
      searchDirs.add(appDir.path);
    } catch (_) {}

    for (final dir in searchDirs) {
      // Buscar con el nombre exacto
      final candidate = '$dir/$fileName';
      final f = File(candidate);
      if (await f.exists() && await f.length() > 0) {
        debugPrint('TranscriptionService: ruta resuelta → $candidate');
        return candidate;
      }
      // Buscar con extensiones alternativas
      final baseName = fileName.replaceAll(RegExp(r'\.(m4a|wav|aac|amr|mp4)$'), '');
      for (final ext in ['.amr', '.m4a', '.wav', '.aac']) {
        final alt = '$dir/$baseName$ext';
        final af = File(alt);
        if (await af.exists() && await af.length() > 0) {
          debugPrint('TranscriptionService: extensión alternativa → $alt');
          return alt;
        }
      }
    }
    debugPrint('TranscriptionService: no encontrado: $originalPath');
    return null;
  }

  static Future<String?> transcribeAndSave({
    required String registroId,
    required String rutaAudio,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      // Resolver la ruta real del archivo (puede estar en otra ubicación)
      final resolvedPath = await _resolveAudioPath(rutaAudio);
      if (resolvedPath == null) {
        debugPrint('TranscriptionService: no se encontró el archivo de audio: $rutaAudio');
        return null;
      }

      final file = File(resolvedPath);
      final size = await file.length();
      if (size <= 0) {
        debugPrint('TranscriptionService: archivo vacío');
        return null;
      }

      final ext = resolvedPath.toLowerCase().split('.').last;
      final mime = switch (ext) {
        'wav' => 'audio/wav',
        'mp3' => 'audio/mpeg',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac',
        'amr' => 'audio/amr',
        _ => 'audio/mp4',
      };

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      debugPrint('TranscriptionService: transcribiendo ${(size / 1024).toStringAsFixed(0)} KB, mime=$mime');

      String? text;

      // 1. Usar API remota si está configurada (la clave Gemini va en el servidor)
      if (ApiConfig.useRemoteApi) {
        text = await ApiService.transcribeAudio(b64, mime);
        if (text != null && text.isNotEmpty) {
          debugPrint('TranscriptionService: éxito vía API remota (${text.length} chars)');
        }
      }

      // 2. Fallback: Gemini directo si hay clave configurada
      if ((text == null || text.isEmpty) && ApiConfig.geminiApiKey.isNotEmpty) {
        debugPrint('TranscriptionService: intentando Gemini directo con key=${ApiConfig.geminiApiKey.substring(0, 8)}...');
        for (final model in _models) {
          text = await _callGemini(
            model: model,
            apiKey: ApiConfig.geminiApiKey,
            audioBase64: b64,
            mimeType: mime,
          );
          if (text != null && text.isNotEmpty) {
            debugPrint('TranscriptionService: éxito con $model (${text.length} chars)');
            break;
          }
        }
      }

      if (text == null || text.isEmpty) {
        debugPrint('TranscriptionService: no se pudo transcribir.');
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
    required String apiKey,
    required String audioBase64,
    required String mimeType,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

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
