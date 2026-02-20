import '../models/nivel_cargo.dart';
import 'package:sqflite/sqflite.dart';

/// Datos de prueba según el marco: 50 vendedores, 7 coaches, 1 KAM, 1 Jefe
class SeedData {
  static Future<void> seed(Database db) async {
    // 1 Jefe
    await db.insert('supervisores', {
      'id': 'jefe_1',
      'nombre': 'Carlos Jefe Ventas',
      'codigo': 'JEF001',
      'zona': 'Nacional',
      'cargo': NivelCargo.jefe.valor,
      'superiorId': null,
      'subordinadosIds': 'kam_1',
    });

    // 1 KAM
    await db.insert('supervisores', {
      'id': 'kam_1',
      'nombre': 'Ana KAM',
      'codigo': 'KAM001',
      'zona': 'Nacional',
      'cargo': NivelCargo.kam.valor,
      'superiorId': 'jefe_1',
      'subordinadosIds': 'coach_1,coach_2,coach_3,coach_4,coach_5,coach_6,coach_7',
    });

    // 7 Coaches
    final coaches = [
      'coach_1',
      'coach_2',
      'coach_3',
      'coach_4',
      'coach_5',
      'coach_6',
      'coach_7',
    ];
    final zonas = ['Norte', 'Sur', 'Centro', 'Oriente', 'Occidente', 'Metro', 'Rural'];
    for (var i = 0; i < 7; i++) {
      final count = i < 6 ? 8 : 2; // 6 coaches x 8 + 1 coach x 2 = 50
      final sub = List.generate(count, (j) => 'vendedor_${i * 8 + j + 1}')
          .join(',');
      await db.insert('supervisores', {
        'id': coaches[i],
        'nombre': 'Coach ${i + 1}',
        'codigo': 'COA${(i + 1).toString().padLeft(3, '0')}',
        'zona': zonas[i % zonas.length],
        'cargo': NivelCargo.coach.valor,
        'superiorId': 'kam_1',
        'subordinadosIds': sub,
      });
    }

    // 50 Vendedores
    for (var i = 1; i <= 50; i++) {
      final coachIdx = ((i - 1) / 8).floor();
      await db.insert('vendedores', {
        'id': 'vendedor_$i',
        'nombre': 'Vendedor $i',
        'codigo': 'VEN${i.toString().padLeft(3, '0')}',
        'zona': zonas[coachIdx % zonas.length],
        'coachId': coaches[coachIdx],
        'geolocalizacionActiva': 1,
        'horaInicioJornada': null,
        'presupuestoMensual': 10000000 + (i * 100000),
        'presupuestoDiario': 450000 + (i * 5000),
      });
    }

    // PPVC y RVC de hoy para algunos vendedores
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    for (var i = 1; i <= 10; i++) {
      await db.insert('ppvc', {
        'id': 'ppvc_$i',
        'vendedorId': 'vendedor_$i',
        'fecha': hoy,
        'zona': zonas[i % zonas.length],
        'clientesProgramados': 8 + (i % 5),
        'clientes60Ids': 'c60_1,c60_2',
        'clientesPerdidosIds': 'cp_1',
        'metaVenta': 500000 + (i * 10000),
        'metaRecaudo': 300000 + (i * 8000),
        'programado2DiasAntes': 1,
      });
      await db.insert('rvc', {
        'id': 'rvc_$i',
        'vendedorId': 'vendedor_$i',
        'fecha': hoy,
        'zona': zonas[i % zonas.length],
        'clientesVisitados': 5 + (i % 4),
        'clientes60Visitados': 2,
        'clientesPerdidosVisitados': 1,
        'ventaTotal': 350000 + (i * 8000),
        'recaudoTotal': 200000 + (i * 5000),
        'clientesNoVisitados': '',
        'descuentosAplicados': 1,
      });
    }
  }
}
