import 'package:geolocator/geolocator.dart';
import 'data_service.dart';

class LocationService {
  static Position? _lastKnown;

  /// Última posición conocida (actualizada desde el stream en tiempo real).
  static Position? get lastKnown => _lastKnown;

  /// Llama esto desde el listener del stream para mantener la posición actualizada.
  static void updateFromStream(Position pos) {
    _lastKnown = pos;
  }

  static Future<bool> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return false;
      // Solicitar "always" para que el monitor de llamadas pueda obtener GPS en segundo plano
      if (permission == LocationPermission.whileInUse) {
        final upgraded = await Geolocator.requestPermission();
        if (upgraded == LocationPermission.always) permission = upgraded;
      }
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
    final pos = await getCurrentPosition();
    if (pos != null) {
      await DataService.guardarUbicacion(
        vendedorId: vendedorId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
    }
  }

  static Stream<Position> get positionStream => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      );
}
