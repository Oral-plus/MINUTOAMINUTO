import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/call_diagnostic_service.dart';

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




  Future<void> _mostrarDialogoMiNumero(
    BuildContext context,
    AppProvider provider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final actual =
        prefs.getString('numero_telefono_propietario') ??
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si ambos tienen la app, cuando llamen entre sí cada uno graba solo su propio audio. '
              'El sistema une ambos audios en un solo registro.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
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
            provider.usuarioActual?.nombre ??
            provider.vendedorActual?.nombre ??
            'Usuario';
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
                // Oral-Plus logo directo
                Image.asset(
                  'assets/images/LOGO 2 1 (2).png',
                  height: 30,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.schedule_rounded, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MINUTO A MINUTO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.black,
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
                icon: const Icon(Icons.analytics_outlined),
                tooltip: 'Diagnóstico de llamadas',
                onPressed: () => CallDiagnosticService.showPanel(context),
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
          backgroundColor: const Color(0xFF0D0D0D),
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
                const SizedBox(height: 10),
                const SizedBox(height: 6),
                Text(
                  'Accesos rápidos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 2,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(
              isSupervisor ? Icons.badge_rounded : Icons.person_rounded,
              color: Colors.white70,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SESIÓN ACTIVA',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cargo.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: activo
            ? const Color(0xFF1A2A1A)
            : const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: activo
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activo ? Icons.shield_rounded : Icons.shield_outlined,
              color: activo ? Colors.white70 : Colors.white24,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              activo
                  ? 'Monitor activo: grabando y registrando llamadas automáticamente.'
                  : 'Monitor iniciando... las llamadas se grabarán en breve.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: activo ? Colors.white70 : Colors.white30,
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
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white10,
        highlightColor: Colors.white.withOpacity(0.04),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Icon(item.icono, color: Colors.white70, size: 22),
              ),
              const Spacer(),
              Text(
                item.titulo.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitulo,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.25),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
