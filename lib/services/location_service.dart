import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service.dart';

class LocationService {
  static Position? _lastKnown;

  /// Última posición conocida (actualizada desde el stream en tiempo real).
  static Position? get lastKnown => _lastKnown;

  /// Llama esto desde el listener del stream para mantener la posición actualizada.
  /// También persiste en SharedPreferences para que otros isolates puedan leerla.
  static void updateFromStream(Position pos) {
    _lastKnown = pos;
    _persistToPrefs(pos.latitude, pos.longitude);
  }

  static void _persistToPrefs(double lat, double lng) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('gps_last_lat', lat);
      prefs.setDouble('gps_last_lng', lng);
    }).catchError((_) {});
  }

  /// Lee la última posición guardada en SharedPreferences.
  /// Funciona en cualquier isolate, incluido el isolate de background de FlutterForegroundTask.
  static Future<Position?> getFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('gps_last_lat');
      final lng = prefs.getDouble('gps_last_lng');
      if (lat == null || lng == null) return null;
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5000,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      // No bloqueamos por isLocationServiceEnabled — aún podemos tener caché
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return false;
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene la posición actual con alta precisión.
  /// Usa lastKnown como fallback rápido si la posición fresca tarda más de 5s.
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return _lastKnown;

      // Intentar obtener posición fresca con timeout de 8 segundos
      Position? fresh;
      try {
        fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        // Fallback: última posición conocida
        fresh = await Geolocator.getLastKnownPosition() ?? _lastKnown;
      }

      if (fresh != null) _lastKnown = fresh;
      return fresh;
    } catch (_) {
      // Último recurso: posición conocida en caché
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _lastKnown = last;
        return last ?? _lastKnown;
      } catch (_) {
        return _lastKnown;
      }
    }
  }

  static Future<void> registrarUbicacionVendedor(String vendedorId) async {
    await registrarUbicacion(userId: vendedorId, nombre: '', cargo: 'VENDEDOR');
  }

  /// Envía la posición actual al servidor para cualquier tipo de usuario.
  static Future<void> registrarUbicacion({
    required String userId,
    required String nombre,
    required String cargo,
  }) async {
    final pos = await getCurrentPosition();
    if (pos != null) {
      await DataService.guardarUbicacion(
        vendedorId: userId,
        lat: pos.latitude,
        lng: pos.longitude,
        nombre: nombre,
        cargo: cargo,
      );
    }
  }

  static Stream<Position> get positionStream => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      );

  /// Último recurso: Google Geolocation REST API.
  /// Funciona solo con IP cuando GPS y red están desactivados.
  static const String _mapsApiKey = 'AIzaSyAkQv8RTOs510d2ag3Kkk0eIYjLj2DbfPQ';

  static Future<Position?> getGoogleGeolocationFallback() async {
    try {
      final res = await http
          .post(
            Uri.parse(
              'https://www.googleapis.com/geolocation/v1/geolocate?key=$_mapsApiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'considerIp': true}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc = data['location'] as Map<String, dynamic>?;
        final lat = (loc?['lat'] as num?)?.toDouble();
        final lng = (loc?['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: (data['accuracy'] as num?)?.toDouble() ?? 5000,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
