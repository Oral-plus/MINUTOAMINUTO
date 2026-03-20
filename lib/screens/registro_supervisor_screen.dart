import '../utils/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:art_sweetalert_new/art_sweetalert_new.dart';
import '../models/supervisor.dart';
import '../models/nivel_cargo.dart';
import '../services/data_service.dart';

class RegistroSupervisorScreen extends StatefulWidget {
  final NivelCargo cargoInicial;

  const RegistroSupervisorScreen({
    super.key,
    this.cargoInicial = NivelCargo.coach,
  });

  @override
  State<RegistroSupervisorScreen> createState() =>
      _RegistroSupervisorScreenState();
}

class _RegistroSupervisorScreenState extends State<RegistroSupervisorScreen> {
  final _formKey = GlobalKey<FormState>();
  late NivelCargo _cargo;
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  String? _superiorId;
  bool _guardando = false;
  Future<List<Supervisor>>? _supervisoresFuture;

  @override
  void initState() {
    super.initState();
    _cargo = widget.cargoInicial;
    _supervisoresFuture = _loadSupervisores();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _zonaCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<List<Supervisor>> _loadSupervisores() async {
    try {
      return await DataService.getSupervisores().timeout(
        const Duration(seconds: 12),
        onTimeout: () => <Supervisor>[],
      );
    } catch (_) {
      return <Supervisor>[];
    }
  }

  String _mensajeErrorRegistro(Object e) {
    final msg = e.toString();
    if (e is TimeoutException || msg.contains('TimeoutException')) {
      return 'La API LAN tardó en responder. '
          'El registro quedó guardado localmente y se puede sincronizar luego.';
    }
    return 'Error: $e';
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      String? superiorId = _superiorId;
      if (_cargo != NivelCargo.jefe && superiorId == null) {
        final lista = await _loadSupervisores();
        final superiores = _cargo == NivelCargo.kam
            ? lista.where((s) => s.esJefe).toList()
            : lista.where((s) => s.esKam).toList();
        if (superiores.isNotEmpty) {
          superiorId = superiores.first.id;
        }
      }
      final id = 'sup_${DateTime.now().millisecondsSinceEpoch}';
      final s = Supervisor(
        id: id,
        nombre: _nombreCtrl.text.trim(),
        codigo: _codigoCtrl.text.trim().toUpperCase(),
        zona: _zonaCtrl.text.trim(),
        cargo: _cargo,
        telefono: _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        superiorId: superiorId,
        subordinadosIds: [],
      );
      await DataService.insertSupervisor(s);
      if (mounted) {
        await ArtSweetAlert.show(
          context: context,
          title: Text('¡Registro exitoso!'),
          content: Text('${_cargo.displayName} registrado correctamente.'),
          type: ArtAlertType.success,
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        await ArtSweetAlert.show(
          context: context,
          title: Text('Error'),
          content: Text(_mensajeErrorRegistro(e)),
          type: ArtAlertType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar ${_cargo.displayName}'),
        backgroundColor: context.ac.fg,
        foregroundColor: context.ac.fg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<NivelCargo>(
                initialValue: _cargo,
                decoration: _inputDecoration('Cargo'),
                items: NivelCargo.values
                    .where((c) => c != NivelCargo.vendedor)
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _cargo = v ?? _cargo),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _nombreCtrl,
                decoration: _inputDecoration('Nombre completo'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _codigoCtrl,
                decoration: _inputDecoration(
                  'Codigo (ej: JEF001, KAM001, COA001)',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _zonaCtrl,
                decoration: _inputDecoration('Zona (ej: Norte, Nacional)'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: _inputDecoration(
                  'Teléfono (para correlación dual)',
                ).copyWith(hintText: 'Ej: 300 123 4567'),
                keyboardType: TextInputType.phone,
              ),
              if (_cargo != NivelCargo.jefe) ...[
                SizedBox(height: 20),
                FutureBuilder<List<Supervisor>>(
                  future: _supervisoresFuture,
                  builder: (context, snap) {
                    final lista = snap.data ?? [];
                    final superiores = _cargo == NivelCargo.kam
                        ? lista.where((s) => s.esJefe).toList()
                        : lista.where((s) => s.esKam).toList();
                    if (superiores.isEmpty) {
                      return Text(
                        _cargo == NivelCargo.kam
                            ? 'Agregue primero un Jefe de Ventas'
                            : 'Agregue primero un KAM',
                        style: TextStyle(color: Colors.grey[600]),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue:
                          _superiorId ??
                          (superiores.isNotEmpty ? superiores.first.id : null),
                      decoration: _inputDecoration('Reporta a'),
                      items: superiores
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.nombre} (${s.cargo.displayName})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _superiorId = v),
                    );
                  },
                ),
              ],
              SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 18,
                      color: context.ac.fg,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Destino de registro: ${DataService.userRegistrationDestination}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: context.ac.fg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _guardando
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.ac.fg,
                        ),
                      )
                    : Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
