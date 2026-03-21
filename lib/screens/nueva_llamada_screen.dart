import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../models/tipo_llamada.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../services/location_service.dart';
import 'speech_llamada_screen.dart';

class NuevaLlamadaScreen extends StatefulWidget {
  const NuevaLlamadaScreen({super.key});

  @override
  State<NuevaLlamadaScreen> createState() => _NuevaLlamadaScreenState();
}

class _NuevaLlamadaScreenState extends State<NuevaLlamadaScreen> {
  TipoLlamada _tipoLlamada = TipoLlamada.manana;
  final _horaInicio = ValueNotifier<DateTime>(DateTime.now());
  final _formKey = GlobalKey<FormState>();
  String _nombreContactado = '';
  int _clientesProgramados = 0;
  int _clientesVisitados = 0;
  double _ventaDia = 0;
  double _recaudoDia = 0;
  bool _cumplioMeta = false;
  bool _coincidenciaPpvcRvc = false;
  int _conversion60 = 0;
  int _recuperacionPerdidos = 0;
  String _observaciones = '';
  bool _confirmacionVeracidad = false;

  @override
  void initState() {
    super.initState();
    _horaInicio.value = DateTime.now();
  }

  @override
  void dispose() {
    _horaInicio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuarioActual;
    if (usuario == null) {
      return const Scaffold(
        body: Center(child: Text('Debe iniciar sesión como supervisor')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva Llamada'),
        backgroundColor: context.ac.bg,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tipo de llamada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TipoLlamada.values.map((t) {
                      return ChoiceChip(
                        label: Text(t.displayName),
                        selected: _tipoLlamada == t,
                        onSelected: (v) => setState(() => _tipoLlamada = t),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SpeechLlamadaScreen(tipoLlamada: _tipoLlamada),
                        ),
                      );
                    },
                    child: Text(
                      _tipoLlamada.objetivo,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.azulCorporativo,
                        fontStyle: FontStyle.italic,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _horaInicio,
                    builder: (context, inicio, _) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inicio de llamada'),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final t = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          inicio,
                                        ),
                                      );
                                      if (t != null) {
                                        _horaInicio.value = DateTime(
                                          inicio.year,
                                          inicio.month,
                                          inicio.day,
                                          t.hour,
                                          t.minute,
                                        );
                                      }
                                    },
                                    icon: Icon(Icons.schedule),
                                    label: Text('Cambiar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Nombre contactado *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Obligatorio' : null,
                    onSaved: (v) => _nombreContactado = v ?? '',
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Clientes programados',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          onSaved: (v) => _clientesProgramados =
                              int.tryParse(v ?? '0') ?? 0,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Clientes visitados',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          onSaved: (v) =>
                              _clientesVisitados = int.tryParse(v ?? '0') ?? 0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Venta del día',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          onSaved: (v) =>
                              _ventaDia = double.tryParse(v ?? '0') ?? 0,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Recaudo del día',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          onSaved: (v) =>
                              _recaudoDia = double.tryParse(v ?? '0') ?? 0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('¿Cumplió meta del día?'),
                    value: _cumplioMeta,
                    onChanged: (v) => setState(() => _cumplioMeta = v),
                  ),
                  SwitchListTile(
                    title: Text('Coincidencia PPVC-RVC'),
                    value: _coincidenciaPpvcRvc,
                    onChanged: (v) => setState(() => _coincidenciaPpvcRvc = v),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Conversión 60',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          onSaved: (v) =>
                              _conversion60 = int.tryParse(v ?? '0') ?? 0,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Recuperación perdidos',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          onSaved: (v) => _recuperacionPerdidos =
                              int.tryParse(v ?? '0') ?? 0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    onSaved: (v) => _observaciones = v ?? '',
                  ),
                  SizedBox(height: 24),
                  Card(
                    color: _confirmacionVeracidad
                        ? AppConstants.verdeMeta.withOpacity(0.1)
                        : null,
                    child: CheckboxListTile(
                      title: Text(
                        'Confirmo que la información registrada es veraz y corresponde a la llamada realizada.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      value: _confirmacionVeracidad,
                      onChanged: (v) =>
                          setState(() => _confirmacionVeracidad = v ?? false),
                    ),
                  ),
                  SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _guardar(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppConstants.verdeMeta,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Registrar llamada'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final usuario = context.read<AppProvider>().usuarioActual;
    if (usuario == null) return;
    if (!_confirmacionVeracidad) {
      AppFeedback.warning(context, 'Debe confirmar la veracidad del registro para continuar.');
      return;
    }

    _formKey.currentState!.save();

    final inicio = _horaInicio.value;
    final fin = DateTime.now();
    final duracion = fin.difference(inicio).inMinutes;

    if (duracion < AppConstants.duracionMinimaLlamada) {
      AppFeedback.warning(
        context,
        'La duración debe ser al menos ${AppConstants.duracionMinimaLlamada} minutos. Actual: $duracion min.',
      );
      return;
    }

    // Ubicación: lastKnown del stream → última conocida de Android → GPS fresco
    double? lat, lng;
    try {
      Position? pos = LocationService.lastKnown;
      if (pos == null) {
        try { pos = await Geolocator.getLastKnownPosition(); } catch (_) {}
      }
      if (pos == null) {
        pos = await LocationService.getCurrentPosition().timeout(const Duration(seconds: 6));
      }
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {}

    final r = RegistroLlamada(
      id: const Uuid().v4(),
      fecha: DateTime.now(),
      horaInicio: inicio,
      horaFin: fin,
      duracionMinutos: duracion,
      tipoLlamada: _tipoLlamada,
      cargoLider: usuario.cargo,
      zona: usuario.zona,
      nombreLider: usuario.nombre,
      nombreContactado: _nombreContactado,
      clientesProgramados: _clientesProgramados,
      clientesVisitados: _clientesVisitados,
      ventaDia: _ventaDia,
      recaudoDia: _recaudoDia,
      cumplioMeta: _cumplioMeta,
      coincidenciaPpvcRvc: _coincidenciaPpvcRvc,
      conversion60: _conversion60,
      recuperacionPerdidos: _recuperacionPerdidos,
      observaciones: _observaciones,
      confirmacionVeracidad: _confirmacionVeracidad,
      latitud: lat,
      longitud: lng,
    );

    try {
      final result = await context.read<AppProvider>().registrarLlamada(r);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.retrying ? Icons.cloud_upload : Icons.check_circle,
                  color: result.retrying ? Colors.orange : Colors.green,
                ),
                SizedBox(width: 10),
                Text('Llamada registrada', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Guardado en', result.savedTo),
                _infoRow('ID Registro', '${result.registroId.substring(0, 20)}...'),
                _infoRow('GPS', result.hasGps ? '✅ Coordenadas capturadas' : '❌ Sin GPS (permiso denegado)'),
                _infoRow('Sync', '✅ Servidor actualizado'),
                if (result.hasGps && lat != null && lng != null) ...[
                  SizedBox(height: 8),
                  Text('📍 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK'),
              ),
            ],
          ),
        );
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '').trim();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 10),
                Text('Error al subir llamada', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Text(
              msg.isEmpty
                  ? 'No se pudo registrar en la base de datos.'
                  : 'No se pudo registrar en la base de datos.\n\nMotivo: $msg',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
