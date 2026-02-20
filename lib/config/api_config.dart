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
  /// - https://minutoaminuto-1.onrender.com = API Dart desplegada en Render
  /// - localhost:8080 = API Dart local
  /// - PHP + SQL Server: 'http://192.168.2.244/api'
  static const String baseUrl = 'https://minutoaminuto-1.onrender.com';
  static const bool useRemoteApi = true;
}
