import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/media_projection_service.dart';
import '../utils/constants.dart';
import '../utils/phone_utils.dart';
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
  bool _mediaProjGranted = false;
  bool _mediaProjChecked = false;

  @override
  void initState() {
    super.initState();
    _checkMediaProjection();
  }

  Future<void> _checkMediaProjection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final granted = await MediaProjectionService.checkPermission();
    if (mounted) setState(() { _mediaProjGranted = granted; _mediaProjChecked = true; });
  }

  Future<void> _solicitarMediaProjection() async {
    final granted = await context.read<AppProvider>().solicitarPermisoMediaProjection();
    if (mounted) setState(() => _mediaProjGranted = granted);
    if (granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso concedido. Las llamadas se grabarán con audio completo.'),
          backgroundColor: Color(0xFF065F46),
        ),
      );
    }
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
        title: const Text('Mi número para correlación dual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si ambos tienen la app, cuando llamen entre sí cada uno graba solo su propio audio. '
              'El sistema une ambos audios en un solo registro.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Mi número de teléfono',
                hintText: 'Ej: +57 300 123 4567',
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
                const SizedBox(height: 10),
                // Banner de permiso MediaProjection (solo Android, solo si no está concedido)
                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android &&
                    _mediaProjChecked &&
                    !_mediaProjGranted)
                  _MediaProjectionBanner(onTap: _solicitarMediaProjection),
                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android &&
                    _mediaProjChecked &&
                    !_mediaProjGranted)
                  const SizedBox(height: 10),
                const SizedBox(height: 6),
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

/// Banner que solicita al usuario el permiso de captura de audio del sistema.
class _MediaProjectionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _MediaProjectionBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic_external_on_rounded,
                color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activar grabación de audio completa',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Toca para permitir capturar la voz de ambos lados de la llamada.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD97706), size: 20),
          ],
        ),
      ),
    );
  }
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
