import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../widgets/bloque_alertas.dart';
import '../widgets/bloque_control_jerarquico.dart';
import '../widgets/bloque_disciplina.dart';
import '../widgets/bloque_ppvc_rvc.dart';
import '../widgets/bloque_productividad.dart';
import '../widgets/bloque_ranking.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Dashboard Ejecutivo'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
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
                        color: AppConstants.azulCorporativo,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icono: Icons.warning_amber_rounded,
                        titulo: 'Alertas',
                        valor: '$totalAlertas',
                        color: totalAlertas == 0
                            ? AppConstants.verdeMeta
                            : AppConstants.rojoCritico,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icono: Icons.shield_rounded,
                        titulo: 'Monitor',
                        valor: monitorActivo ? 'Activo' : 'Inactivo',
                        color: monitorActivo
                            ? AppConstants.verdeMeta
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const BloqueDisciplina(),
                const SizedBox(height: 16),
                const BloqueProductividad(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panel de control',
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
          const SizedBox(height: 10),
          Text(
            '$totalLlamadas llamadas registradas y $totalAlertas alertas abiertas',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
