/// Configuración de la API
///
/// useRemoteApi = false  → SQLite local (Android/iOS/Windows con FFI)
/// useRemoteApi = true   → API remota
///
/// Opciones de baseUrl:
/// - API Dart local (memoria): 'http://localhost:8080'
/// - API Node Render:         'https://minutoaminuto-2.onrender.com'
///
/// Para SQL Server: usar API remota con endpoints compatibles.
class ApiConfig {
  /// URL de la API.
  /// - Render desplegado: 'https://minutoaminuto-2.onrender.com'
  /// - Respaldo: 'https://minutoaminuto-2.onrender.com'
  /// - Se puede sobreescribir con --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://minutoaminuto-2.onrender.com',
  );

  /// URL alternativa cuando el servidor publica la API sin el prefijo /api.
  /// Se puede sobreescribir con --dart-define=API_FALLBACK_BASE_URL=...
  static const String fallbackBaseUrl = String.fromEnvironment(
    'API_FALLBACK_BASE_URL',
    defaultValue: 'https://minutoaminuto-2.onrender.com',
  );
  /// false = SQLite local. true = API remota (inserta en servidor).
  static const bool useRemoteApi = true;
}
