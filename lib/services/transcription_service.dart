import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'data_service.dart';

class TranscriptionService {
  // Modelos Gemini válidos (v1 API)
  static const List<String> _models = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
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
      final supportDir = await getApplicationSupportDirectory();
      // Ruta real del nativo: filesDir/call_recordings = supportDir/call_recordings
      searchDirs.add('${supportDir.path}/call_recordings');
      searchDirs.add('${appDir.path}/call_recordings');
      searchDirs.add('${appDir.parent.path}/call_recordings');
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
      for (final ext in ['.mp4', '.amr', '.m4a', '.wav', '.aac']) {
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

  // Archivos > 10 MB van por File API para evitar timeout con inline base64
  static const int _fileApiThreshold = 10 * 1024 * 1024;

  static Future<String?> transcribeAndSave({
    required String registroId,
    required String rutaAudio,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final resolvedPath = await _resolveAudioPath(rutaAudio);
      if (resolvedPath == null) {
        debugPrint('TranscriptionService: no encontrado: $rutaAudio');
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
        'wav'  => 'audio/wav',
        'mp3'  => 'audio/mpeg',
        'aac'  => 'audio/aac',
        'ogg'  => 'audio/ogg',
        'flac' => 'audio/flac',
        'amr'  => 'audio/amr',
        _      => 'audio/mp4',
      };

      debugPrint('TranscriptionService: ${(size / 1024).toStringAsFixed(0)} KB, mime=$mime');

      final bytes = await file.readAsBytes();
      String? text;
      Exception? lastEx;
      final key = ApiConfig.geminiApiKey;

      if (key.isNotEmpty) {
        if (size > _fileApiThreshold) {
          // Audio largo → File API (no hay límite de tamaño de payload)
          debugPrint('TranscriptionService: audio grande, usando File API');
          for (final model in _models) {
            try {
              text = await _callGeminiFileApi(
                apiKey: key, model: model,
                audioBytes: bytes, mimeType: mime,
                displayName: resolvedPath.split('/').last,
              );
              if (text != null && text.isNotEmpty) { lastEx = null; break; }
            } catch (e) {
              lastEx = e is Exception ? e : Exception(e.toString());
              debugPrint('File API $model error: $e');
            }
          }
        }
        // Audio corto o fallback tras fallo de File API → inline base64
        if (text == null || text.isEmpty) {
          final b64 = base64Encode(bytes);
          for (final model in _models) {
            try {
              text = await _callGemini(
                model: model, apiKey: key,
                audioBase64: b64, mimeType: mime,
              );
              if (text != null && text.isNotEmpty) { lastEx = null; break; }
            } catch (e) {
              lastEx = e is Exception ? e : Exception(e.toString());
            }
          }
        }
      }

      // Fallback: API remota del servidor
      if ((text == null || text.isEmpty) && ApiConfig.useRemoteApi) {
        try {
          final b64 = base64Encode(bytes);
          text = await ApiService.transcribeAudio(b64, mime);
          if (text != null && text.isNotEmpty) lastEx = null;
        } catch (e) {
          debugPrint('TranscriptionService API remota error: $e');
          lastEx = e is Exception ? e : Exception(e.toString());
        }
      }

      if (text == null || text.isEmpty) {
        debugPrint('TranscriptionService: falló. ${lastEx?.toString()}');
        return null;
      }

      try {
        await DataService.updateRegistroLlamadaTranscripcion(registroId, text);
      } catch (e) {
        debugPrint('TranscriptionService: error guardando: $e');
      }
      return text;
    } catch (e) {
      debugPrint('TranscriptionService error general: $e');
      rethrow;
    }
  }

  /// Sube el audio a la File API de Gemini y transcribe desde la URL del archivo.
  static Future<String?> _callGeminiFileApi({
    required String apiKey,
    required String model,
    required List<int> audioBytes,
    required String mimeType,
    required String displayName,
  }) async {
    // 1. Iniciar upload resumible
    final initRes = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/upload/v1beta/files?key=$apiKey',
      ),
      headers: {
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': '${audioBytes.length}',
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'file': {'displayName': displayName}}),
    ).timeout(const Duration(seconds: 30));

    final uploadUrl = initRes.headers['x-goog-upload-url'];
    if (uploadUrl == null) throw Exception('File API: sin upload URL');

    // 2. Subir bytes
    final uploadRes = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Length': '${audioBytes.length}',
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
        'Content-Type': mimeType,
      },
      body: audioBytes,
    ).timeout(const Duration(seconds: 180));

    if (uploadRes.statusCode != 200) {
      throw Exception('File API upload HTTP ${uploadRes.statusCode}');
    }

    final fileData = jsonDecode(uploadRes.body) as Map<String, dynamic>;
    final fileUri = fileData['file']?['uri'] as String?;
    if (fileUri == null) throw Exception('File API: sin fileUri');

    // 3. Esperar a que el archivo esté activo
    await Future.delayed(const Duration(seconds: 3));

    // 4. Generar contenido usando la URI del archivo
    final genUrl =
        'https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey';

    final genBody = {
      'contents': [
        {
          'parts': [
            {'file_data': {'mime_type': mimeType, 'file_uri': fileUri}},
            {
              'text': 'Transcribe esta grabación de llamada telefónica al español. '
                  'Incluye todo lo que dicen ambas personas. '
                  'Usa formato: "Persona 1: [texto]" y "Persona 2: [texto]" si puedes distinguir las voces. '
                  'Si no se entiende algo, escribe [inaudible]. '
                  'Devuelve únicamente la transcripción, sin explicaciones ni comentarios.',
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 8192},
    };

    final genRes = await http.post(
      Uri.parse(genUrl),
      body: jsonEncode(genBody),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 300));

    if (genRes.statusCode != 200) {
      final detail = genRes.body.length > 300 ? genRes.body.substring(0, 300) : genRes.body;
      throw Exception('File API generateContent $model HTTP ${genRes.statusCode}: $detail');
    }

    final genData = jsonDecode(genRes.body) as Map<String, dynamic>;
    final candidates = genData['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) throw Exception('File API: sin candidatos');

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) throw Exception('File API: partes vacías');

    final text = parts[0]['text'] as String?;
    return (text != null && text.trim().isNotEmpty) ? text.trim() : null;
  }

  static Future<String?> _callGemini({
    required String model,
    required String apiKey,
    required String audioBase64,
    required String mimeType,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey';

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
          .timeout(const Duration(seconds: 240));

      if (r.statusCode != 200) {
        final detail = r.body.length > 300 ? r.body.substring(0, 300) : r.body;
        debugPrint('Gemini $model HTTP ${r.statusCode}: $detail');
        throw Exception('Error $model: $detail');
      }

      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini $model: sin candidatos en respuesta');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      if (content == null) throw Exception('Gemini $model: sin contenido de transcripción');

      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) throw Exception('Gemini $model: respuesta vacía');

      final text = parts[0]['text'] as String?;
      return (text != null && text.trim().isNotEmpty) ? text.trim() : null;
    } catch (e) {
      debugPrint('Gemini $model exception: $e');
      rethrow;
    }
  }
}
