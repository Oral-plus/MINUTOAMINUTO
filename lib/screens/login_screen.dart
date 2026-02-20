import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _esSupervisor = true;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 90,
                      width: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.schedule,
                        size: 80,
                        color: AppConstants.azulCorporativo,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'MINUTO A MINUTO',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seguimiento PPVC y RVC',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => SizedBox(
                            width: constraints.maxWidth,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(value: true, label: Text('Supervisor'), icon: Icon(Icons.supervisor_account)),
                                  ButtonSegment(value: false, label: Text('Vendedor'), icon: Icon(Icons.person)),
                                ],
                                selected: {_esSupervisor},
                                onSelectionChanged: (v) {
                                  setState(() {
                                    _esSupervisor = v.first;
                                    _selectedId = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _esSupervisor
                            ? _SelectorSupervisor(
                                onSelected: (id) =>
                                    setState(() => _selectedId = id),
                                selectedId: _selectedId,
                              )
                            : _SelectorVendedor(
                                onSelected: (id) =>
                                    setState(() => _selectedId = id),
                                selectedId: _selectedId,
                              ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _selectedId == null
                              ? null
                              : () => _login(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppConstants.azulCorporativo,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Ingresar'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const SetupScreen()),
                            );
                          },
                          child: const Text('Configurar equipo'),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context) async {
    if (_selectedId == null) return;
    final provider = context.read<AppProvider>();
    if (_esSupervisor) {
      await provider.loginSupervisor(_selectedId!);
    } else {
      await provider.loginVendedor(_selectedId!);
    }
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }
}

class _SelectorSupervisor extends StatelessWidget {
  final void Function(String) onSelected;
  final String? selectedId;

  const _SelectorSupervisor({
    required this.onSelected,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Supervisor>>(
      future: DataService.getSupervisores(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final list = snapshot.data!;
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No hay supervisores. Use "Configurar equipo" para agregar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: selectedId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Seleccione supervisor',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          items: list.map((s) => DropdownMenuItem(
            value: s.id,
            child: Text('${s.nombre} (${s.cargo.displayName})', overflow: TextOverflow.ellipsis, maxLines: 1),
          )).toList(),
          onChanged: (v) => onSelected(v ?? ''),
        );
      },
    );
  }
}

class _SelectorVendedor extends StatelessWidget {
  final void Function(String) onSelected;
  final String? selectedId;

  const _SelectorVendedor({
    required this.onSelected,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Vendedor>>(
      future: DataService.getVendedores(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final list = snapshot.data!;
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No hay vendedores. Use "Configurar equipo" para agregar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: selectedId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Seleccione vendedor',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          items: list.map((v) => DropdownMenuItem(
            value: v.id,
            child: Text('${v.nombre} - ${v.zona}', overflow: TextOverflow.ellipsis, maxLines: 1),
          )).toList(),
          onChanged: (v) => onSelected(v ?? ''),
        );
      },
    );
  }
}
