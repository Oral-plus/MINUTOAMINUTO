import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Servicio de diagnóstico post-llamada.
/// Guarda los detalles del último guardado y permite mostrarlos
/// como un panel flotante en la UI.
class CallDiagnosticService {
  static const _keyLastDiag = 'call_diagnostic_last';
  static _DiagData? _lastDiag;

  /// Registrar resultado de guardado (llamar desde call_monitor_service)
  static Future<void> record({
    required String registroId,
    required String nombreContactado,
    required int duracionMinutos,
    required bool guardadoEnApi,
    required bool merged,
    String? audioPath,
    String? errorMsg,
  }) async {
    final data = _DiagData(
      registroId: registroId,
      nombreContactado: nombreContactado,
      duracionMinutos: duracionMinutos,
      guardadoEnApi: guardadoEnApi,
      merged: merged,
      audioPath: audioPath,
      errorMsg: errorMsg,
      timestamp: DateTime.now(),
    );
    _lastDiag = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastDiag, jsonEncode(data.toMap()));
    } catch (_) {}
  }

  static _DiagData? get lastDiag => _lastDiag;

  static Future<_DiagData?> loadLastDiag() async {
    if (_lastDiag != null) return _lastDiag;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLastDiag);
      if (raw == null) return null;
      _lastDiag = _DiagData.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      return _lastDiag;
    } catch (_) {
      return null;
    }
  }

  /// Muestra el panel diagnóstico como un bottom sheet premium
  static Future<void> showPanel(BuildContext context) async {
    final data = await loadLastDiag();
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros de llamadas recientes.')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DiagPanel(data: data),
    );
  }
}

class _DiagData {
  final String registroId;
  final String nombreContactado;
  final int duracionMinutos;
  final bool guardadoEnApi;
  final bool merged;
  final String? audioPath;
  final String? errorMsg;
  final DateTime timestamp;

  const _DiagData({
    required this.registroId,
    required this.nombreContactado,
    required this.duracionMinutos,
    required this.guardadoEnApi,
    required this.merged,
    required this.timestamp,
    this.audioPath,
    this.errorMsg,
  });

  Map<String, dynamic> toMap() => {
    'registroId': registroId,
    'nombreContactado': nombreContactado,
    'duracionMinutos': duracionMinutos,
    'guardadoEnApi': guardadoEnApi,
    'merged': merged,
    'audioPath': audioPath,
    'errorMsg': errorMsg,
    'timestamp': timestamp.toIso8601String(),
  };

  factory _DiagData.fromMap(Map<String, dynamic> m) => _DiagData(
    registroId: m['registroId'] as String? ?? '',
    nombreContactado: m['nombreContactado'] as String? ?? '',
    duracionMinutos: m['duracionMinutos'] as int? ?? 0,
    guardadoEnApi: m['guardadoEnApi'] as bool? ?? false,
    merged: m['merged'] as bool? ?? false,
    audioPath: m['audioPath'] as String?,
    errorMsg: m['errorMsg'] as String?,
    timestamp: DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

class _DiagPanel extends StatelessWidget {
  final _DiagData data;
  const _DiagPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final apiOk = data.guardadoEnApi;
    final hasAudio = data.audioPath != null && data.audioPath!.isNotEmpty;
    final hasError = data.errorMsg != null && data.errorMsg!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: apiOk ? const Color(0xFF4ADE80).withOpacity(0.1) : const Color(0xFFEF5350).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: apiOk ? const Color(0xFF4ADE80).withOpacity(0.2) : const Color(0xFFEF5350).withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        apiOk ? Icons.cloud_done_rounded : Icons.storage_rounded,
                        color: apiOk ? const Color(0xFF4ADE80) : const Color(0xFFEF9A9A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnóstico de llamada',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          Text(
                            '${data.timestamp.hour.toString().padLeft(2,'0')}:${data.timestamp.minute.toString().padLeft(2,'0')} · ${data.timestamp.day}/${data.timestamp.month}/${data.timestamp.year}',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Donde se guardó
                _DiagRow(
                  icon: apiOk ? Icons.cloud_done_outlined : Icons.phone_android_rounded,
                  label: 'Guardado en',
                  value: apiOk
                      ? (data.merged ? 'Servidor (correlación dual)' : 'Servidor (SQL Server)')
                      : 'Local SQLite (sin conexión)',
                  valueColor: apiOk ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                ),
                const SizedBox(height: 12),

                _DiagRow(
                  icon: Icons.person_outline,
                  label: 'Contacto',
                  value: data.nombreContactado,
                ),
                const SizedBox(height: 12),

                _DiagRow(
                  icon: Icons.timer_outlined,
                  label: 'Duración',
                  value: '${data.duracionMinutos} min',
                ),
                const SizedBox(height: 12),

                _DiagRow(
                  icon: Icons.tag_rounded,
                  label: 'ID Registro',
                  value: data.registroId,
                  small: true,
                ),

                if (hasAudio) ...[
                  const SizedBox(height: 12),
                  _DiagRow(
                    icon: Icons.mic_rounded,
                    label: 'Audio guardado en',
                    value: data.audioPath!,
                    small: true,
                    valueColor: const Color(0xFF4ADE80),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  _DiagRow(
                    icon: Icons.mic_off_rounded,
                    label: 'Audio',
                    value: 'Sin grabación de audio',
                    valueColor: Colors.white38,
                  ),
                ],

                if (hasError) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF9A9A), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.errorMsg!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFEF9A9A), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool small;

  const _DiagRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: small ? 11 : 13,
                  color: valueColor ?? Colors.white.withOpacity(0.75),
                  fontFamily: small ? 'monospace' : null,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
