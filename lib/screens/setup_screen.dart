import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_sweetalert_new/art_sweetalert_new.dart';
import '../providers/app_provider.dart';
import '../models/supervisor.dart';
import '../models/vendedor.dart';
import '../models/nivel_cargo.dart';
import '../services/data_service.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'registro_supervisor_screen.dart';
import 'registro_vendedor_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import '../widgets/app_loading_screen.dart';

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
    if (ApiConfig.useRemoteApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificarConexionApi());
    }
  }

  Future<void> _verificarConexionApi() async {
    try {
      final ok = await ApiService.testConnection();
      if (!mounted) return;
      if (ok) {
        await ArtSweetAlert.show(
          context: context,
          title: Text('API conectada'),
          content: Text('La conexión con el servidor está funcionando correctamente.'),
          type: ArtAlertType.success,
        );
      }
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final sp = await DataService.getSupervisores().timeout(
        const Duration(seconds: 20),
        onTimeout: () => <Supervisor>[],
      );
      final vd = await DataService.getVendedores().timeout(
        const Duration(seconds: 20),
        onTimeout: () => <Vendedor>[],
      );
      if (!mounted) return;
      setState(() {
        _supervisores = sp;
        _vendedores = vd;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supervisores = [];
        _vendedores = [];
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const AppLoadingScreen();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF212121),
              Color(0xFF424242),
              Color(0xFF616161),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
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
                                color: context.ac.fg.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings_applications,
                                size: 48,
                                color: context.ac.fg,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Configuración inicial',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: context.ac.fg,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Registre su equipo de ventas para comenzar',
                              style: TextStyle(
                                fontSize: 16,
                                color: context.ac.fg.withOpacity(0.9),
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
                          decoration: BoxDecoration(color: context.ac.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: context.ac.fg.withOpacity(0.12),
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
                                icon: Icon(Icons.login),
                                label: Text('Ir a Inicio de sesión'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.ac.fg,
                                  foregroundColor: context.ac.fg,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminScreen(),
                                  ),
                                ).then((_) => _cargar());
                              },
                              child: Text('Administrar todo'),
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
          color: context.ac.fg.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: context.ac.fg, size: 24),
      ),
      title: Text(
        titulo,
        style: TextStyle(
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
          backgroundColor: context.ac.fg.withOpacity(0.1),
          foregroundColor: context.ac.fg,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(vacio ? 'Agregar' : 'Añadir otro'),
      ),
    );
  }
}
