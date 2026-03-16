import 'package:flutter/material.dart';

class AppKeys {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
}

class AppConstants {
  // Tema Premium Blanco y Negro
  static const Color azulCorporativo = Color(0xFF0A0A0A); // Negro casi puro, más suave que 000000
  static const Color verdeMeta = Color(0xFF262626);       // Gris muy oscuro
  static const Color amarilloAdvertencia = Color(0xFF737373); // Gris medio
  static const Color rojoCritico = Color(0xFFA3A3A3);     // Gris claro para contrastes suaves 

  // Semáforo (escala de grises)
  static const Color semaforoVerde = Color(0xFF262626);   // Éxito / Alta prioridad -> Negro mate
  static const Color semaforoAmarillo = Color(0xFF737373); // Alerta media -> Gris
  static const Color semaforoRojo = Color(0xFFD4D4D4);     // Crítico/Bajo -> Gris claro (fondo)

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
  // Alerta 8:20: vendedor sin llamada hecha antes de las 8:20 → notificar al coach
  static const int horaAlerta8am = 8;
  static const int minutoAlerta8am = 20;

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
