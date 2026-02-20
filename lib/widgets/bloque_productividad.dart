import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class BloqueProductividad extends StatelessWidget {
  const BloqueProductividad({super.key});

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
                  Icons.trending_up,
                  color: AppConstants.verdeMeta,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'BLOQUE 2 – PRODUCTIVIDAD DEL DÍA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '¿Estamos produciendo?',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: context.read<AppProvider>().obtenerMetricasProductividad(),
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
                final ventaTotal = m['ventaTotal'] as double;
                final recaudoTotal = m['recaudoTotal'] as double;
                final clientesVisitados = m['clientesVisitados'] as int;
                final clientesProgramados = m['clientesProgramados'] as int;
                final pctPresup = m['porcentajePresupuesto'] as double;
                final ticketPromedio = m['ticketPromedio'] as double;

                return Column(
                  children: [
                    _Metrica(
                      label: 'Venta acumulada del día',
                      valor: '\$${NumberFormat('#,##0').format(ventaTotal)}',
                      color: AppConstants.verdeMeta,
                    ),
                    const SizedBox(height: 12),
                    _Metrica(
                      label: '% Presupuesto diario cumplido',
                      valor: '${pctPresup.toStringAsFixed(1)}%',
                      color: pctPresup >= 100
                          ? AppConstants.verdeMeta
                          : pctPresup >= 80
                              ? AppConstants.amarilloAdvertencia
                              : AppConstants.rojoCritico,
                    ),
                    const SizedBox(height: 12),
                    _Metrica(
                      label: 'Recaudo del día',
                      valor: '\$${NumberFormat('#,##0').format(recaudoTotal)}',
                      color: AppConstants.azulCorporativo,
                    ),
                    const SizedBox(height: 12),
                    _Metrica(
                      label: 'Ticket promedio',
                      valor: '\$${NumberFormat('#,##0').format(ticketPromedio)}',
                    ),
                    const SizedBox(height: 12),
                    _Metrica(
                      label: 'Clientes visitados vs programados',
                      valor:
                          '$clientesVisitados / $clientesProgramados',
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

class _Metrica extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;

  const _Metrica({
    required this.label,
    required this.valor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
