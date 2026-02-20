import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';

class BloquePpvcRvc extends StatelessWidget {
  const BloquePpvcRvc({super.key});

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
                  Icons.compare_arrows,
                  color: AppConstants.azulCorporativo,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'BLOQUE 3 – EJECUCIÓN PPVC vs RVC',
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
              '¿Se está ejecutando lo planeado?',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder(
              future: _calcularMetricas(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final m = snapshot.data!;
                return Column(
                  children: [
                    _Indicador(
                      label: 'Clientes programados vs visitados',
                      valor: '${m['visitados']} / ${m['programados']}',
                      pct: m['pctEjecucion'],
                      meta: AppConstants.metaClientesProgramadosVsVisitados,
                    ),
                    const SizedBox(height: 12),
                    _Indicador(
                      label: 'Coincidencia PPVC-RVC',
                      valor: m['coincidencia'].toStringAsFixed(1),
                      pct: m['pctCoincidencia'],
                      meta: AppConstants.metaCoincidenciaPpvcRvc,
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

  Future<Map<String, dynamic>> _calcularMetricas(BuildContext context) async {
    final hoy = DateTime.now();
    final ppvcList = await DataService.getPpvcByFecha(hoy);
    final rvcList = await DataService.getRvcByFecha(hoy);

    int programados = 0;
    int visitados = 0;
    int coincidencias = 0;
    int total = 0;

    for (final p in ppvcList) {
      programados += p.clientesProgramados;
      final rvcMatch = rvcList.where((rvc) => rvc.vendedorId == p.vendedorId);
      final r = rvcMatch.isEmpty ? null : rvcMatch.first;
      if (r != null) {
        visitados += r.clientesVisitados;
        total++;
        if ((r.clientesVisitados / (p.clientesProgramados > 0 ? p.clientesProgramados : 1)) >= 0.9) {
          coincidencias++;
        }
      }
    }

    final pctEjecucion = programados > 0 ? (visitados / programados) * 100 : 0.0;
    final pctCoincidencia = total > 0 ? (coincidencias / total) * 100 : 0.0;

    return {
      'programados': programados,
      'visitados': visitados,
      'pctEjecucion': pctEjecucion,
      'pctCoincidencia': pctCoincidencia,
      'coincidencia': pctCoincidencia,
    };
  }
}

class _Indicador extends StatelessWidget {
  final String label;
  final String valor;
  final double pct;
  final double meta;

  const _Indicador({
    required this.label,
    required this.valor,
    required this.pct,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final cumple = pct >= meta;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cumple ? AppConstants.verdeMeta : AppConstants.rojoCritico,
          ),
        ),
        Text(
          '(Meta: ${meta.toStringAsFixed(0)}%)',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
