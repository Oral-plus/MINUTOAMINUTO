/// Niveles jerárquicos del proceso Minuto a Minuto
enum NivelCargo {
  vendedor,
  coach,
  kam,
  jefe;

  String get displayName {
    switch (this) {
      case NivelCargo.vendedor:
        return 'Vendedor';
      case NivelCargo.coach:
        return 'Coach';
      case NivelCargo.kam:
        return 'KAM';
      case NivelCargo.jefe:
        return 'Jefe de Ventas';
    }
  }

  String get valor => name;
}
