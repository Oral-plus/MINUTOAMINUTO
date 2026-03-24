import '../utils/app_theme.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../services/data_service.dart';
import '../services/call_monitor_service.dart';
import '../services/transcription_manager.dart';
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
  DateTime? _selectedDate;
  List<RegistroLlamada> _llamadas = [];
  bool _loading = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Arrancar siempre en "hoy"
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _cargarLlamadas();
      if (mounted) _checkPendingCumplioMeta();
    });
  }

  Future<void> _checkPendingCumplioMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(CallMonitorService.keyCumplioMetaPending);
      if (id == null || id.isEmpty) return;
      await prefs.remove(CallMonitorService.keyCumplioMetaPending);
      if (!mounted) return;
      await _showCumplioMetaSheet(id);
    } catch (_) {}
  }

  Future<void> _showCumplioMetaSheet(String registroId) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.ac.surfaceAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.ac.fg.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.ac.fg.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.check_circle_outline_rounded,
                size: 40, color: context.ac.fg.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(
              '¿Cumplió la meta del día?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.ac.fg,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Registra el resultado de esta llamada',
              style: TextStyle(
                fontSize: 13,
                color: context.ac.fg.withOpacity(0.45),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('No', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Sí', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppConstants.verdeMeta,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await DataService.updateRegistroLlamadaCumplioMeta(registroId, result);
      if (mounted) _cargarLlamadas();
    } catch (_) {}
  }

  Future<void> _cargarLlamadas() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final provider = context.read<AppProvider>();
      final nombre = provider.usuarioActual?.nombre ?? provider.vendedorActual?.nombre;
      final hoy = DateTime.now();
      final desde = _selectedDate ?? hoy;
      final hasta = _selectedDate ?? hoy;
      var lista = await DataService.getRegistroLlamadas(
        desde: desde,
        hasta: hasta,
      );
      if (nombre != null) {
        lista = lista.where((l) => l.nombreLider == nombre).toList();
      }
      // Filtro client-side por día exacto
      if (_selectedDate != null) {
        final sel = _selectedDate!;
        lista = lista.where((l) {
          final d = l.fecha;
          return d.year == sel.year && d.month == sel.month && d.day == sel.day;
        }).toList();
      }
      lista.sort((a, b) => b.horaInicio.compareTo(a.horaInicio));
      if (mounted) setState(() { _llamadas = lista; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeDate(DateTime d) {
    final hoy = DateTime.now();
    if (d.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) return;
    setState(() => _selectedDate = d);
    _cargarLlamadas();
  }


  String _labelFecha() {
    final d = _selectedDate;
    if (d == null) return 'TODAS';
    final hoy = DateTime.now();
    if (d.year == hoy.year && d.month == hoy.month && d.day == hoy.day) return 'HOY';
    final ayer = hoy.subtract(const Duration(days: 1));
    if (d.year == ayer.year && d.month == ayer.month && d.day == ayer.day) return 'AYER';
    return DateFormat('dd MMM yyyy', 'es').format(d).toUpperCase();
  }

  Widget _buildDateBar() {
    final hoy = DateTime.now();
    final sel = _selectedDate;
    final esHoy = sel != null &&
        sel.year == hoy.year &&
        sel.month == hoy.month &&
        sel.day == hoy.day;
    return Container(
      color: context.ac.appBarBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: sel == null ? null : () => _changeDate(sel.subtract(const Duration(days: 1))),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: sel ?? hoy,
                  firstDate: DateTime(2024),
                  lastDate: hoy,
                );
                if (picked != null) _changeDate(picked);
              },
              child: Center(
                child: Text(
                  _labelFecha(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: context.ac.fg,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: (sel == null || esHoy) ? null : () => _changeDate(sel.add(const Duration(days: 1))),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (!esHoy)
            TextButton(
              onPressed: () => _changeDate(hoy),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Hoy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.ac.fg)),
            ),
          if (sel != null)
            TextButton(
              onPressed: () { setState(() => _selectedDate = null); _cargarLlamadas(); },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Todas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.ac.fg)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RegistroLlamada> get _filteredLlamadas {
    if (_searchQuery.isEmpty) return _llamadas;
    final q = _searchQuery.toLowerCase();
    return _llamadas.where((l) {
      return l.nombreContactado.toLowerCase().contains(q) ||
          (l.numeroContacto ?? '').contains(q) ||
          l.nombreLider.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final llamadas = _filteredLlamadas;
    final totalMinutos = llamadas.fold<int>(0, (acc, l) => acc + l.duracionMinutos);
    final llamadasConAudio = llamadas.where((l) => _isConAudio(l)).length;
    final llamadasConTranscripcion = llamadas.where((l) => _isConTranscripcion(l)).length;

    return Scaffold(
      backgroundColor: context.ac.bg,
      appBar: AppBar(
        title: Text('MIS LLAMADAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
        backgroundColor: context.ac.appBarBg,
        foregroundColor: context.ac.fg,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildDateBar(),
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontSize: 13, color: context.ac.fg),
                  decoration: InputDecoration(
                    hintText: 'Buscar nombre o número...',
                    hintStyle: TextStyle(fontSize: 12, color: context.ac.fg.withOpacity(0.3)),
                    prefixIcon: Icon(Icons.search, size: 18, color: context.ac.fg.withOpacity(0.3)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                            child: Icon(Icons.close, size: 16, color: context.ac.fg.withOpacity(0.4)),
                          )
                        : null,
                    filled: true,
                    fillColor: context.ac.fg.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
            ),
          ]),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.ac.fg))
          : RefreshIndicator(
              onRefresh: _cargarLlamadas,
              backgroundColor: context.ac.surface,
              color: context.ac.fg,
              child: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  return ListView.separated(
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
                      if (llamadas.isEmpty) return const _EstadoVacioLlamadasCard();
                      final l = llamadas[i - 1];
                      return _LlamadaCard(
                        llamada: l,
                        contacto: provider.usuarioActual != null ? l.nombreContactado : 'De: ${l.nombreLider}',
                        tipoColor: _colorTipo(l.tipoLlamada),
                        tieneAudio: _isConAudio(l),
                        tieneTranscripcion: _isConTranscripcion(l),
                        esUsuarioActual: provider.usuarioActual != null,
                        onTranscripcionGuardada: _cargarLlamadas,
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  static bool _isConAudio(RegistroLlamada l) {
    final ruta = l.rutaGrabacion;
    return ruta != null && ruta.trim().isNotEmpty;
  }

  static bool _isConTranscripcion(RegistroLlamada l) {
    final texto = l.transcripcionTexto ?? TranscriptionManager.instance.getText(l.id);
    return texto != null && texto.trim().isNotEmpty;
  }

  static Color _colorTipo(dynamic tipo) {
    switch (tipo.toString()) {
      case 'TipoLlamada.manana':
        return const Color(0xFF6B7280);
      case 'TipoLlamada.tarde':
        return const Color(0xFF111827);
      case 'TipoLlamada.kam':
        return const Color(0xFF6B7280);
      case 'TipoLlamada.jefe':
        return const Color(0xFF111827);
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
  final VoidCallback onTranscripcionGuardada;

  const _LlamadaCard({
    required this.llamada,
    required this.contacto,
    required this.tipoColor,
    required this.tieneAudio,
    required this.tieneTranscripcion,
    required this.esUsuarioActual,
    required this.onTranscripcionGuardada,
  });

  @override
  State<_LlamadaCard> createState() => _LlamadaCardState();
}

class _LlamadaCardState extends State<_LlamadaCard> {
  bool _expandido = false;
  bool _transcripcionRefrescada = false;

  @override
  void initState() {
    super.initState();
    TranscriptionManager.instance.addListener(_onTranscriptionUpdate);
  }

  @override
  void dispose() {
    TranscriptionManager.instance.removeListener(_onTranscriptionUpdate);
    super.dispose();
  }

  void _onTranscriptionUpdate() {
    if (!mounted) return;
    final id = widget.llamada.id;
    if (TranscriptionManager.instance.isDone(id) && !_transcripcionRefrescada) {
      _transcripcionRefrescada = true;
      widget.onTranscripcionGuardada();
    }
    setState(() {});
  }

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

  // ── Helpers visuales ──────────────────────────────────────────────────────

  Widget _statusTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.ac.fg.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: context.ac.fg.withOpacity(0.45)),
        SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.ac.fg.withOpacity(0.45),
                letterSpacing: 0.2)),
      ]),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.ac.fg.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ac.fg.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: context.ac.fg.withOpacity(0.3),
                letterSpacing: 1.2)),
        SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.ac.fg,
                letterSpacing: -0.5)),
      ]),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label.toUpperCase(),
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: context.ac.fg.withOpacity(0.28),
            letterSpacing: 1.8));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.llamada;
    final coords = _parseCoords(l);
    final inicio = l.horaInicio.toLocal();
    final fin = l.horaFin.toLocal();
    final horaStr =
        '${DateFormat('HH:mm').format(inicio)} – ${DateFormat('HH:mm').format(fin)}';
    final hoy = DateTime.now();
    final esHoy = inicio.year == hoy.year &&
        inicio.month == hoy.month &&
        inicio.day == hoy.day;
    final ayer = hoy.subtract(const Duration(days: 1));
    final esAyer = inicio.year == ayer.year &&
        inicio.month == ayer.month &&
        inicio.day == ayer.day;
    final fechaLabel = esHoy
        ? 'HOY'
        : esAyer
        ? 'AYER'
        : '${l.horaInicio.day.toString().padLeft(2, '0')}/${l.horaInicio.month.toString().padLeft(2, '0')}';
    final durStr = l.duracionMinutos > 0 ? '${l.duracionMinutos} min' : '< 1 min';
    final words = widget.contacto.trim().split(' ');
    final initials = words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final transcPending = TranscriptionManager.instance.isPending(widget.llamada.id);
    final transcError = TranscriptionManager.instance.isError(widget.llamada.id);
    final transcPct = TranscriptionManager.instance.getProgress(widget.llamada.id);

    return GestureDetector(
      onTap: () => setState(() => _expandido = !_expandido),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: context.ac.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.ac.fg.withOpacity(_expandido ? 0.1 : 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: context.ac.fg.withOpacity(_expandido ? 0.06 : 0.025),
              blurRadius: _expandido ? 28 : 10,
              offset: Offset(0, _expandido ? 10 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Acento lateral de color según tipo ──────────────────
                Container(width: 3, color: widget.tipoColor),
                // ── Cuerpo ───────────────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Cabecera
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 17, 14, 15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar con iniciales
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: context.ac.fg.withOpacity(0.07),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials.isEmpty ? '?' : initials,
                                  style: TextStyle(
                                    fontSize: initials.length > 1 ? 13 : 16,
                                    fontWeight: FontWeight.w900,
                                    color: context.ac.fg.withOpacity(0.6),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            // Nombre + meta
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.contacto,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: context.ac.fg,
                                      letterSpacing: -0.3,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '$fechaLabel  ·  $horaStr  ·  ${l.tipoLlamada.displayName.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: context.ac.fg.withOpacity(0.32),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  SizedBox(height: 9),
                                  // Tags de estado
                                  Wrap(
                                    spacing: 5,
                                    runSpacing: 4,
                                    children: [
                                      _statusTag(Icons.schedule_rounded, durStr),
                                      if (!widget.tieneAudio)
                                        _statusTag(Icons.phone_missed_rounded, 'Perdida'),
                                      if (widget.tieneAudio)
                                        _statusTag(Icons.mic_rounded, 'Audio'),
                                      if (widget.tieneTranscripcion)
                                        _statusTag(Icons.auto_awesome_rounded, 'IA'),
                                      if (transcPending)
                                        _statusTag(Icons.hourglass_top_rounded,
                                            'IA ${(transcPct * 100).round()}%'),
                                      if (transcError)
                                        _statusTag(Icons.error_outline_rounded, 'Error'),
                                      if (coords != null)
                                        GestureDetector(
                                          onTap: () => MapLocationModal.show(context,
                                              latitude: coords.lat,
                                              longitude: coords.lng,
                                              contactName: l.nombreContactado),
                                          child: _statusTag(Icons.location_on_rounded, 'GPS'),
                                        ),
                                      if (l.rutaGrabacionPuntoB != null &&
                                          l.rutaGrabacionPuntoB!.isNotEmpty)
                                        _statusTag(Icons.call_merge_rounded, 'A+B'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Chevron
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: AnimatedRotation(
                                turns: _expandido ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: context.ac.fg.withOpacity(0.2),
                                    size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Contenido expandido ──────────────────────────────
                      if (_expandido) ...[
                        Divider(height: 1, color: context.ac.fg.withOpacity(0.06)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Métricas en grid 2×2
                              if (l.ventaDia > 0 ||
                                  l.recaudoDia > 0 ||
                                  l.clientesProgramados > 0 ||
                                  l.clientesVisitados > 0) ...[
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 2.8,
                                  children: [
                                    if (l.ventaDia > 0)
                                      _metricTile('VENTA DÍA',
                                          '\$${NumberFormat('#,##0').format(l.ventaDia)}'),
                                    if (l.recaudoDia > 0)
                                      _metricTile('RECAUDO',
                                          '\$${NumberFormat('#,##0').format(l.recaudoDia)}'),
                                    if (l.clientesProgramados > 0)
                                      _metricTile('PROGRAMADOS',
                                          '${l.clientesProgramados}'),
                                    if (l.clientesVisitados > 0)
                                      _metricTile('VISITADOS',
                                          '${l.clientesVisitados}'),
                                    if (l.conversion60 > 0)
                                      _metricTile('CONV. 60', '${l.conversion60}'),
                                    if (l.recuperacionPerdidos > 0)
                                      _metricTile('RECUP. PERDIDOS',
                                          '${l.recuperacionPerdidos}'),
                                  ],
                                ),
                                SizedBox(height: 14),
                              ],
                              // Indicadores booleanos
                              if (l.cumplioMeta || l.coincidenciaPpvcRvc) ...[
                                Wrap(spacing: 8, children: [
                                  if (l.cumplioMeta)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: context.ac.fg.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: context.ac.fg.withOpacity(0.1)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.check_circle_rounded,
                                            size: 12, color: context.ac.fg.withOpacity(0.5)),
                                        SizedBox(width: 5),
                                        Text('Cumplió meta',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: context.ac.fg.withOpacity(0.55))),
                                      ]),
                                    ),
                                  if (l.coincidenciaPpvcRvc)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: context.ac.fg.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: context.ac.fg.withOpacity(0.1)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.link_rounded,
                                            size: 12, color: context.ac.fg.withOpacity(0.5)),
                                        SizedBox(width: 5),
                                        Text('PPVC-RVC',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: context.ac.fg.withOpacity(0.55))),
                                      ]),
                                    ),
                                ]),
                                SizedBox(height: 14),
                              ],
                              // Observaciones ocultas por diseño
                              // Mapa
                              if (coords != null) ...[
                                _sectionLabel('Ubicación de la llamada'),
                                SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => MapLocationModal.show(context,
                                      latitude: coords.lat,
                                      longitude: coords.lng,
                                      contactName: l.nombreContactado),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Stack(children: [
                                      MapLocationModal.miniMap(
                                        latitude: coords.lat,
                                        longitude: coords.lng,
                                        height: MediaQuery.of(context).size.shortestSide * 0.38,
                                      ),
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.65),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.open_in_full_rounded,
                                                size: 12, color: Colors.white),
                                            SizedBox(width: 5),
                                            Text('Ver mapa',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700)),
                                          ]),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                              // Audio
                              if (widget.tieneAudio) ...[
                                _sectionLabel('Grabación'),
                                SizedBox(height: 8),
                                _AudioPlayerWidget(
                                  url: l.rutaGrabacion!,
                                  registroId: l.id,
                                  // Usar texto de la BD o del caché en memoria (sin esperar recarga de la API)
                                  transcripcion: l.transcripcionTexto ??
                                      TranscriptionManager.instance.getText(l.id),
                                  onTranscripcionGuardada:
                                      widget.onTranscripcionGuardada,
                                ),
                                SizedBox(height: 14),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: context.ac.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.ac.fg.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Número grande
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$totalLlamadas',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: context.ac.fg,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              Text(
                'LLAMADAS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: context.ac.fg.withOpacity(0.28),
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),
          // Separador vertical
          Container(
            width: 1,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: context.ac.fg.withOpacity(0.08),
          ),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow(context, Icons.schedule_rounded, '$totalMinutos min'),
                SizedBox(height: 7),
                _statRow(context, Icons.mic_rounded, '$conAudio audios'),
                SizedBox(height: 7),
                _statRow(context, Icons.auto_awesome_rounded, '$conTranscripcion transcritas'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 13, color: context.ac.fg.withOpacity(0.3)),
      SizedBox(width: 7),
      Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.ac.fg.withOpacity(0.5),
          )),
    ]);
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
        color: context.ac.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.ac.fg.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.ac.fg.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.ac.fg.withOpacity(0.08)),
            ),
            child: Icon(
              Icons.phone_in_talk_outlined,
              color: context.ac.fg.withOpacity(0.2),
              size: 28,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Sin llamadas hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.ac.fg,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Las llamadas que registres durante el día\naparecerán en este módulo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.ac.fg.withOpacity(0.3), height: 1.5),
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
    // Auto-transcribir si tiene audio pero no transcripción todavía
    final tieneTranscripcion =
        widget.transcripcion != null && widget.transcripcion!.isNotEmpty;
    if (!tieneTranscripcion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TranscriptionManager.instance.enqueue(widget.registroId, widget.url);
      });
    }
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
        _player!.play();
        return;
      }

      setState(() => _cargandoAudio = true);

      final isUrl = widget.url.startsWith('http://') ||
          widget.url.startsWith('https://');

      if (isUrl) {
        await _player!.setUrl(widget.url);
        if (mounted) setState(() => _cargandoAudio = false);
        _player!.play();
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
        if (mounted) setState(() => _cargandoAudio = false);
        _player!.play();
      }
    } catch (e) {
      debugPrint('AudioPlayer error: $e — url: ${widget.url}');
      if (mounted) {
        AppFeedback.error(context, 'No se pudo reproducir el audio');
      }
    } finally {
      if (mounted && _cargandoAudio) setState(() => _cargandoAudio = false);
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

  void _reintentarTranscripcion() {
    TranscriptionManager.instance.retry(widget.registroId, widget.url);
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
        color: context.ac.fg.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ac.fg.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play button with glow effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _playing ? [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ] : [],
                ),
                child: IconButton.filled(
                  onPressed: _togglePlay,
                  icon: _cargandoAudio
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.ac.fg,
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
                        ? const Color(0xFFD4AF37)
                        : context.ac.fg.withOpacity(0.12),
                    foregroundColor: _playing ? const Color(0xFF111827) : context.ac.fg,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grabación de llamada',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.ac.fg,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      _playing
                          ? 'Reproduciendo audio...'
                          : 'Toca para reproducir',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.ac.fg.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
              if (!tieneTranscripcion &&
                  TranscriptionManager.instance.isPending(widget.registroId))
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: TranscriptionManager.instance.getProgress(widget.registroId),
                          color: context.ac.fg.withOpacity(0.6),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'IA ${(TranscriptionManager.instance.getProgress(widget.registroId) * 100).round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.ac.fg.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              if (!tieneTranscripcion &&
                  TranscriptionManager.instance.isError(widget.registroId))
                InkWell(
                  onTap: _reintentarTranscripcion,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 15, color: context.ac.fg.withOpacity(0.5)),
                        SizedBox(width: 6),
                        Text('Reintentar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.ac.fg.withOpacity(0.5))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          // Waveform-style slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _playing ? const Color(0xFFD4AF37) : context.ac.fg.withOpacity(0.5),
              inactiveTrackColor: context.ac.fg.withOpacity(0.08),
              thumbColor: context.ac.fg,
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
                  style: TextStyle(fontSize: 11, color: context.ac.fg.withOpacity(0.35), fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDuration(_duracionTotal),
                  style: TextStyle(fontSize: 11, color: context.ac.fg.withOpacity(0.35), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          
          // Transcription integrated inside the same card
          if (tieneTranscripcion) ...[
            SizedBox(height: 16),
            Divider(color: context.ac.fg.withOpacity(0.05), height: 1),
            SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: const Color(0xFFFBBF24).withOpacity(0.5)),
                SizedBox(width: 8),
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
            SizedBox(height: 8),
            Text(
              _transcripcionLocal ?? widget.transcripcion ?? '',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.ac.fg.withOpacity(0.65),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
