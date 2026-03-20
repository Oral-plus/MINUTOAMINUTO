import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';
import 'app_loading_screen.dart';

class BloquePpvcRvc extends StatelessWidget {
  const BloquePpvcRvc({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.ac.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: context.ac.fg.withOpacity(0.03),
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
                  Icons.compare_arrows,
                  color: AppConstants.azulCorporativo,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ejecución PPVC vs RVC',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '¿Se está ejecutando lo planeado?',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            FutureBuilder(
              future: _calcularMetricas(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: AppLoadingIndicator(
                      logoHeight: 84,
                      dotSize: 8,
                      showMessage: false,
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
                    SizedBox(height: 12),
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
            style: TextStyle(fontSize: 14),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        SizedBox(width: 8),
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
