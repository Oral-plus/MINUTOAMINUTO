import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../services/data_service.dart';
import '../services/post_call_notification_service.dart';
import '../services/transcription_service.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../widgets/map_location_modal.dart';
import '../widgets/active_call_indicator.dart';

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
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Editar observaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Escriba aquí...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white30)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w900)),
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
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('REGISTRO DE HOY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
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
            backgroundColor: const Color(0xFF1A1A1A),
            color: Colors.white,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: llamadas.isEmpty ? 2 : llamadas.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    children: [
                      const ActiveCallIndicator(),
                      _ResumenLlamadasCard(
                        totalLlamadas: llamadas.length,
                        totalMinutos: totalMinutos,
                        conAudio: llamadasConAudio,
                        conTranscripcion: llamadasConTranscripcion,
                      ),
                    ],
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
                    ? '${l.nombreContactado}'
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
        return Colors.black54;
      case 'TipoLlamada.tarde':
        return Colors.black87;
      case 'TipoLlamada.kam':
        return Colors.black54;
      case 'TipoLlamada.jefe':
        return Colors.black87;
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }

  Widget _chip(IconData icon, String text, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.llamada;
    final coords = _parseCoords(l);
    final horaStr =
        '${DateFormat('HH:mm').format(l.horaInicio)} – ${DateFormat('HH:mm').format(l.horaFin)}';
    final agoStr = _timeAgo(l.horaFin);
    final durStr = l.duracionMinutos > 0 ? '${l.duracionMinutos} min' : '< 1 min';

    return GestureDetector(
      onTap: () => setState(() => _expandido = !_expandido),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _expandido
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_expandido ? 0.3 : 0.1),
              blurRadius: _expandido ? 20 : 10,
              offset: Offset(0, _expandido ? 10 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera siempre visible ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Icon(Icons.phone_in_talk_rounded,
                        color: Colors.white70, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.contacto,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Text('$horaStr  ·  $agoStr',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  _chip(Icons.schedule_rounded, durStr,
                      Colors.white38,
                      bg: Colors.white.withOpacity(0.04)),
                  const SizedBox(width: 10),
                  // Flecha expandir
                  AnimatedRotation(
                    turns: _expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.2), size: 22),
                  ),
                ],
              ),
            ),

            // ── Chips de estado ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(spacing: 7, runSpacing: 7, children: [
                _chip(Icons.label_rounded, l.tipoLlamada.displayName,
                    Colors.white54),
                if (l.rutaGrabacionPuntoB != null &&
                    l.rutaGrabacionPuntoB!.isNotEmpty)
                  _chip(Icons.call_merge_rounded, 'Cruce A+B',
                      const Color(0xFF60A5FA)),
                if (widget.tieneAudio)
                  _chip(Icons.mic_rounded, 'Audio guardado',
                      const Color(0xFF4ADE80)),
                if (widget.tieneTranscripcion)
                  _chip(Icons.auto_awesome_rounded, 'Transcripción',
                      const Color(0xFFFBBF24)),
                if (coords != null)
                  GestureDetector(
                    onTap: () => MapLocationModal.show(
                      context,
                      latitude: coords.lat,
                      longitude: coords.lng,
                      contactName: l.nombreContactado,
                    ),
                    child: _chip(Icons.location_on_rounded, 'Ver en mapa',
                        const Color(0xFF60A5FA),
                        bg: const Color(0xFF60A5FA).withOpacity(0.12)),
                  ),
              ]),
            ),

            // ── Contenido expandido ───────────────────────────────────────
            if (_expandido) ...[
              Divider(height: 1, color: Colors.white.withOpacity(0.06)),
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
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          _limpiarObservaciones(l.observaciones),
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: Colors.white.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                          height: MediaQuery.of(context).size.shortestSide * 0.42,
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

                    // Transcripción (Eliminado de aquí, ahora está integrado en el AudioPlayer)


                    // Acciones
                    Row(children: [
                      if (widget.esUsuarioActual)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onEditarObservaciones,
                            icon: Icon(Icons.edit_outlined, size: 16, color: Colors.white.withOpacity(0.5)),
                            label: Text('Editar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      Icon(icon, size: 15, color: Colors.white.withOpacity(0.35)),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.35),
              letterSpacing: 1.5)),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN DEL DÍA',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$totalLlamadas registradas',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ResumenMetrica(
                  icono: Icons.schedule_rounded,
                  valor: '$totalMinutos',
                  etiqueta: 'MINUTOS',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResumenMetrica(
                  icono: Icons.mic_rounded,
                  valor: '$conAudio',
                  etiqueta: 'AUDIOS',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResumenMetrica(
                  icono: Icons.auto_awesome_rounded,
                  valor: '$conTranscripcion',
                  etiqueta: 'IA',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 14, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(
              Icons.phone_in_talk_outlined,
              color: Colors.white.withOpacity(0.2),
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Sin llamadas hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las llamadas que registres durante el día\naparecerán en este módulo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3), height: 1.5),
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
  AudioPlayer? _player;
  bool _playing = false;
  bool _transcribiendo = false;
  bool _cargandoAudio = false;
  String? _transcripcionLocal;
  Duration _duracionTotal = Duration.zero;
  Duration _posicionActual = Duration.zero;

  void _initPlayerIfNeeded() {
    if (_player != null) return;
    _player = AudioPlayer();
    _player!.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
    _player!.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _duracionTotal = duration);
    });
    _player!.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _posicionActual = position);
    });
    _player!.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _posicionActual = _duracionTotal;
        });
        _player!.pause();
        _player!.seek(Duration.zero);
      }
    });
  }

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
        debugPrint('AudioPlayer: ruta resuelta → $candidate');
        return candidate;
      }
      // Buscar con extensiones alternativas
      final baseName = fileName.replaceAll(RegExp(r'\.(m4a|wav|aac|amr|mp4)$'), '');
      for (final ext in ['.amr', '.m4a', '.wav', '.aac']) {
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
    // El player se inicializa perezosamente al tocar "Play" 
    // para evitar colapsar el MediaServer (límite de 32 tracks de Android)
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_cargandoAudio) return;
    
    _initPlayerIfNeeded();

    try {
      if (_playing) {
        await _player!.pause();
        return;
      }

      if (_posicionActual > Duration.zero &&
          _duracionTotal > Duration.zero &&
          _posicionActual < _duracionTotal) {
        await _player!.play();
        return;
      }

      setState(() => _cargandoAudio = true);

      final isUrl = widget.url.startsWith('http://') ||
          widget.url.startsWith('https://');

      if (isUrl) {
        await _player!.setUrl(widget.url);
        await _player!.play();
      } else {
        final resolvedPath = await _resolveAudioPath(widget.url);
        if (resolvedPath == null) {
          if (mounted) AppFeedback.error(context, 'Grabación no disponible en este dispositivo');
          return;
        }
        final size = await File(resolvedPath).length();
        if (size <= 0) {
          if (mounted) AppFeedback.error(context, 'El archivo de audio está vacío');
          return;
        }
        await _player!.setFilePath(resolvedPath);
        await _player!.play();
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
    await _player?.seek(Duration(milliseconds: clamped));
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play button with glow effect
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _playing ? [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ] : [],
                ),
                child: IconButton.filled(
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
                          size: 24,
                        ),
                  style: IconButton.styleFrom(
                    backgroundColor: _playing
                        ? const Color(0xFF4ADE80)
                        : Colors.white.withOpacity(0.12),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grabación de llamada',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _playing
                          ? 'Reproduciendo audio...'
                          : 'Toca para reproducir',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
              if (!tieneTranscripcion)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.25)),
                    color: const Color(0xFFFBBF24).withOpacity(0.08),
                  ),
                  child: InkWell(
                    onTap: _transcribiendo ? null : _transcribirConIA,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _transcribiendo
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFBBF24),
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 15, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 6),
                          Text(
                            _transcribiendo ? 'IA...' : 'Transcribir',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Waveform-style slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _playing ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.5),
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: Colors.white,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35), fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDuration(_duracionTotal),
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          
          // Transcription integrated inside the same card
          if (tieneTranscripcion) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: const Color(0xFFFBBF24).withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'TRANSCRIPCIÓN IA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFBBF24).withOpacity(0.5),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _transcripcionLocal ?? widget.transcripcion ?? '',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withOpacity(0.65),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
