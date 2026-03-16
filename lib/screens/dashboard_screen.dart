import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

import '../widgets/bloque_alertas.dart';
import '../widgets/bloque_control_jerarquico.dart';
import '../widgets/bloque_disciplina.dart';
import '../widgets/bloque_ppvc_rvc.dart';
import '../widgets/bloque_ranking.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().recargarDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().recargarDashboard(),
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final totalLlamadas = provider.llamadas.length;
            final totalAlertas = provider.alertas.length;
            final monitorActivo = provider.monitorLlamadasActivo;
            final nombre =
                provider.usuarioActual?.nombre ?? provider.vendedorActual?.nombre ?? 'Usuario';

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _DemoBanner(provider: provider),
                const _BatteryShieldBanner(),
                const SizedBox(height: 12),
                _DashboardHeader(
                  nombre: nombre,
                  totalLlamadas: totalLlamadas,
                  totalAlertas: totalAlertas,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icono: Icons.call_rounded,
                        titulo: 'Llamadas',
                        valor: '$totalLlamadas',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icono: Icons.warning_amber_rounded,
                        titulo: 'Alertas',
                        valor: '$totalAlertas',
                        color: totalAlertas == 0
                            ? Colors.black54
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icono: Icons.shield_rounded,
                        titulo: 'Monitor',
                        valor: monitorActivo ? 'Activo' : 'Inactivo',
                        color: monitorActivo
                            ? Colors.black87
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const BloqueDisciplina(),
                const SizedBox(height: 16),
                const BloquePpvcRvc(),
                const SizedBox(height: 16),
                const BloqueControlJerarquico(),
                const SizedBox(height: 16),
                const BloqueAlertas(),
                const SizedBox(height: 16),
                const BloqueRanking(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  final AppProvider provider;

  const _DemoBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final enDemo = provider.modoDemoActivo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enDemo ? const Color(0xFF1A1500) : const Color(0xFF0A1520),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enDemo ? Colors.amber.withOpacity(0.3) : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enDemo ? Icons.science_rounded : Icons.rocket_launch_rounded,
            color: enDemo ? Colors.amber : Colors.blue.shade300,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              enDemo
                  ? 'Modo demo activo — datos de prueba'
                  : '¿Presentación? Carga datos demo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enDemo ? Colors.amber.shade300 : Colors.blue.shade300,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (enDemo) {
                await provider.salirModoDemo();
              } else {
                await provider.cargarDatosDemo();
              }
            },
            child: Text(
              enDemo ? 'Salir' : 'Cargar',
              style: TextStyle(
                color: enDemo ? Colors.amber : Colors.blue.shade300,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String nombre;
  final int totalLlamadas;
  final int totalAlertas;

  const _DashboardHeader({
    required this.nombre,
    required this.totalLlamadas,
    required this.totalAlertas,
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
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.analytics_outlined,
              size: 100,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PANEL DE CONTROL',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeaderChip(
                    icon: Icons.call_rounded,
                    label: '$totalLlamadas Llamadas',
                  ),
                  const SizedBox(width: 8),
                  _HeaderChip(
                    icon: Icons.notifications_active_rounded,
                    label: '$totalAlertas Alertas',
                    color: totalAlertas > 0 ? Colors.amber : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _HeaderChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (color ?? Colors.white).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.white.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final Color color;

  const _StatCard({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 16, color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.25),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryShieldBanner extends StatelessWidget {
  const _BatteryShieldBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.batteryOptimizationDisabled) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.battery_alert_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optimización de Batería Activa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    Text(
                      'Android puede cerrar el monitor. Toca "Blindar" y elige "Sin Restricción".',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => provider.solicitarIgnorarBateria(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Blindar',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

