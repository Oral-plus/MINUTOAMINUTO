import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../utils/constants.dart';

class MisLlamadasScreen extends StatelessWidget {
  const MisLlamadasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Llamadas Hoy'),
        backgroundColor: AppConstants.azulCorporativo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          List<RegistroLlamada> llamadas;
          if (provider.usuarioActual != null) {
            llamadas = provider.llamadas
                .where((l) => l.nombreLider == provider.usuarioActual!.nombre)
                .toList();
          } else if (provider.vendedorActual != null) {
            llamadas = provider.llamadas
                .where((l) =>
                    l.nombreContactado == provider.vendedorActual!.nombre)
                .toList();
          } else {
            llamadas = provider.llamadas;
          }

          llamadas.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));

          if (llamadas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_in_talk,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay llamadas registradas hoy',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: llamadas.length,
            itemBuilder: (context, i) {
              final l = llamadas[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _colorTipo(l.tipoLlamada)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l.tipoLlamada.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _colorTipo(l.tipoLlamada),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${l.duracionMinutos} min',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        provider.usuarioActual != null
                            ? 'A: ${l.nombreContactado}'
                            : 'De: ${l.nombreLider}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormat('HH:mm').format(l.horaInicio)} - ${DateFormat('HH:mm').format(l.horaFin)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (l.ventaDia > 0 || l.recaudoDia > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (l.ventaDia > 0)
                              Text(
                                'Venta: \$${NumberFormat('#,##0').format(l.ventaDia)}',
                                style: const TextStyle(
                                  color: AppConstants.verdeMeta,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (l.ventaDia > 0 && l.recaudoDia > 0)
                              const Text(' | '),
                            if (l.recaudoDia > 0)
                              Text(
                                'Recaudo: \$${NumberFormat('#,##0').format(l.recaudoDia)}',
                                style: const TextStyle(
                                  color: AppConstants.azulCorporativo,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (l.observaciones.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          l.observaciones,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (provider.usuarioActual != null && (l.rutaGrabacion != null || l.transcripcionTexto != null)) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        if (l.rutaGrabacion != null && l.rutaGrabacion!.isNotEmpty)
                          _AudioPlayerWidget(url: l.rutaGrabacion!),
                        if (l.transcripcionTexto != null && l.transcripcionTexto!.isNotEmpty) ...[
                          if (l.rutaGrabacion != null && l.rutaGrabacion!.isNotEmpty) const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Transcripción (Gemini)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppConstants.azulCorporativo,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    l.transcripcionTexto!,
                                    style: const TextStyle(fontSize: 13, height: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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

class _AudioPlayerWidget extends StatefulWidget {
  final String url;

  const _AudioPlayerWidget({required this.url});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      final isUrl = widget.url.startsWith('http://') || widget.url.startsWith('https://');
      if (isUrl) {
        await _player.play(UrlSource(widget.url));
      } else {
        await _player.play(DeviceFileSource(widget.url));
      }
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: _togglePlay,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          style: IconButton.styleFrom(
            backgroundColor: AppConstants.azulCorporativo,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Escuchar grabación',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
