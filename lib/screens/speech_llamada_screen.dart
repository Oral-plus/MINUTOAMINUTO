import 'package:flutter/material.dart';
import '../models/tipo_llamada.dart';
import '../utils/constants.dart';

/// Pantalla con la estructura de speech sugerida para cada tipo de llamada
class SpeechLlamadaScreen extends StatelessWidget {
  final TipoLlamada tipoLlamada;

  const SpeechLlamadaScreen({
    super.key,
    required this.tipoLlamada,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech - ${tipoLlamada.displayName}'),
        backgroundColor: AppConstants.azulCorporativo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Seccion(
              titulo: 'Objetivo',
              contenido: tipoLlamada.objetivo,
              icono: Icons.flag,
            ),
            const SizedBox(height: 24),
            ..._preguntasParaTipo(tipoLlamada),
            const SizedBox(height: 24),
            _Seccion(
              titulo: 'Cierre',
              contenido: _cierreParaTipo(tipoLlamada),
              icono: Icons.check_circle,
              color: AppConstants.verdeMeta,
            ),
            const SizedBox(height: 16),
            Text(
              'Duración ideal: 3-5 minutos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _preguntasParaTipo(TipoLlamada t) {
    switch (t) {
      case TipoLlamada.manana:
        return [
          const _Pregunta('¿A qué hora iniciaste ruta?'),
          const _Pregunta('¿Cuántos clientes programados hoy?'),
          const _Pregunta('¿Cuántos 60 / Perdidos?'),
          const _Pregunta('¿Meta de venta del día?'),
          const _Pregunta('¿Meta de recaudo?'),
          const _Pregunta('¿Qué cliente es prioridad?'),
          const _Pregunta('¿Qué apoyo necesitas?'),
        ];
      case TipoLlamada.tarde:
        return [
          const _Pregunta('¿Cuántos clientes ejecutados?'),
          const _Pregunta('¿Venta acumulada?'),
          const _Pregunta('¿Recaudo?'),
          const _Pregunta('¿Clientes no visitados?'),
          const _Pregunta('¿Reprogramación?'),
          const _Pregunta('¿Cumpliste presupuesto diario?'),
          const _Pregunta('¿Qué aprendiste hoy?'),
        ];
      case TipoLlamada.kam:
        return [
          const _Pregunta('% cumplimiento equipo'),
          const _Pregunta('Alertas disciplina'),
          const _Pregunta('Apoyo en clientes críticos'),
          const _Pregunta('Conversión 60 y Perdidos'),
        ];
      case TipoLlamada.jefe:
        return [
          const _Pregunta('Productividad'),
          const _Pregunta('Conversión'),
          const _Pregunta('Disciplina del Coach'),
          const _Pregunta('Plan correctivo si bajo desempeño'),
        ];
    }
  }

  String _cierreParaTipo(TipoLlamada t) {
    switch (t) {
      case TipoLlamada.manana:
        return '"Hoy no vamos a cumplir, hoy vamos a superar."';
      case TipoLlamada.tarde:
        return '"Mañana corregimos y escalamos."';
      case TipoLlamada.kam:
      case TipoLlamada.jefe:
        return 'Cierre estratégico según contexto.';
    }
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final String contenido;
  final IconData icono;
  final Color? color;

  const _Seccion({
    required this.titulo,
    required this.contenido,
    required this.icono,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppConstants.azulCorporativo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: c),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              contenido,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pregunta extends StatelessWidget {
  final String texto;

  const _Pregunta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
