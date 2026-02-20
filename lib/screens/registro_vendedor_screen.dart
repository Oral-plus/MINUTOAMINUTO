import 'package:flutter/material.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';

class RegistroVendedorScreen extends StatefulWidget {
  const RegistroVendedorScreen({super.key});

  @override
  State<RegistroVendedorScreen> createState() => _RegistroVendedorScreenState();
}

class _RegistroVendedorScreenState extends State<RegistroVendedorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  String? _coachId;
  final _presupuestoMensualCtrl = TextEditingController(text: '0');
  final _presupuestoDiarioCtrl = TextEditingController(text: '0');
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _zonaCtrl.dispose();
    _presupuestoMensualCtrl.dispose();
    _presupuestoDiarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_coachId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un Coach'),
          backgroundColor: AppConstants.rojoCritico,
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final id = 'ven_${DateTime.now().millisecondsSinceEpoch}';
      final presupM = double.tryParse(_presupuestoMensualCtrl.text) ?? 0;
      final presupD = double.tryParse(_presupuestoDiarioCtrl.text) ?? 0;
      final v = Vendedor(
        id: id,
        nombre: _nombreCtrl.text.trim(),
        codigo: _codigoCtrl.text.trim().toUpperCase(),
        zona: _zonaCtrl.text.trim(),
        coachId: _coachId!,
        geolocalizacionActiva: false,
        presupuestoMensual: presupM,
        presupuestoDiario: presupD,
      );
      await DataService.insertVendedor(v);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vendedor registrado correctamente'),
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
        title: const Text('Registrar Vendedor'),
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
              TextFormField(
                controller: _nombreCtrl,
                decoration: _inputDecoration('Nombre completo'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _codigoCtrl,
                decoration: _inputDecoration('Codigo (ej: VEN001)'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _zonaCtrl,
                decoration: _inputDecoration('Zona'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Supervisor>>(
                future: DataService.getSupervisores(),
                builder: (context, snap) {
                  final coaches = (snap.data ?? []).where((s) => s.esCoach).toList();
                  if (coaches.isEmpty) {
                    return Text(
                      'Agregue primero al menos un Coach',
                      style: TextStyle(color: Colors.grey[600]),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: _coachId ?? (coaches.isNotEmpty ? coaches.first.id : null),
                    decoration: _inputDecoration('Coach asignado'),
                    items: coaches
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.nombre} - ${c.zona}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _coachId = v),
                  );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _presupuestoMensualCtrl,
                decoration: _inputDecoration('Presupuesto mensual'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _presupuestoDiarioCtrl,
                decoration: _inputDecoration('Presupuesto diario'),
                keyboardType: TextInputType.number,
              ),
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
