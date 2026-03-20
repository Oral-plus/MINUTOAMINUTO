import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

import '../widgets/bloque_alertas.dart';
import '../widgets/bloque_contactos_cartera.dart';
import '../widgets/bloque_control_jerarquico.dart';
import '../widgets/bloque_disciplina.dart';
import '../widgets/bloque_ppvc_rvc.dart';
import '../widgets/bloque_ranking.dart';
import '../widgets/bloque_vendedores_sap.dart';
import '../widgets/bloque_equipo_jerarquico.dart';

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
      backgroundColor: context.ac.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/LOGO 2 1 (2).png',
              height: 42,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.schedule_rounded, color: context.ac.fg.withOpacity(0.7)),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'MINUTO A MINUTO',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.ac.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: context.ac.bg,
        foregroundColor: context.ac.fg,
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
                SizedBox(height: 12),
                _DashboardHeader(
                  nombre: nombre,
                  totalLlamadas: totalLlamadas,
                  totalAlertas: totalAlertas,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icono: Icons.call_rounded,
                        titulo: 'Llamadas',
                        valor: '$totalLlamadas',
                        color: context.ac.fg,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icono: Icons.warning_amber_rounded,
                        titulo: 'Alertas',
                        valor: '$totalAlertas',
                        color: totalAlertas == 0
                            ? context.ac.fgSubtle
                            : context.ac.fg,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icono: Icons.shield_rounded,
                        titulo: 'Monitor',
                        valor: monitorActivo ? 'Activo' : 'Inactivo',
                        color: monitorActivo
                            ? context.ac.fg
                            : context.ac.fgSubtle,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                const BloqueDisciplina(),
                SizedBox(height: 16),
                const BloquePpvcRvc(),
                SizedBox(height: 16),
                const BloqueEquipoJerarquico(),
                SizedBox(height: 16),
                const BloqueControlJerarquico(),
                SizedBox(height: 16),
                const BloqueAlertas(),
                SizedBox(height: 16),
                const BloqueVendedoresSap(),
                SizedBox(height: 16),
                const BloqueContactosCartera(),
                SizedBox(height: 16),
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
          SizedBox(width: 12),
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
    final ac = context.ac;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ac.surfaceAlt,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ac.fg.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: context.ac.fg.withOpacity(context.isDark ? 0.5 : 0.1),
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
              color: ac.fg.withOpacity(0.03),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PANEL DE CONTROL',
                style: TextStyle(
                  color: ac.fg.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 10),
              Text(
                nombre,
                style: TextStyle(
                  color: ac.fg,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  _HeaderChip(
                    icon: Icons.call_rounded,
                    label: '$totalLlamadas Llamadas',
                  ),
                  SizedBox(width: 8),
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
    final fg = context.ac.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? fg).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (color ?? fg).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? fg.withOpacity(0.5)),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color ?? fg.withOpacity(0.8),
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
    final ac = context.ac;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ac.fg.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: context.ac.fg.withOpacity(0.15),
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
              color: ac.fg.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 16, color: ac.fg.withOpacity(0.6)),
          ),
          SizedBox(height: 16),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ac.fg,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 2),
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: ac.fg.withOpacity(0.25),
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
              Icon(Icons.battery_alert_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Expanded(
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
                      style: TextStyle(fontSize: 10, color: context.ac.fg.withOpacity(0.7)),
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
                child: Text(
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

