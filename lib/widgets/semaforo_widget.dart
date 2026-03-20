import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SemaforoWidget extends StatelessWidget {
  /// 0 = Verde, 1 = Amarillo, 2 = Rojo
  final int estado;
  final String label;

  const SemaforoWidget({
    super.key,
    required this.estado,
    this.label = 'Estado',
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String texto;
    IconData icono;
    switch (estado) {
      case 0:
        color = AppConstants.semaforoVerde;
        texto = 'Cumple llamadas';
        icono = Icons.check_circle;
        break;
      case 1:
        color = AppConstants.semaforoAmarillo;
        texto = 'Cumple 1 de 2';
        icono = Icons.warning;
        break;
      case 2:
        color = AppConstants.semaforoRojo;
        texto = 'No cumple';
        icono = Icons.error;
        break;
      default:
        color = Colors.grey;
        texto = 'Sin datos';
        icono = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
