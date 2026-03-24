import 'nivel_cargo.dart';

class Supervisor {
  final String id;
  final String nombre;
  final String codigo;
  final String zona;
  final NivelCargo cargo;
  final String? telefono;
  final String? superiorId; // Coach -> KAM, KAM -> Jefe
  final List<String> subordinadosIds; // IDs de vendedores o coaches
  final String? alias; // login simplificado KAM01, COACH01...

  Supervisor({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.zona,
    required this.cargo,
    this.telefono,
    this.superiorId,
    this.subordinadosIds = const [],
    this.alias,
  });

  bool get esCoach => cargo == NivelCargo.coach;
  bool get esKam => cargo == NivelCargo.kam;
  bool get esJefe => cargo == NivelCargo.jefe;

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'codigo': codigo,
        'zona': zona,
        'cargo': cargo.valor,
        'telefono': telefono,
        'superiorId': superiorId,
        'subordinadosIds': subordinadosIds.join(','),
        'alias': alias,
      };

  factory Supervisor.fromMap(Map<String, dynamic> map) => Supervisor(
        id: map['id'].toString(),
        nombre: map['nombre'] as String,
        codigo: map['codigo'] as String,
        zona: map['zona'] as String,
        cargo: NivelCargo.values.firstWhere(
          (e) => e.valor == map['cargo'],
          orElse: () => NivelCargo.coach,
        ),
        telefono: map['telefono'] as String?,
        superiorId: map['superiorId'] as String?,
        subordinadosIds: (map['subordinadosIds'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        alias: map['alias'] as String?,
      );
  Supervisor copyWith({
    String? id,
    String? nombre,
    String? codigo,
    String? zona,
    NivelCargo? cargo,
    String? telefono,
    String? superiorId,
    List<String>? subordinadosIds,
    String? alias,
  }) =>
      Supervisor(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        codigo: codigo ?? this.codigo,
        zona: zona ?? this.zona,
        cargo: cargo ?? this.cargo,
        telefono: telefono ?? this.telefono,
        superiorId: superiorId ?? this.superiorId,
        subordinadosIds: subordinadosIds ?? this.subordinadosIds,
        alias: alias ?? this.alias,
      );
}
