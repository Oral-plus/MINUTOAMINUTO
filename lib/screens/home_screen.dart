import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_loading_screen.dart';
import 'admin_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'mis_llamadas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.usuarioActual == null && provider.vendedorActual == null) {
          return const AppLoadingScreen();
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
            color: AppConstants.azulCorporativo,
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
            color: const Color(0xFF1E3A8A),
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
              color: const Color(0xFF0F766E),
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
                    color: AppConstants.azulCorporativo,
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
            foregroundColor: const Color(0xFF111827),
            actions: [
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
          backgroundColor: const Color(0xFFF4F6FB),
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
                _MonitorStatusBadge(activo: provider.monitorLlamadasActivo),
                const SizedBox(height: 16),
                const Text(
                  'Accesos rápidos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
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
          colors: [Color(0xFF102A5C), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
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
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo
              ? AppConstants.verdeMeta.withValues(alpha: 0.3)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            activo ? Icons.shield_rounded : Icons.shield_outlined,
            color: activo ? AppConstants.verdeMeta : const Color(0xFFEF4444),
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
                    ? const Color(0xFF065F46)
                    : const Color(0xFF991B1B),
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
