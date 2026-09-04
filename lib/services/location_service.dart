import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Ubicación del dispositivo con gestión de permisos.
class LocationService {
  const LocationService();

  /// Centro de Barcelona, respaldo si no hay permiso/GPS.
  static final LatLng fallback = LatLng(41.3874, 2.1686);

  Future<({LatLng punto, bool esReal})> ubicacionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (punto: fallback, esReal: false);
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return (punto: fallback, esReal: false);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return (punto: LatLng(pos.latitude, pos.longitude), esReal: true);
    } catch (_) {
      return (punto: fallback, esReal: false);
    }
  }
}
