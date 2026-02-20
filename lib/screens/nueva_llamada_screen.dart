import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/registro_llamada.dart';
import '../models/tipo_llamada.dart';
import '../utils/constants.dart';
import 'speech_llamada_screen.dart';
import '../widgets/recording_overlay.dart';

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
        title: const Text('Nueva Llamada'),
        backgroundColor: AppConstants.azulCorporativo,
        foregroundColor: Colors.white,
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
              const Text(
                'Tipo de llamada',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpeechLlamadaScreen(
                        tipoLlamada: _tipoLlamada,
                      ),
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
              const SizedBox(height: 24),
              ValueListenableBuilder<DateTime>(
                valueListenable: _horaInicio,
                builder: (context, inicio, _) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inicio de llamada'),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(inicio),
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
                                icon: const Icon(Icons.schedule),
                                label: const Text('Cambiar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nombre contactado *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obligatorio' : null,
                onSaved: (v) => _nombreContactado = v ?? '',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Clientes programados',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '0',
                      onSaved: (v) =>
                          _clientesProgramados = int.tryParse(v ?? '0') ?? 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
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
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('¿Cumplió meta del día?'),
                value: _cumplioMeta,
                onChanged: (v) => setState(() => _cumplioMeta = v),
              ),
              SwitchListTile(
                title: const Text('Coincidencia PPVC-RVC'),
                value: _coincidenciaPpvcRvc,
                onChanged: (v) => setState(() => _coincidenciaPpvcRvc = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Conversión 60',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '0',
                      onSaved: (v) =>
                          _conversion60 = int.tryParse(v ?? '0') ?? 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Recuperación perdidos',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '0',
                      onSaved: (v) =>
                          _recuperacionPerdidos = int.tryParse(v ?? '0') ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onSaved: (v) => _observaciones = v ?? '',
              ),
              const SizedBox(height: 24),
              Card(
                color: _confirmacionVeracidad
                    ? AppConstants.verdeMeta.withOpacity(0.1)
                    : null,
                child: CheckboxListTile(
                  title: const Text(
                    'Confirmo que la información registrada es veraz y corresponde a la llamada realizada.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  value: _confirmacionVeracidad,
                  onChanged: (v) => setState(() => _confirmacionVeracidad = v ?? false),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _guardar(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.verdeMeta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Registrar llamada'),
              ),
            ],
          ),
        ),
        ),
        const RecordingOverlay(visible: true),
        ],
      ),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final usuario = context.read<AppProvider>().usuarioActual;
    if (usuario == null) return;
    if (!_confirmacionVeracidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe confirmar la veracidad del registro para continuar.',
          ),
          backgroundColor: AppConstants.rojoCritico,
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    final inicio = _horaInicio.value;
    final fin = DateTime.now();
    final duracion = fin.difference(inicio).inMinutes;

    if (duracion < AppConstants.duracionMinimaLlamada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La duración debe ser al menos ${AppConstants.duracionMinimaLlamada} minutos. Actual: $duracion min.',
          ),
          backgroundColor: AppConstants.rojoCritico,
        ),
      );
      return;
    }

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
    );

    try {
      await context.read<AppProvider>().registrarLlamada(r);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Llamada registrada correctamente'),
            backgroundColor: AppConstants.verdeMeta,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppConstants.rojoCritico,
          ),
        );
      }
    }
  }
}
