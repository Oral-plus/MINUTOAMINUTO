/// Planificación PPVC (Plan de Visita a Clientes)
class Ppvc {
  final String id;
  final String vendedorId;
  final DateTime fecha;
  final String zona;
  final int clientesProgramados;
  final List<String> clientes60Ids;
  final List<String> clientesPerdidosIds;
  final double metaVenta;
  final double metaRecaudo;
  final bool programado2DiasAntes;

  Ppvc({
    required this.id,
    required this.vendedorId,
    required this.fecha,
    required this.zona,
    this.clientesProgramados = 0,
    this.clientes60Ids = const [],
    this.clientesPerdidosIds = const [],
    this.metaVenta = 0,
    this.metaRecaudo = 0,
    this.programado2DiasAntes = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'vendedorId': vendedorId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'zona': zona,
        'clientesProgramados': clientesProgramados,
        'clientes60Ids': clientes60Ids.join(','),
        'clientesPerdidosIds': clientesPerdidosIds.join(','),
        'metaVenta': metaVenta,
        'metaRecaudo': metaRecaudo,
        'programado2DiasAntes': programado2DiasAntes ? 1 : 0,
      };

  factory Ppvc.fromMap(Map<String, dynamic> map) => Ppvc(
        id: map['id'] as String,
        vendedorId: map['vendedorId'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        zona: map['zona'] as String? ?? '',
        clientesProgramados: map['clientesProgramados'] as int? ?? 0,
        clientes60Ids: (map['clientes60Ids'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        clientesPerdidosIds: (map['clientesPerdidosIds'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        metaVenta: (map['metaVenta'] ?? 0).toDouble(),
        metaRecaudo: (map['metaRecaudo'] ?? 0).toDouble(),
        programado2DiasAntes: (map['programado2DiasAntes'] ?? 0) == 1,
      );
}
