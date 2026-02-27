import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../services/data_service.dart';
import '../services/post_call_notification_service.dart';
import '../services/transcription_service.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../widgets/map_location_modal.dart';

class MisLlamadasScreen extends StatefulWidget {
  const MisLlamadasScreen({super.key});

  @override
  State<MisLlamadasScreen> createState() => _MisLlamadasScreenState();
}

class _MisLlamadasScreenState extends State<MisLlamadasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _verificarEdicionPendiente();
      if (mounted) {
        await context.read<AppProvider>().cargarDatosHoy();
      }
    });
  }

  Future<void> _verificarEdicionPendiente() async {
    final id = await PostCallNotificationService.getPendingEditRegistroId();
    if (id == null || !mounted) return;
    final r = await DataService.getRegistroLlamada(id);
    if (r != null && mounted) _mostrarDialogoEditarObservaciones(context, r);
  }

  static Future<void> _mostrarDialogoEditarObservaciones(
    BuildContext context,
    RegistroLlamada r,
  ) async {
    final controller = TextEditingController(text: r.observaciones);
    final provider = context.read<AppProvider>();
    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar observaciones - ${r.nombreContactado}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Observaciones sobre la llamada...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.verdeMeta,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardado == true && controller.text != r.observaciones) {
      await DataService.updateRegistroLlamadaObservaciones(
        r.id,
        controller.text,
      );
      if (context.mounted) {
        provider.cargarDatosHoy();
        AppFeedback.success(context, 'Observaciones actualizadas');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Llamadas Hoy'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final nombreUsuario = provider.usuarioActual?.nombre ??
              provider.vendedorActual?.nombre;
          List<RegistroLlamada> llamadas = provider.llamadas;
          if (nombreUsuario != null) {
            llamadas = llamadas
                .where((l) => l.nombreLider == nombreUsuario)
                .toList();
          }

          llamadas.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
          final totalMinutos = llamadas.fold<int>(
            0,
            (acc, l) => acc + l.duracionMinutos,
          );
          final llamadasConAudio =
              llamadas.where((l) => _isConAudio(l)).length;
          final llamadasConTranscripcion =
              llamadas.where((l) => _isConTranscripcion(l)).length;

          return RefreshIndicator(
            onRefresh: () => provider.cargarDatosHoy(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              itemCount: llamadas.isEmpty ? 2 : llamadas.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _ResumenLlamadasCard(
                    totalLlamadas: llamadas.length,
                    totalMinutos: totalMinutos,
                    conAudio: llamadasConAudio,
                    conTranscripcion: llamadasConTranscripcion,
                  );
                }

                if (llamadas.isEmpty) {
                  return const _EstadoVacioLlamadasCard();
                }

                final l = llamadas[i - 1];
                final tipoColor = _colorTipo(l.tipoLlamada);
                final tieneAudio = _isConAudio(l);
                final tieneTranscripcion = _isConTranscripcion(l);
                final contacto = provider.usuarioActual != null
                    ? 'A: ${l.nombreContactado}'
                    : 'De: ${l.nombreLider}';

                return _LlamadaCard(
                  llamada: l,
                  contacto: contacto,
                  tipoColor: tipoColor,
                  tieneAudio: tieneAudio,
                  tieneTranscripcion: tieneTranscripcion,
                  esUsuarioActual: provider.usuarioActual != null,
                  onEditarObservaciones: () =>
                      _mostrarDialogoEditarObservaciones(context, l),
                  onTranscripcionGuardada: () => provider.cargarDatosHoy(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static bool _isConAudio(RegistroLlamada l) {
    final ruta = l.rutaGrabacion;
    return ruta != null && ruta.trim().isNotEmpty;
  }

  static bool _isConTranscripcion(RegistroLlamada l) {
    final texto = l.transcripcionTexto;
    return texto != null && texto.trim().isNotEmpty;
  }

  static Color _colorTipo(dynamic tipo) {
    switch (tipo.toString()) {
      case 'TipoLlamada.manana':
        return Colors.orange;
      case 'TipoLlamada.tarde':
        return Colors.blue;
      case 'TipoLlamada.kam':
        return Colors.purple;
      case 'TipoLlamada.jefe':
        return Colors.teal;
      default:
        return AppConstants.azulCorporativo;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card expandible de llamada
// ─────────────────────────────────────────────────────────────────────────────

class _LlamadaCard extends StatefulWidget {
  final RegistroLlamada llamada;
  final String contacto;
  final Color tipoColor;
  final bool tieneAudio;
  final bool tieneTranscripcion;
  final bool esUsuarioActual;
  final VoidCallback onEditarObservaciones;
  final VoidCallback onTranscripcionGuardada;

  const _LlamadaCard({
    required this.llamada,
    required this.contacto,
    required this.tipoColor,
    required this.tieneAudio,
    required this.tieneTranscripcion,
    required this.esUsuarioActual,
    required this.onEditarObservaciones,
    required this.onTranscripcionGuardada,
  });

  @override
  State<_LlamadaCard> createState() => _LlamadaCardState();
}

class _LlamadaCardState extends State<_LlamadaCard> {
  bool _expandido = false;

  static ({double lat, double lng})? _parseCoords(RegistroLlamada l) {
    // Primero usar campos directos (más precisos)
    if (l.latitud != null && l.longitud != null &&
        !(l.latitud == 0 && l.longitud == 0)) {
      return (lat: l.latitud!, lng: l.longitud!);
    }
    // Fallback: parsear desde observaciones (llamadas antiguas)
    final m = RegExp(
      r'[Uu]bicaci[oó]n:\s*([-\d.]+)\s*,\s*([-\d.]+)',
      caseSensitive: false,
    ).firstMatch(l.observaciones);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1) ?? '');
    final lng = double.tryParse(m.group(2) ?? '');
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return (lat: lat, lng: lng);
  }

  Widget _chip(IconData icon, String text, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.llamada;
    final coords = _parseCoords(l);
    final horaStr =
        '${DateFormat('HH:mm').format(l.horaInicio)} – ${DateFormat('HH:mm').format(l.horaFin)}';

    return GestureDetector(
      onTap: () => setState(() => _expandido = !_expandido),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expandido
                ? AppConstants.azulCorporativo.withOpacity(0.4)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_expandido ? 0.06 : 0.03),
              blurRadius: _expandido ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera siempre visible ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.tipoColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_in_talk_rounded,
                        color: widget.tipoColor, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.contacto,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 3),
                        Text(horaStr,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  // Duración
                  _chip(Icons.schedule_rounded, '${l.duracionMinutos} min',
                      const Color(0xFF374151),
                      bg: const Color(0xFFF3F4F6)),
                  const SizedBox(width: 8),
                  // Flecha expandir
                  AnimatedRotation(
                    turns: _expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF9CA3AF), size: 22),
                  ),
                ],
              ),
            ),

            // ── Chips de estado ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(spacing: 7, runSpacing: 7, children: [
                _chip(Icons.label_rounded, l.tipoLlamada.displayName,
                    widget.tipoColor),
                if (widget.tieneAudio)
                  _chip(Icons.mic_rounded, 'Audio guardado',
                      AppConstants.verdeMeta),
                if (widget.tieneTranscripcion)
                  _chip(Icons.auto_awesome_rounded, 'Transcripción',
                      const Color(0xFF7C3AED)),
                if (coords != null)
                  GestureDetector(
                    onTap: () => MapLocationModal.show(
                      context,
                      latitude: coords.lat,
                      longitude: coords.lng,
                      contactName: l.nombreContactado,
                    ),
                    child: _chip(Icons.location_on_rounded, 'Ver en mapa',
                        AppConstants.azulCorporativo,
                        bg: AppConstants.azulCorporativo.withOpacity(0.12)),
                  ),
              ]),
            ),

            // ── Contenido expandido ───────────────────────────────────────
            if (_expandido) ...[
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Venta / Recaudo
                    if (l.ventaDia > 0 || l.recaudoDia > 0) ...[
                      Row(children: [
                        if (l.ventaDia > 0)
                          _InfoPill(
                              icon: Icons.trending_up_rounded,
                              label: 'Venta',
                              value:
                                  '\$${NumberFormat('#,##0').format(l.ventaDia)}',
                              color: AppConstants.verdeMeta),
                        if (l.ventaDia > 0 && l.recaudoDia > 0)
                          const SizedBox(width: 8),
                        if (l.recaudoDia > 0)
                          _InfoPill(
                              icon: Icons.payments_rounded,
                              label: 'Recaudo',
                              value:
                                  '\$${NumberFormat('#,##0').format(l.recaudoDia)}',
                              color: AppConstants.azulCorporativo),
                      ]),
                      const SizedBox(height: 12),
                    ],

                    // Observaciones limpias (sin la metadata técnica)
                    if (l.observaciones.isNotEmpty) ...[
                      _SectionLabel(
                          icon: Icons.notes_rounded, label: 'Observaciones'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          _limpiarObservaciones(l.observaciones),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Color(0xFF374151)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Mapa de ubicación (siempre visible si hay coords)
                    if (coords != null) ...[
                      _SectionLabel(
                          icon: Icons.location_on_rounded,
                          label: 'Ubicación de la llamada'),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          child: GestureDetector(
                            onTap: () => MapLocationModal.show(
                              context,
                              latitude: coords.lat,
                              longitude: coords.lng,
                              contactName: l.nombreContactado,
                            ),
                            child: Stack(children: [
                              MapLocationModal.miniMap(
                                latitude: coords.lat,
                                longitude: coords.lng,
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppConstants.azulCorporativo,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.open_in_full_rounded,
                                          size: 13, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Ver mapa',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Audio
                    if (widget.tieneAudio) ...[
                      _SectionLabel(
                          icon: Icons.mic_rounded,
                          label: 'Grabación de llamada'),
                      const SizedBox(height: 6),
                      _AudioPlayerWidget(
                        url: l.rutaGrabacion!,
                        registroId: l.id,
                        transcripcion: l.transcripcionTexto,
                        onTranscripcionGuardada: widget.onTranscripcionGuardada,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Transcripción
                    if (widget.tieneTranscripcion) ...[
                      _SectionLabel(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Transcripción IA'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.2)),
                        ),
                        child: Text(
                          l.transcripcionTexto!,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: Color(0xFF374151)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Acciones
                    Row(children: [
                      if (widget.esUsuarioActual)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onEditarObservaciones,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Editar'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Elimina la metadata técnica de las observaciones para mostrar solo
  /// lo que el usuario escribió o la info relevante.
  static String _limpiarObservaciones(String obs) {
    // Quitar líneas de metadata técnica
    final lines = obs.split('. ').where((s) {
      final lower = s.toLowerCase();
      return !lower.startsWith('ip:') &&
          !lower.startsWith('ubicación:') &&
          !lower.startsWith('audio:');
    }).toList();
    return lines.join('. ').trim();
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoPill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF6B7280)),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280))),
    ]);
  }
}

class _ResumenLlamadasCard extends StatelessWidget {
  final int totalLlamadas;
  final int totalMinutos;
  final int conAudio;
  final int conTranscripcion;

  const _ResumenLlamadasCard({
    required this.totalLlamadas,
    required this.totalMinutos,
    required this.conAudio,
    required this.conTranscripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C95), AppConstants.azulCorporativo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppConstants.azulCorporativo.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del día',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalLlamadas llamadas registradas',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ResumenMetrica(
                  icono: Icons.schedule_rounded,
                  valor: '$totalMinutos min',
                  etiqueta: 'Duración total',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResumenMetrica(
                  icono: Icons.mic_rounded,
                  valor: '$conAudio',
                  etiqueta: 'Con audio',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResumenMetrica(
                  icono: Icons.auto_awesome_rounded,
                  valor: '$conTranscripcion',
                  etiqueta: 'Con IA',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumenMetrica extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _ResumenMetrica({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacioLlamadasCard extends StatelessWidget {
  const _EstadoVacioLlamadasCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.phone_in_talk_outlined,
              color: Color(0xFF9CA3AF),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin llamadas hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Las llamadas que registres durante el día aparecerán en este módulo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final String registroId;
  final String? transcripcion;
  final VoidCallback? onTranscripcionGuardada;

  const _AudioPlayerWidget({
    required this.url,
    required this.registroId,
    this.transcripcion,
    this.onTranscripcionGuardada,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _transcribiendo = false;
  bool _cargandoAudio = false;
  String? _transcripcionLocal;
  Duration _duracionTotal = Duration.zero;
  Duration _posicionActual = Duration.zero;

  /// Busca el archivo de audio en múltiples rutas posibles.
  static Future<String?> _resolveAudioPath(String originalPath) async {
    // 1. Ruta original exacta
    if (await File(originalPath).exists()) {
      final size = await File(originalPath).length();
      if (size > 0) return originalPath;
    }

    // 2. Extraer nombre del archivo
    final fileName = originalPath.split('/').last.split('\\').last;
    if (fileName.isEmpty) return null;

    final searchDirs = <String>[];
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // Ruta exacta que usa el nativo: <data>/app_flutter/call_recordings
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
        debugPrint('AudioPlayer: ruta resuelta → $candidate');
        return candidate;
      }
      // Buscar con extensiones alternativas
      final baseName = fileName.replaceAll(RegExp(r'\.(m4a|wav|aac|mp4)$'), '');
      for (final ext in ['.m4a', '.wav', '.aac']) {
        final alt = '$dir/$baseName$ext';
        final af = File(alt);
        if (await af.exists() && await af.length() > 0) {
          debugPrint('AudioPlayer: extensión alternativa → $alt');
          return alt;
        }
      }
    }
    debugPrint('AudioPlayer: no encontrado: $originalPath');
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            audioMode: AndroidAudioMode.normal,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      ),
    );
    unawaited(_player.setPlayerMode(PlayerMode.mediaPlayer));
    unawaited(_player.setVolume(1.0));
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duracionTotal = duration);
    });
    _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _posicionActual = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _posicionActual = _duracionTotal;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_cargandoAudio) return;
    try {
      if (_playing) {
        await _player.pause();
        return;
      }

      if (_posicionActual > Duration.zero &&
          _duracionTotal > Duration.zero &&
          _posicionActual < _duracionTotal) {
        await _player.resume();
        return;
      }

      setState(() => _cargandoAudio = true);

      final isUrl = widget.url.startsWith('http://') ||
          widget.url.startsWith('https://');

      if (isUrl) {
        await _player.play(
          UrlSource(widget.url),
          volume: 1.0,
          mode: PlayerMode.mediaPlayer,
        );
      } else {
        // Resolver la ruta real del archivo (puede haber cambiado entre versiones)
        final resolvedPath = await _resolveAudioPath(widget.url);
        if (resolvedPath == null) {
          if (mounted) {
            AppFeedback.error(
              context,
              'Grabación no disponible en este dispositivo',
            );
          }
          return;
        }
        final size = await File(resolvedPath).length();
        if (size <= 0) {
          if (mounted) {
            AppFeedback.error(context, 'El archivo de audio está vacío');
          }
          return;
        }
        await _player.play(
          DeviceFileSource(resolvedPath),
          volume: 1.0,
          mode: PlayerMode.mediaPlayer,
        );
      }
    } catch (e) {
      debugPrint('AudioPlayer error: $e — url: ${widget.url}');
      if (mounted) {
        AppFeedback.error(context, 'No se pudo reproducir el audio');
      }
    } finally {
      if (mounted) setState(() => _cargandoAudio = false);
    }
  }

  Future<void> _seek(double ms) async {
    if (_duracionTotal == Duration.zero) return;
    final maxMs = _duracionTotal.inMilliseconds;
    final clamped = ms.clamp(0, maxMs.toDouble()).round();
    await _player.seek(Duration(milliseconds: clamped));
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _transcribirConIA() async {
    if (_transcribiendo) return;
    setState(() => _transcribiendo = true);
    try {
      final text = await TranscriptionService.transcribeAndSave(
        registroId: widget.registroId,
        rutaAudio: widget.url,
      );
      if (mounted) {
        setState(() {
          _transcribiendo = false;
          if (text != null) _transcripcionLocal = text;
        });
        widget.onTranscripcionGuardada?.call();
        if (text != null && mounted) {
          AppFeedback.success(context, 'Transcripción guardada');
        } else if (mounted) {
          AppFeedback.warning(context, 'No se pudo transcribir. Verifique la conexión con la API.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _transcribiendo = false);
        AppFeedback.error(context, 'Error en transcripción: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneTranscripcion =
        (_transcripcionLocal != null && _transcripcionLocal!.isNotEmpty) ||
            (widget.transcripcion != null && widget.transcripcion!.isNotEmpty);
    final maxMs = _duracionTotal.inMilliseconds <= 0
        ? 1
        : _duracionTotal.inMilliseconds;
    final valueMs = _posicionActual.inMilliseconds.clamp(0, maxMs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: _togglePlay,
                icon: _cargandoAudio
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                style: IconButton.styleFrom(
                  backgroundColor: AppConstants.azulCorporativo,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grabación de llamada',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _playing
                          ? 'Reproduciendo audio...'
                          : 'Toca para reproducir',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (!tieneTranscripcion)
                OutlinedButton.icon(
                  onPressed: _transcribiendo ? null : _transcribirConIA,
                  icon: _transcribiendo
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    _transcribiendo ? 'Transcribiendo...' : 'Transcribir',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.azulCorporativo,
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppConstants.azulCorporativo,
              inactiveTrackColor: const Color(0xFFE5E7EB),
              thumbColor: AppConstants.azulCorporativo,
              trackHeight: 3,
            ),
            child: Slider(
              value: valueMs.toDouble(),
              min: 0,
              max: maxMs.toDouble(),
              onChanged: _duracionTotal == Duration.zero ? null : _seek,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_posicionActual),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                Text(
                  _formatDuration(_duracionTotal),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
