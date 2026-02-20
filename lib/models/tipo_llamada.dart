/// Tipos de llamada según horario y nivel
enum TipoLlamada {
  manana,
  tarde,
  kam,
  jefe;

  String get displayName {
    switch (this) {
      case TipoLlamada.manana:
        return 'Mañana';
      case TipoLlamada.tarde:
        return 'Tarde';
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
      case TipoLlamada.kam:
        return 'Cumplimiento equipo, alertas disciplina';
      case TipoLlamada.jefe:
        return 'Enfoque estratégico, productividad';
    }
  }
}
