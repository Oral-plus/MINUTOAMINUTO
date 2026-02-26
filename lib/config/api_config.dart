/// Configuración de la API
///
/// useRemoteApi = false  → SQLite local (Android/iOS/Windows con FFI)
/// useRemoteApi = true   → API remota
///
/// Opciones de baseUrl:
/// - API Dart local (memoria): 'http://localhost:8080'
/// - API LAN Node:            'http://192.168.2.253:3005'
///
/// Para SQL Server: usar API remota con endpoints compatibles.
class ApiConfig {
  /// URL de la API.
  /// - Principal (LAN): 'http://192.168.2.253:3005'
  /// - Se puede sobreescribir con --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.2.253:3005',
  );

  /// Mantiene compatibilidad con código existente.
  /// Debe ser la misma URL LAN; no se usa fallback externo.
  /// Se puede sobreescribir con --dart-define=API_FALLBACK_BASE_URL=...
  static const String fallbackBaseUrl = String.fromEnvironment(
    'API_FALLBACK_BASE_URL',
    defaultValue: 'http://192.168.2.253:3005',
  );
  /// false = SQLite local (todo queda en el dispositivo).
  /// true = API remota (inserta en servidor).
  /// Cambiar a true cuando el dominio/API LAN esté disponible.
  static const bool useRemoteApi = false;
}
