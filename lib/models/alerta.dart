enum TipoAlerta {
  sinLlamada12m,
  sinCierre5pm,
  coachNoCumple2Dias,
  vendedorSinVenta2pm,
  vendedorSinRecaudo,
  cliente60NoProgramado,
  clientePerdidoNoImpactado,
  sinVisitasAntes10am,
  sinRvcdiligenciado,
}

class Alerta {
  final String id;
  final TipoAlerta tipo;
  final DateTime fecha;
  final String mensaje;
  final String? vendedorId;
  final String? supervisorId;
  final String zona;
  final bool resuelta;

  Alerta({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.mensaje,
    this.vendedorId,
    this.supervisorId,
    this.zona = '',
    this.resuelta = false,
  });

  String get titulo {
    switch (tipo) {
      case TipoAlerta.sinLlamada12m:
        return 'Sin registro de llamada al mediodía';
      case TipoAlerta.sinCierre5pm:
        return 'Sin cierre a las 5 PM';
      case TipoAlerta.coachNoCumple2Dias:
        return 'Coach no cumple 2 días';
      case TipoAlerta.vendedorSinVenta2pm:
        return 'Vendedor sin venta antes de las 2 PM';
      case TipoAlerta.vendedorSinRecaudo:
        return 'Vendedor sin recaudo';
      case TipoAlerta.cliente60NoProgramado:
        return 'Cliente 60 no programado';
      case TipoAlerta.clientePerdidoNoImpactado:
        return 'Cliente perdido no impactado';
      case TipoAlerta.sinVisitasAntes10am:
        return 'Sin visitas antes de las 10 AM';
      case TipoAlerta.sinRvcdiligenciado:
        return 'Sin RVC diligenciado';
    }
  }
}
