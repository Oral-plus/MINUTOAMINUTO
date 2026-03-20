import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'admin_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'mis_llamadas_screen.dart';
import '../widgets/active_call_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _mostrarDialogoMiNumero(BuildContext context, AppProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getString('numero_telefono_propietario') ??
        provider.usuarioActual?.telefono ??
        provider.vendedorActual?.telefono ??
        '';
    final ctrl = TextEditingController(text: actual);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Mi número para correlación dual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Si ambos tienen la app, cuando llamen entre sí cada uno graba solo su propio audio. '
                'El sistema une ambos audios en un solo registro.',
                style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Mi número de teléfono',
                  hintText: 'Ej: 300 123 4567',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () async {
              final num = ctrl.text.trim();
              if (num.isEmpty) {
                await prefs.remove('numero_telefono_propietario');
              } else {
                await prefs.setString('numero_telefono_propietario', num);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.azulCorporativo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.usuarioActual == null && provider.vendedorActual == null) {
          return const LoginScreen();
        }

        final nombre =
            provider.usuarioActual?.nombre ?? provider.vendedorActual?.nombre ?? 'Usuario';
        final cargo = provider.usuarioActual?.cargo.displayName ?? 'Vendedor';
        final isSupervisor = provider.usuarioActual != null;
        final acciones = <_AccionHome>[
          _AccionHome(
            icono: Icons.call_rounded,
            titulo: 'Mis llamadas',
            subtitulo: 'Ver registro del día',
            color: Colors.black,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MisLlamadasScreen()),
              );
            },
          ),
          _AccionHome(
            icono: Icons.insights_rounded,
            titulo: 'Dashboard',
            subtitulo: 'Indicadores en vivo',
            color: Colors.black,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
          ),
          if (isSupervisor)
            _AccionHome(
              icono: Icons.manage_accounts_rounded,
              titulo: 'Administración',
              subtitulo: 'Equipo comercial',
              color: Colors.black,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                ).then((_) => provider.cargarEquipo());
              },
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 38,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.schedule_rounded,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Minuto a Minuto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.phone_android_rounded),
                tooltip: 'Mi número para correlación dual',
                onPressed: () => _mostrarDialogoMiNumero(context, provider),
              ),
              if (isSupervisor)
                IconButton(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  tooltip: 'Administrar equipo',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    ).then((_) => provider.cargarEquipo());
                  },
                ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await context.read<AppProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF5F5F5),
          body: RefreshIndicator(
            onRefresh: () async {
              await provider.cargarDatosHoy();
              await provider.cargarEquipo();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _HomeHeaderCard(
                  nombre: nombre,
                  cargo: cargo,
                  isSupervisor: isSupervisor,
                ),
                const SizedBox(height: 16),
                const ActiveCallIndicator(),
                _MonitorStatusBadge(activo: provider.monitorLlamadasActivo),
                const SizedBox(height: 10),
                const SizedBox(height: 6),
                const Text(
                  'Accesos rápidos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: acciones.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (_, i) => _AccionTile(item: acciones[i]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeaderCard extends StatelessWidget {
  final String nombre;
  final String cargo;
  final bool isSupervisor;

  const _HomeHeaderCard({
    required this.nombre,
    required this.cargo,
    required this.isSupervisor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black87, Colors.black54],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSupervisor ? Icons.badge_rounded : Icons.person_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sesión activa',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cargo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitorStatusBadge extends StatelessWidget {
  final bool activo;

  const _MonitorStatusBadge({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: activo
            ? AppConstants.verdeMeta.withValues(alpha: 0.08)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo
              ? Colors.black54
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            activo ? Icons.shield_rounded : Icons.shield_outlined,
            color: activo ? Colors.black87 : Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              activo
                  ? 'Monitor activo: grabando y registrando llamadas automáticamente.'
                  : 'Monitor iniciando... las llamadas se grabarán en breve.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: activo
                    ? Colors.black87
                    : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccionHome {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  _AccionHome({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });
}

class _AccionTile extends StatelessWidget {
  final _AccionHome item;

  const _AccionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icono, color: item.color, size: 20),
              ),
              const Spacer(),
              Text(
                item.titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitulo,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
