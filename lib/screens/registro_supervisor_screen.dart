import 'package:flutter/material.dart';
import '../models/supervisor.dart';
import '../models/nivel_cargo.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';

class RegistroSupervisorScreen extends StatefulWidget {
  final NivelCargo cargoInicial;

  const RegistroSupervisorScreen({super.key, this.cargoInicial = NivelCargo.coach});

  @override
  State<RegistroSupervisorScreen> createState() => _RegistroSupervisorScreenState();
}

class _RegistroSupervisorScreenState extends State<RegistroSupervisorScreen> {
  final _formKey = GlobalKey<FormState>();
  late NivelCargo _cargo;
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  String? _superiorId;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargo = widget.cargoInicial;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _zonaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      String? superiorId = _superiorId;
      if (_cargo != NivelCargo.jefe && superiorId == null) {
        final lista = await DataService.getSupervisores();
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
        superiorId: superiorId,
        subordinadosIds: [],
      );
      await DataService.insertSupervisor(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_cargo.displayName} registrado correctamente'),
            backgroundColor: AppConstants.verdeMeta,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppConstants.rojoCritico,
          ),
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
        backgroundColor: AppConstants.azulCorporativo,
        foregroundColor: Colors.white,
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
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _cargo = v ?? _cargo),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreCtrl,
                decoration: _inputDecoration('Nombre completo'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _codigoCtrl,
                decoration: _inputDecoration('Codigo (ej: JEF001, KAM001, COA001)'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _zonaCtrl,
                decoration: _inputDecoration('Zona (ej: Norte, Nacional)'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              if (_cargo != NivelCargo.jefe) ...[
                const SizedBox(height: 20),
                FutureBuilder<List<Supervisor>>(
                  future: DataService.getSupervisores(),
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
                      initialValue: _superiorId ?? (superiores.isNotEmpty ? superiores.first.id : null),
                      decoration: _inputDecoration('Reporta a'),
                      items: superiores
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.nombre} (${s.cargo.displayName})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _superiorId = v),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.azulCorporativo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _guardando
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
