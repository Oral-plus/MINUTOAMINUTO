/// Registro de Visita a Cliente (RVC)
class Rvc {
  final String id;
  final String vendedorId;
  final DateTime fecha;
  final String zona;
  final int clientesVisitados;
  final int clientes60Visitados;
  final int clientesPerdidosVisitados;
  final double ventaTotal;
  final double recaudoTotal;
  final List<String> clientesNoVisitados;
  final bool descuentosAplicados;

  Rvc({
    required this.id,
    required this.vendedorId,
    required this.fecha,
    required this.zona,
    this.clientesVisitados = 0,
    this.clientes60Visitados = 0,
    this.clientesPerdidosVisitados = 0,
    this.ventaTotal = 0,
    this.recaudoTotal = 0,
    this.clientesNoVisitados = const [],
    this.descuentosAplicados = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'vendedorId': vendedorId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'zona': zona,
        'clientesVisitados': clientesVisitados,
        'clientes60Visitados': clientes60Visitados,
        'clientesPerdidosVisitados': clientesPerdidosVisitados,
        'ventaTotal': ventaTotal,
        'recaudoTotal': recaudoTotal,
        'clientesNoVisitados': clientesNoVisitados.join(','),
        'descuentosAplicados': descuentosAplicados ? 1 : 0,
      };

  factory Rvc.fromMap(Map<String, dynamic> map) => Rvc(
        id: map['id'] as String,
        vendedorId: map['vendedorId'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        zona: map['zona'] as String? ?? '',
        clientesVisitados: map['clientesVisitados'] as int? ?? 0,
        clientes60Visitados: map['clientes60Visitados'] as int? ?? 0,
        clientesPerdidosVisitados:
            map['clientesPerdidosVisitados'] as int? ?? 0,
        ventaTotal: (map['ventaTotal'] ?? 0).toDouble(),
        recaudoTotal: (map['recaudoTotal'] ?? 0).toDouble(),
        clientesNoVisitados: (map['clientesNoVisitados'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        descuentosAplicados: (map['descuentosAplicados'] ?? 0) == 1,
      );
}
