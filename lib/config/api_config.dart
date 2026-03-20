/// Configuración de la API
///
/// useRemoteApi = false  → SQLite local (Android/iOS/Windows con FFI)
/// useRemoteApi = true   → API remota
///
/// Opciones de baseUrl:
/// - Producción: 'https://minutoamimuto.oral-plus.com' (usa HTTPS si nginx redirige)
/// - LAN:        'http://192.168.2.253:3005'
///
/// Para SQL Server: usar API remota con endpoints compatibles.
class ApiConfig {
  /// URL de la API.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://minutoamimuto.oral-plus.com',
  );

  /// Fallback si la principal falla.
  static const String fallbackBaseUrl = String.fromEnvironment(
    'API_FALLBACK_BASE_URL',
    defaultValue: 'https://minutoamimuto.oral-plus.com',
  );
  /// false = SQLite local (todo queda en el dispositivo).
  /// true = API remota (inserta en servidor).
  static const bool useRemoteApi = true;

  /// Clave de Gemini para transcripción directa (solo si useRemoteApi=false).
  /// Con useRemoteApi=true la transcripción va por /transcribe en el servidor.
  /// Nunca pongas la clave aquí — pásala en tiempo de compilación:
  ///   flutter build apk --dart-define=GEMINI_API_KEY=TU_CLAVE
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyAkQv8RTOs510d2ag3Kkk0eIYjLj2DbfPQ', // API Key proporcionada por el usuario para transcripción directa rápida
  );
}
