/// Utilidades para normalización de números telefónicos.
/// Usado en la correlación de llamadas duales (punto A + punto B).
class PhoneUtils {
  /// Normaliza un número para comparación (elimina espacios, +, guiones).
  static String normalize(String? number) {
    if (number == null || number.isEmpty) return '';
    return number.replaceAll(RegExp(r'[\s\-\(\)\+]'), '').replaceAll(RegExp(r'\D'), '');
  }

  /// Devuelve true si dos números coinciden tras normalizar.
  static bool matches(String? a, String? b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    return na == nb || na.endsWith(nb) || nb.endsWith(na);
  }
}
