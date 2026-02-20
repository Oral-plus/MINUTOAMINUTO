import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'nueva_llamada_screen.dart';
import 'mis_llamadas_screen.dart';
import 'dashboard_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) => Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 28,
                  width: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.schedule, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Minuto a Minuto', style: TextStyle(fontSize: 18)),
            ],
          ),
          backgroundColor: AppConstants.azulCorporativo,
          foregroundColor: Colors.white,
          actions: [
            if (provider.usuarioActual != null)
              IconButton(
                icon: const Icon(Icons.manage_accounts),
                tooltip: 'Administrar equipo',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ).then((_) => provider.cargarEquipo());
                },
              ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
        body: Consumer<AppProvider>(
          builder: (context, provider, _) {
          if (provider.usuarioActual == null && provider.vendedorActual == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final nombre = provider.usuarioActual?.nombre ??
              provider.vendedorActual?.nombre ??
              'Usuario';
          final cargo = provider.usuarioActual?.cargo.displayName ??
              'Vendedor';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppConstants.azulCorporativo,
                        const Color(0xFF0D47A1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.azulCorporativo.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cargo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (provider.vendedorActual != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                provider.geolocalizacionActiva
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: provider.geolocalizacionActiva
                                    ? Colors.white
                                    : Colors.white70,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                provider.geolocalizacionActiva
                                    ? 'Geolocalización activa'
                                    : 'Geolocalización inactiva',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: provider.geolocalizacionActiva
                                    ? provider.detenerGeolocalizacion
                                    : provider.iniciarGeolocalizacion,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: Text(provider.geolocalizacionActiva ? 'Desactivar' : 'Activar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (provider.usuarioActual != null) ...[
                  _BotonAccion(
                    icono: Icons.add_call,
                    titulo: 'Nueva Llamada',
                    subtitulo: 'Registrar llamada obligatoria',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NuevaLlamadaScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _BotonAccion(
                    icono: Icons.list_alt,
                    titulo: 'Mis Llamadas Hoy',
                    subtitulo: 'Ver registro del día',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisLlamadasScreen(),
                        ),
                      );
                    },
                  ),
                ] else if (provider.vendedorActual != null) ...[
                  _BotonAccion(
                    icono: Icons.list_alt,
                    titulo: 'Mis Llamadas Hoy',
                    subtitulo: 'Llamadas recibidas',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisLlamadasScreen(),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                _BotonAccion(
                  icono: Icons.analytics,
                  titulo: 'Dashboard',
                  subtitulo: 'Ver indicadores en tiempo real',
                  color: AppConstants.azulCorporativo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            );
          },
        ),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final Color? color;

  const _BotonAccion({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppConstants.azulCorporativo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, size: 28, color: c),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
