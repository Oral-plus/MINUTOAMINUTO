import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../utils/kpi_calculator.dart';
import 'semaforo_widget.dart';

class BloqueDisciplina extends StatelessWidget {
  const BloqueDisciplina({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  color: AppConstants.azulCorporativo,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'BLOQUE 1 – DISCIPLINA OPERATIVA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '¿El equipo está cumpliendo el procedimiento?',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                final pctLlamadas = provider.porcentajeLlamadasCoach;
                final pctInicio = provider.porcentajeInicioJornada;
                final pctGeo = provider.porcentajeGeolocalizacion;
                final semaforo = provider.semaforoDisciplina;

                return Column(
                  children: [
                    _IndicadorKPI(
                      label: '% Llamadas Coach realizadas',
                      valor: pctLlamadas,
                      meta: AppConstants.metaLlamadasCoach,
                    ),
                    const SizedBox(height: 12),
                    _IndicadorKPI(
                      label: '% Inicio jornada antes 8:30 am',
                      valor: pctInicio,
                      meta: AppConstants.metaInicioJornada,
                    ),
                    const SizedBox(height: 12),
                    _IndicadorKPI(
                      label: '% Geolocalización activa',
                      valor: pctGeo,
                      meta: AppConstants.metaGeolocalizacion,
                    ),
                    const SizedBox(height: 24),
                    SemaforoWidget(
                      estado: semaforo,
                      label: 'Semáforo general',
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

class _IndicadorKPI extends StatelessWidget {
  final String label;
  final double valor;
  final double meta;

  const _IndicadorKPI({
    required this.label,
    required this.valor,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final cumple = valor >= meta;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Text(
            '${valor.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cumple ? AppConstants.verdeMeta : AppConstants.rojoCritico,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Meta: ${meta.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
