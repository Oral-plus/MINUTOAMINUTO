class Vendedor {
  final String id;
  final String nombre;
  final String codigo;
  final String zona;
  final String? coachId;
  final String? telefono;
  final bool geolocalizacionActiva;
  final DateTime? horaInicioJornada;
  final double presupuestoMensual;
  final double presupuestoDiario;
  final String? alias; // login simplificado VEND01, etc.

  Vendedor({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.zona,
    this.coachId,
    this.telefono,
    this.geolocalizacionActiva = false,
    this.horaInicioJornada,
    this.presupuestoMensual = 0,
    this.presupuestoDiario = 0,
    this.alias,
  });

  Map<String, dynamic> toMap() => {
        'id': id.toString(),
        'nombre': nombre,
        'codigo': codigo,
        'zona': zona,
        'coachId': coachId,
        'telefono': telefono,
        'geolocalizacionActiva': geolocalizacionActiva ? 1 : 0,
        'horaInicioJornada': horaInicioJornada?.toIso8601String(),
        'presupuestoMensual': presupuestoMensual,
        'presupuestoDiario': presupuestoDiario,
        'alias': alias,
      };

  factory Vendedor.fromMap(Map<String, dynamic> map) => Vendedor(
        id: map['id'].toString(),
        nombre: map['nombre'] as String,
        codigo: map['codigo'] as String,
        zona: map['zona'] as String,
        coachId: (map['coachId'] as String?) ?? '',
        telefono: map['telefono'] as String?,
        geolocalizacionActiva: (map['geolocalizacionActiva'] ?? 0) == 1,
        horaInicioJornada: map['horaInicioJornada'] != null
            ? DateTime.parse(map['horaInicioJornada'] as String)
            : null,
        presupuestoMensual: (map['presupuestoMensual'] ?? 0).toDouble(),
        presupuestoDiario: (map['presupuestoDiario'] ?? 0).toDouble(),
        alias: map['alias'] as String?,
      );
  Vendedor copyWith({
    String? id,
    String? nombre,
    String? codigo,
    String? zona,
    String? coachId,
    String? telefono,
    bool? geolocalizacionActiva,
    DateTime? horaInicioJornada,
    double? presupuestoMensual,
    double? presupuestoDiario,
    String? alias,
  }) =>
      Vendedor(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        codigo: codigo ?? this.codigo,
        zona: zona ?? this.zona,
        coachId: coachId ?? this.coachId,
        telefono: telefono ?? this.telefono,
        geolocalizacionActiva: geolocalizacionActiva ?? this.geolocalizacionActiva,
        horaInicioJornada: horaInicioJornada ?? this.horaInicioJornada,
        presupuestoMensual: presupuestoMensual ?? this.presupuestoMensual,
        presupuestoDiario: presupuestoDiario ?? this.presupuestoDiario,
        alias: alias ?? this.alias,
      );
}
