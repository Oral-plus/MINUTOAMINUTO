import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../models/nivel_cargo.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';
import 'registro_supervisor_screen.dart';
import 'registro_vendedor_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';

/// Pantalla de configuración inicial cuando no hay datos.
/// Permite registrar Jefe, KAM, Coaches y Vendedores.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  List<Supervisor> _supervisores = [];
  List<Vendedor> _vendedores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final sp = await DataService.getSupervisores();
    final vd = await DataService.getVendedores();
    setState(() {
      _supervisores = sp;
      _vendedores = vd;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.settings_applications,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Configuración inicial',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Registre su equipo de ventas para comenzar',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _TarjetaRegistro(
                                icono: Icons.person_outline,
                                titulo: 'Jefe de Ventas',
                                subtitulo: _supervisores
                                    .where((s) => s.esJefe)
                                    .map((s) => s.nombre)
                                    .join(', '),
                                vacio: _supervisores.where((s) => s.esJefe).isEmpty,
                                onAgregar: () => _agregarSupervisor(NivelCargo.jefe),
                              ),
                              const Divider(height: 1),
                              _TarjetaRegistro(
                                icono: Icons.badge_outlined,
                                titulo: 'KAM',
                                subtitulo: _supervisores
                                    .where((s) => s.esKam)
                                    .map((s) => s.nombre)
                                    .join(', '),
                                vacio: _supervisores.where((s) => s.esKam).isEmpty,
                                onAgregar: () => _agregarSupervisor(NivelCargo.kam),
                              ),
                              const Divider(height: 1),
                              _TarjetaRegistro(
                                icono: Icons.groups_outlined,
                                titulo: 'Coaches',
                                subtitulo: '${_supervisores.where((s) => s.esCoach).length} registrados',
                                vacio: _supervisores.where((s) => s.esCoach).isEmpty,
                                onAgregar: () => _agregarSupervisor(NivelCargo.coach),
                              ),
                              const Divider(height: 1),
                              _TarjetaRegistro(
                                icono: Icons.storefront_outlined,
                                titulo: 'Vendedores',
                                subtitulo: '${_vendedores.length} registrados',
                                vacio: _vendedores.isEmpty,
                                onAgregar: _agregarVendedor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _supervisores.isEmpty
                                    ? null
                                    : () {
                                        context.read<AppProvider>().cargarEquipo();
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.login),
                                label: const Text('Ir a Inicio de sesión'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppConstants.azulCorporativo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminScreen(),
                                  ),
                                ).then((_) => _cargar());
                              },
                              child: const Text('Administrar todo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _agregarSupervisor(NivelCargo cargo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroSupervisorScreen(cargoInicial: cargo),
      ),
    );
    _cargar();
  }

  Future<void> _agregarVendedor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistroVendedorScreen(),
      ),
    );
    _cargar();
  }
}

class _TarjetaRegistro extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool vacio;
  final VoidCallback onAgregar;

  const _TarjetaRegistro({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.vacio,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppConstants.azulCorporativo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: AppConstants.azulCorporativo, size: 24),
      ),
      title: Text(
        titulo,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        vacio ? 'Sin registrar' : subtitulo,
        style: TextStyle(
          color: vacio ? Colors.grey : Colors.grey[700],
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton.tonal(
        onPressed: onAgregar,
        style: FilledButton.styleFrom(
          backgroundColor: AppConstants.azulCorporativo.withOpacity(0.15),
          foregroundColor: AppConstants.azulCorporativo,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(vacio ? 'Agregar' : 'Añadir otro'),
      ),
    );
  }
}
