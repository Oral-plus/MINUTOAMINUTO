import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/vendedor.dart';
import '../utils/constants.dart';
import 'app_loading_screen.dart';

class BloqueRanking extends StatelessWidget {
  const BloqueRanking({super.key});

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
                  Icons.emoji_events,
                  color: AppConstants.amarilloAdvertencia,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Ranking diario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: context.read<AppProvider>().obtenerRankingVendedores(),
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
                    Text(
                      'Top 5 Vendedores',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
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
                    SizedBox(height: 24),
                    Text(
                      'Bottom 5',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
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
            ? AppConstants.verdeMeta.withOpacity(0.04)
            : Colors.grey.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esTop
              ? AppConstants.verdeMeta.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
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
              style: TextStyle(
                color: context.ac.fg,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
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
