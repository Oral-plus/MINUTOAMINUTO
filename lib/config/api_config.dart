/// Configuración de la API
///
/// useRemoteApi = false  → SQLite local (Android/iOS/Windows con FFI)
/// useRemoteApi = true   → API remota
///
/// Opciones de baseUrl:
/// - API Dart local (memoria): 'http://localhost:8080'
/// - API PHP + SQL Server:    'http://192.168.2.244/api' (o la URL donde esté PHP)
///
/// Para SQL Server: usar la API PHP y apuntar baseUrl al servidor.
/// La API PHP escribe en [minuto_a_minuto].[dbo].[supervisores] y vendedores.
class ApiConfig {
  /// URL de la API.
  /// - Render desplegado: 'https://minutoaminuto-1.onrender.com'
  /// - PHP + SQL Server (LAN): 'http://192.168.2.244/api'
  /// - Se puede sobreescribir con --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://minutoaminuto-1.onrender.com',
  );

  /// URL alternativa cuando el servidor publica la API sin el prefijo /api.
  /// Se puede sobreescribir con --dart-define=API_FALLBACK_BASE_URL=...
  static const String fallbackBaseUrl = String.fromEnvironment(
    'API_FALLBACK_BASE_URL',
    defaultValue: 'https://minutoaminuto-1.onrender.com/api',
  );
  /// false = SQLite local. true = API remota (inserta en servidor).
  static const bool useRemoteApi = true;
}
