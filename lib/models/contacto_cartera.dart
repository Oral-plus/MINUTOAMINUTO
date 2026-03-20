class ContactoCartera {
  final String cardCode;
  final String cardName;
  final String cardFName;
  final String slpName;
  final String coach;
  final String kam;

  const ContactoCartera({
    required this.cardCode,
    required this.cardName,
    required this.cardFName,
    required this.slpName,
    required this.coach,
    required this.kam,
  });

  factory ContactoCartera.fromMap(Map<String, dynamic> map) => ContactoCartera(
        cardCode:  _s(map['cardCode']),
        cardName:  _s(map['cardName']),
        cardFName: _s(map['cardFName']),
        slpName:   _s(map['slpName']),
        coach:     _s(map['coach']),
        kam:       _s(map['kam']),
      );

  static String _s(dynamic v) => v?.toString().trim() ?? '';

  /// Nombre para mostrar: usa CardFName si está disponible, sino CardName
  String get nombreMostrar => cardFName.isNotEmpty ? cardFName : cardName;
}
