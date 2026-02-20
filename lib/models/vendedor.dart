class Vendedor {
  final String id;
  final String nombre;
  final String codigo;
  final String zona;
  final String coachId;
  final bool geolocalizacionActiva;
  final DateTime? horaInicioJornada;
  final double presupuestoMensual;
  final double presupuestoDiario;

  Vendedor({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.zona,
    required this.coachId,
    this.geolocalizacionActiva = false,
    this.horaInicioJornada,
    this.presupuestoMensual = 0,
    this.presupuestoDiario = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'codigo': codigo,
        'zona': zona,
        'coachId': coachId,
        'geolocalizacionActiva': geolocalizacionActiva ? 1 : 0,
        'horaInicioJornada': horaInicioJornada?.toIso8601String(),
        'presupuestoMensual': presupuestoMensual,
        'presupuestoDiario': presupuestoDiario,
      };

  factory Vendedor.fromMap(Map<String, dynamic> map) => Vendedor(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        codigo: map['codigo'] as String,
        zona: map['zona'] as String,
        coachId: map['coachId'] as String,
        geolocalizacionActiva: (map['geolocalizacionActiva'] ?? 0) == 1,
        horaInicioJornada: map['horaInicioJornada'] != null
            ? DateTime.parse(map['horaInicioJornada'] as String)
            : null,
        presupuestoMensual: (map['presupuestoMensual'] ?? 0).toDouble(),
        presupuestoDiario: (map['presupuestoDiario'] ?? 0).toDouble(),
      );
}
