import 'package:uuid/uuid.dart';
import '../models/alerta.dart';
import '../models/tipo_llamada.dart';
import 'data_service.dart';
import '../utils/constants.dart';

class AlertasService {
  static const _uuid = Uuid();

  /// Verifica y genera alertas según reglas del negocio
  static Future<void> verificarAlertasDiarias() async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    // Si a las 12m no hay registro de llamada → alerta
    if (ahora.hour >= AppConstants.horaAlertaSinLlamada) {
      await _alertaSinLlamadaManana(hoy);
    }

    // Si a las 5 pm no hay cierre → alerta a KAM
    if (ahora.hour >= AppConstants.horaAlertaSinCierre) {
      await _alertaSinCierreTarde(hoy);
    }

    // Coach no cumple 2 días
    await _alertaCoachNoCumple2Dias();
  }

  static Future<void> _alertaSinLlamadaManana(DateTime hoy) async {
    final vendedores = await DataService.getVendedores();
    final llamadas = await DataService.getRegistroLlamadas(
      desde: hoy,
      hasta: hoy,
    );
    final contactados = llamadas
        .where((l) => l.tipoLlamada == TipoLlamada.manana)
        .map((l) => l.nombreContactado)
        .toSet();

    for (final v in vendedores) {
      if (!contactados.contains(v.nombre)) {
        // Verificar si ya existe alerta
        final alertas = await DataService.getAlertasPendientes();
        final yaExiste = alertas.any((a) =>
            a.tipo == TipoAlerta.sinLlamada12m &&
            a.vendedorId == v.id &&
            a.fecha.year == hoy.year &&
            a.fecha.month == hoy.month &&
            a.fecha.day == hoy.day);
        if (!yaExiste) {
          await DataService.insertAlerta(Alerta(
            id: _uuid.v4(),
            tipo: TipoAlerta.sinLlamada12m,
            fecha: DateTime.now(),
            mensaje: 'Sin registro de llamada matutina para ${v.nombre}',
            vendedorId: v.id,
            zona: v.zona,
          ));
        }
      }
    }
  }

  static Future<void> _alertaSinCierreTarde(DateTime hoy) async {
    final coaches = (await DataService.getSupervisores())
        .where((s) => s.cargo.name == 'coach')
        .toList();
    final llamadas = await DataService.getRegistroLlamadas(
      desde: hoy,
      hasta: hoy,
    );
    final contactadosTarde = llamadas
        .where((l) => l.tipoLlamada == TipoLlamada.tarde)
        .map((l) => l.nombreLider)
        .toSet();

    for (final c in coaches) {
      if (!contactadosTarde.contains(c.nombre)) {
        final alertas = await DataService.getAlertasPendientes();
        final yaExiste = alertas.any((a) =>
            a.tipo == TipoAlerta.sinCierre5pm &&
            a.supervisorId == c.id &&
            a.fecha.year == hoy.year &&
            a.fecha.month == hoy.month &&
            a.fecha.day == hoy.day);
        if (!yaExiste) {
          await DataService.insertAlerta(Alerta(
            id: _uuid.v4(),
            tipo: TipoAlerta.sinCierre5pm,
            fecha: DateTime.now(),
            mensaje: 'Coach ${c.nombre} sin cierre de llamada tarde',
            supervisorId: c.id,
            zona: c.zona,
          ));
        }
      }
    }
  }

  static Future<void> _alertaCoachNoCumple2Dias() async {
    // Simplificado: verificar últimos 2 días
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final anteayer = DateTime.now().subtract(const Duration(days: 2));

    final coaches = (await DataService.getSupervisores())
        .where((s) => s.cargo.name == 'coach')
        .toList();

    for (final c in coaches) {
      final llamadasAyer = await DataService.getRegistroLlamadas(
        desde: ayer,
        hasta: ayer,
      );
      final llamadasAnteayer = await DataService.getRegistroLlamadas(
        desde: anteayer,
        hasta: anteayer,
      );

      final cumpleAyer = llamadasAyer
          .where((l) => l.nombreLider == c.nombre && l.duracionMinutos >= 2)
          .length;
      final cumpleAnteayer = llamadasAnteayer
          .where((l) => l.nombreLider == c.nombre && l.duracionMinutos >= 2)
          .length;

      if (cumpleAyer < 2 && cumpleAnteayer < 2) {
        final alertas = await DataService.getAlertasPendientes();
        final yaExiste = alertas.any((a) =>
            a.tipo == TipoAlerta.coachNoCumple2Dias &&
            a.supervisorId == c.id);
        if (!yaExiste) {
          await DataService.insertAlerta(Alerta(
            id: _uuid.v4(),
            tipo: TipoAlerta.coachNoCumple2Dias,
            fecha: DateTime.now(),
            mensaje: 'Coach ${c.nombre} no cumple llamadas 2 días consecutivos',
            supervisorId: c.id,
            zona: c.zona,
          ));
        }
      }
    }
  }
}
