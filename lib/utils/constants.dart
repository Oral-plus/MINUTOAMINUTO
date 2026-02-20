import 'package:flutter/material.dart';

class AppConstants {
  // Colores corporativos
  static const Color azulCorporativo = Color(0xFF1565C0);
  static const Color verdeMeta = Color(0xFF2E7D32);
  static const Color amarilloAdvertencia = Color(0xFFF9A825);
  static const Color rojoCritico = Color(0xFFC62828);

  // Semáforo
  static const Color semaforoVerde = Color(0xFF4CAF50);
  static const Color semaforoAmarillo = Color(0xFFFFC107);
  static const Color semaforoRojo = Color(0xFFF44336);

  // Umbrales semáforo
  static const double umbralVerde = 90.0;
  static const double umbralAmarillo = 80.0;

  // Horarios
  static const int horaInicioJornadaLimite = 8; // 8:30 am
  static const int minutoInicioJornadaLimite = 30;
  static const int horaLlamadaMananaInicio = 8;
  static const int horaLlamadaMananaFin = 9;
  static const int horaLlamadaTardeInicio = 15;
  static const int horaLlamadaTardeFin = 17;
  static const int horaCierreSistema = 18;
  static const int horaAlertaSinLlamada = 12;
  static const int horaAlertaSinCierre = 17;

  // Metas
  static const double metaLlamadasCoach = 95;
  static const double metaLlamadasKam = 100;
  static const double metaInicioJornada = 90;
  static const double metaGeolocalizacion = 100;
  static const double metaPpvcProgramado = 100;
  static const double metaClientesProgramadosVsVisitados = 95;
  static const double metaCoincidenciaPpvcRvc = 90;

  // ILO (Índice de Liderazgo Operativo)
  static const double pesoDisciplinaLlamadas = 0.40;
  static const double pesoConversion60 = 0.20;
  static const double pesoRecuperacionPerdidos = 0.20;
  static const double pesoCumplimientoPresupuesto = 0.20;

  // Duración mínima llamada (minutos)
  static const int duracionMinimaLlamada = 2;
}
