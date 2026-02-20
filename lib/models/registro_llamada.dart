import 'tipo_llamada.dart';
import 'nivel_cargo.dart';

class RegistroLlamada {
  final String id;
  final DateTime fecha;
  final DateTime horaInicio;
  final DateTime horaFin;
  final int duracionMinutos;
  final TipoLlamada tipoLlamada;
  final NivelCargo cargoLider;
  final String zona;
  final String nombreLider;
  final String nombreContactado;
  final int clientesProgramados;
  final int clientesVisitados;
  final double ventaDia;
  final double recaudoDia;
  final bool cumplioMeta;
  final bool coincidenciaPpvcRvc;
  final int conversion60;
  final int recuperacionPerdidos;
  final String observaciones;
  final bool confirmacionVeracidad;
  final String? rutaGrabacion;
  final String? transcripcionTexto;

  RegistroLlamada({
    required this.id,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.duracionMinutos,
    required this.tipoLlamada,
    required this.cargoLider,
    required this.zona,
    required this.nombreLider,
    required this.nombreContactado,
    this.clientesProgramados = 0,
    this.clientesVisitados = 0,
    this.ventaDia = 0,
    this.recaudoDia = 0,
    this.cumplioMeta = false,
    this.coincidenciaPpvcRvc = false,
    this.conversion60 = 0,
    this.recuperacionPerdidos = 0,
    this.observaciones = '',
    required this.confirmacionVeracidad,
    this.rutaGrabacion,
    this.transcripcionTexto,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String().split('T')[0],
        'horaInicio': horaInicio.toIso8601String(),
        'horaFin': horaFin.toIso8601String(),
        'duracionMinutos': duracionMinutos,
        'tipoLlamada': tipoLlamada.valor,
        'cargoLider': cargoLider.valor,
        'zona': zona,
        'nombreLider': nombreLider,
        'nombreContactado': nombreContactado,
        'clientesProgramados': clientesProgramados,
        'clientesVisitados': clientesVisitados,
        'ventaDia': ventaDia,
        'recaudoDia': recaudoDia,
        'cumplioMeta': cumplioMeta ? 1 : 0,
        'coincidenciaPpvcRvc': coincidenciaPpvcRvc ? 1 : 0,
        'conversion60': conversion60,
        'recuperacionPerdidos': recuperacionPerdidos,
        'observaciones': observaciones,
        'confirmacionVeracidad': confirmacionVeracidad ? 1 : 0,
        'rutaGrabacion': rutaGrabacion,
        'transcripcionTexto': transcripcionTexto,
      };

  factory RegistroLlamada.fromMap(Map<String, dynamic> map) => RegistroLlamada(
        id: map['id'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        horaInicio: DateTime.parse(map['horaInicio'] as String),
        horaFin: DateTime.parse(map['horaFin'] as String),
        duracionMinutos: map['duracionMinutos'] as int? ?? 0,
        tipoLlamada: TipoLlamada.values.firstWhere(
          (e) => e.valor == map['tipoLlamada'],
          orElse: () => TipoLlamada.manana,
        ),
        cargoLider: NivelCargo.values.firstWhere(
          (e) => e.valor == map['cargoLider'],
          orElse: () => NivelCargo.coach,
        ),
        zona: map['zona'] as String? ?? '',
        nombreLider: map['nombreLider'] as String? ?? '',
        nombreContactado: map['nombreContactado'] as String? ?? '',
        clientesProgramados: map['clientesProgramados'] as int? ?? 0,
        clientesVisitados: map['clientesVisitados'] as int? ?? 0,
        ventaDia: (map['ventaDia'] ?? 0).toDouble(),
        recaudoDia: (map['recaudoDia'] ?? 0).toDouble(),
        cumplioMeta: (map['cumplioMeta'] ?? 0) == 1,
        coincidenciaPpvcRvc: (map['coincidenciaPpvcRvc'] ?? 0) == 1,
        conversion60: map['conversion60'] as int? ?? 0,
        recuperacionPerdidos: map['recuperacionPerdidos'] as int? ?? 0,
        observaciones: map['observaciones'] as String? ?? '',
        confirmacionVeracidad: (map['confirmacionVeracidad'] ?? 0) == 1,
        rutaGrabacion: map['rutaGrabacion'] as String?,
        transcripcionTexto: map['transcripcionTexto'] as String?,
      );
}
