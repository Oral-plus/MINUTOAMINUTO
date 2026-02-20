import 'constants.dart';

class KpiCalculator {
  /// % Llamadas Coach realizadas
  static double cumplimientoLlamadasCoach({
    required int realizadas,
    required int esperadas,
  }) {
    if (esperadas == 0) return 0;
    return (realizadas / esperadas) * 100;
  }

  /// % Llamadas KAM realizadas
  static double cumplimientoLlamadasKam({
    required int realizadas,
    required int esperadas,
  }) {
    if (esperadas == 0) return 0;
    return (realizadas / esperadas) * 100;
  }

  /// % Inicio jornada antes 8:30 am
  static double cumplimientoInicioJornada({
    required int puntuales,
    required int total,
  }) {
    if (total == 0) return 0;
    return (puntuales / total) * 100;
  }

  /// % Geolocalización activa
  static double cumplimientoGeolocalizacion({
    required int activos,
    required int total,
  }) {
    if (total == 0) return 0;
    return (activos / total) * 100;
  }

  /// Conversión 60
  static double conversion60({required int convertidos, required int visitados}) {
    if (visitados == 0) return 0;
    return (convertidos / visitados) * 100;
  }

  /// Productividad por visita
  static double productividadPorVisita({
    required double ventaTotal,
    required int clientesVisitados,
  }) {
    if (clientesVisitados == 0) return 0;
    return ventaTotal / clientesVisitados;
  }

  /// % Presupuesto diario cumplido
  static double cumplimientoPresupuestoDiario({
    required double ventaDia,
    required double presupuestoDia,
  }) {
    if (presupuestoDia == 0) return 0;
    return (ventaDia / presupuestoDia) * 100;
  }

  /// Índice de Liderazgo Operativo (ILO)
  static double calcularILO({
    required double disciplinaLlamadas,
    required double conversion60,
    required double recuperacionPerdidos,
    required double cumplimientoPresupuesto,
  }) {
    return (disciplinaLlamadas * AppConstants.pesoDisciplinaLlamadas) +
        (conversion60 * AppConstants.pesoConversion60) +
        (recuperacionPerdidos * AppConstants.pesoRecuperacionPerdidos) +
        (cumplimientoPresupuesto * AppConstants.pesoCumplimientoPresupuesto);
  }

  /// Color del semáforo según porcentaje
  static int semaforoPorcentaje(double porcentaje) {
    if (porcentaje >= AppConstants.umbralVerde) return 0; // Verde
    if (porcentaje >= AppConstants.umbralAmarillo) return 1; // Amarillo
    return 2; // Rojo
  }
}
