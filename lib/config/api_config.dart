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
  /// - localhost:8080 = API Dart (memoria)
  /// - Cambie a la URL de su servidor PHP para SQL Server, ej:
  ///   'http://192.168.2.244/api' o 'http://192.168.2.244/minuto_a_minuto/api'
  static const String baseUrl = 'http://localhost:8080';
  static const bool useRemoteApi = true;
}
