/// Tipos de llamada según horario y nivel
enum TipoLlamada {
  manana,
  tarde,
  noche,
  kam,
  jefe;

  /// Devuelve el tipo según la hora actual: mañana (6-12), tarde (12-18), noche (18-6)
  static TipoLlamada fromHora([DateTime? hora]) {
    final h = (hora ?? DateTime.now()).hour;
    if (h >= 6 && h < 12) return TipoLlamada.manana;
    if (h >= 12 && h < 18) return TipoLlamada.tarde;
    return TipoLlamada.noche;
  }

  String get displayName {
    switch (this) {
      case TipoLlamada.manana:
        return 'Mañana';
      case TipoLlamada.tarde:
        return 'Tarde';
      case TipoLlamada.noche:
        return 'Noche';
      case TipoLlamada.kam:
        return 'KAM';
      case TipoLlamada.jefe:
        return 'Jefe';
    }
  }

  String get valor => name;

  String get objetivo {
    switch (this) {
      case TipoLlamada.manana:
        return 'Planeación y enfoque';
      case TipoLlamada.tarde:
        return 'Control y cierre';
      case TipoLlamada.noche:
        return 'Seguimiento nocturno';
      case TipoLlamada.kam:
        return 'Cumplimiento equipo, alertas disciplina';
      case TipoLlamada.jefe:
        return 'Enfoque estratégico, productividad';
    }
  }
}
