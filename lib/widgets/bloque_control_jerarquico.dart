import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class BloqueControlJerarquico extends StatelessWidget {
  const BloqueControlJerarquico({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.supervisor_account,
                  color: AppConstants.azulCorporativo,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Control jerárquico',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '¿Los líderes están liderando?',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                return Column(
                  children: [
                    _NivelControl(
                      titulo: 'Coach',
                      descripcion: '% llamadas realizadas | % equipo cumplimiento > 90%',
                      pct: provider.porcentajeLlamadasCoach,
                    ),
                    const SizedBox(height: 16),
                    _NivelControl(
                      titulo: 'KAM',
                      descripcion: '% revisiones PPVC | % revisiones RVC | Alertas abiertas',
                      pct: provider.porcentajeLlamadasCoach,
                    ),
                    const SizedBox(height: 16),
                    _NivelControl(
                      titulo: 'Jefe de Ventas',
                      descripcion: '% supervisores auditados | Consolidado disciplina',
                      pct: provider.porcentajeLlamadasCoach,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NivelControl extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final double pct;

  const _NivelControl({
    required this.titulo,
    required this.descripcion,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final color = pct >= 90
        ? AppConstants.verdeMeta
        : pct >= 80
            ? AppConstants.amarilloAdvertencia
            : AppConstants.rojoCritico;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
