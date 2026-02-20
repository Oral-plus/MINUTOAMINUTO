import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/vendedor.dart';
import '../utils/constants.dart';

class BloqueRanking extends StatelessWidget {
  const BloqueRanking({super.key});

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
                  Icons.emoji_events,
                  color: AppConstants.amarilloAdvertencia,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'BLOQUE 6 – RANKING DIARIO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: context.read<AppProvider>().obtenerRankingVendedores(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final ranking = snapshot.data!;

                if (ranking.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Sin datos de ventas hoy',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top 5 Vendedores',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...ranking.take(5).toList().asMap().entries.map((e) {
                      final i = e.key;
                      final r = e.value;
                      final v = r['vendedor'] as Vendedor;
                      final venta = r['venta'] as double;
                      final pct = r['pctPresupuesto'] as double;
                      return _RankingItem(
                        posicion: i + 1,
                        nombre: v.nombre,
                        venta: venta,
                        pctPresupuesto: pct,
                        esTop: true,
                      );
                    }),
                    const SizedBox(height: 24),
                    const Text(
                      'Bottom 5',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(() {
                      final start = ranking.length > 5 ? ranking.length - 5 : 0;
                      final bottom = ranking.sublist(start).reversed.toList();
                      return bottom.asMap().entries.map((e) {
                        final r = e.value;
                        final v = r['vendedor'] as Vendedor;
                        final venta = r['venta'] as double;
                        final pct = r['pctPresupuesto'] as double;
                        final pos = start + bottom.length - e.key;
                        return _RankingItem(
                          posicion: pos,
                          nombre: v.nombre,
                          venta: venta,
                          pctPresupuesto: pct,
                          esTop: false,
                        );
                      });
                    })(),
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

class _RankingItem extends StatelessWidget {
  final int posicion;
  final String nombre;
  final double venta;
  final double pctPresupuesto;
  final bool esTop;

  const _RankingItem({
    required this.posicion,
    required this.nombre,
    required this.venta,
    required this.pctPresupuesto,
    required this.esTop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esTop
            ? AppConstants.verdeMeta.withOpacity(0.1)
            : AppConstants.rojoCritico.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: esTop
              ? AppConstants.verdeMeta.withOpacity(0.3)
              : AppConstants.rojoCritico.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: esTop
                  ? AppConstants.verdeMeta
                  : AppConstants.rojoCritico.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$posicion',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Venta: \$${NumberFormat('#,##0').format(venta)} | ${pctPresupuesto.toStringAsFixed(1)}% presup.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
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
