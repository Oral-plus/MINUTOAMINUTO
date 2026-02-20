import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';
import 'data_service.dart';

class LocationService {
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      );
}
