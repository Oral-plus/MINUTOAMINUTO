import 'nivel_cargo.dart';

class Supervisor {
  final String id;
  final String nombre;
  final String codigo;
  final String zona;
  final NivelCargo cargo;
  final String? superiorId; // Coach -> KAM, KAM -> Jefe
  final List<String> subordinadosIds; // IDs de vendedores o coaches

  Supervisor({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.zona,
    required this.cargo,
    this.superiorId,
    this.subordinadosIds = const [],
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
        'superiorId': superiorId,
        'subordinadosIds': subordinadosIds.join(','),
      };

  factory Supervisor.fromMap(Map<String, dynamic> map) => Supervisor(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        codigo: map['codigo'] as String,
        zona: map['zona'] as String,
        cargo: NivelCargo.values.firstWhere(
          (e) => e.valor == map['cargo'],
          orElse: () => NivelCargo.coach,
        ),
        superiorId: map['superiorId'] as String?,
        subordinadosIds: (map['subordinadosIds'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
      );
}
