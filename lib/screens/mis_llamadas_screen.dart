import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../services/data_service.dart';
import '../services/post_call_notification_service.dart';
import '../services/transcription_service.dart';
import '../utils/constants.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Observaciones actualizadas')),
        );
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

          Widget chipEstado({
            required IconData icono,
            required String texto,
            required Color color,
            Color? fondo,
          }) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: fondo ?? color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }

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

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: tipoColor.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.phone_in_talk_rounded,
                                color: tipoColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contacto,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('HH:mm').format(l.horaInicio)} - ${DateFormat('HH:mm').format(l.horaFin)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            chipEstado(
                              icono: Icons.schedule_rounded,
                              texto: '${l.duracionMinutos} min',
                              color: const Color(0xFF374151),
                              fondo: const Color(0xFFF3F4F6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            chipEstado(
                              icono: Icons.label_rounded,
                              texto: l.tipoLlamada.displayName,
                              color: tipoColor,
                            ),
                            if (tieneAudio)
                              chipEstado(
                                icono: Icons.mic_rounded,
                                texto: 'Audio guardado',
                                color: AppConstants.verdeMeta,
                              ),
                            if (tieneTranscripcion)
                              chipEstado(
                                icono: Icons.auto_awesome_rounded,
                                texto: 'Transcripción',
                                color: const Color(0xFF7C3AED),
                              ),
                          ],
                        ),
                        if (l.ventaDia > 0 || l.recaudoDia > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                if (l.ventaDia > 0)
                                  Text(
                                    'Venta: \$${NumberFormat('#,##0').format(l.ventaDia)}',
                                    style: const TextStyle(
                                      color: AppConstants.verdeMeta,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (l.recaudoDia > 0)
                                  Text(
                                    'Recaudo: \$${NumberFormat('#,##0').format(l.recaudoDia)}',
                                    style: const TextStyle(
                                      color: AppConstants.azulCorporativo,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (l.observaciones.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              l.observaciones,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF374151),
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (provider.usuarioActual != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _mostrarDialogoEditarObservaciones(context, l),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Editar observaciones'),
                            ),
                          ),
                        ],
                        if (tieneAudio || tieneTranscripcion) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tieneAudio)
                                  _AudioPlayerWidget(
                                    url: l.rutaGrabacion!,
                                    registroId: l.id,
                                    transcripcion: l.transcripcionTexto,
                                    onTranscripcionGuardada: () {
                                      provider.cargarDatosHoy();
                                    },
                                  ),
                                if (tieneTranscripcion) ...[
                                  if (tieneAudio) const SizedBox(height: 8),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Transcripción (Gemini)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppConstants.azulCorporativo,
                                        ),
                                      ),
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: Text(
                                            l.transcripcionTexto!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.55,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

  @override
  void initState() {
    super.initState();
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
        await _player.play(UrlSource(widget.url));
      } else {
        await _player.play(DeviceFileSource(widget.url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo reproducir el audio'),
            backgroundColor: AppConstants.rojoCritico,
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transcripción guardada'),
              backgroundColor: AppConstants.verdeMeta,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo transcribir. Verifique que la API tenga el endpoint /transcribe.',
              ),
              backgroundColor: AppConstants.rojoCritico,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _transcribiendo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppConstants.rojoCritico,
          ),
        );
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
