import 'package:latlong2/latlong.dart';
import 'package:solar_calculator/solar_calculator.dart';

/// Posición aparente del sol.
class SunPosition {
  /// Grados sobre el horizonte (negativo = bajo el horizonte).
  final double elevationDeg;

  /// Grados desde el norte, sentido horario.
  final double azimuthDeg;

  const SunPosition({required this.elevationDeg, required this.azimuthDeg});

  bool get esDeDia => elevationDeg > 0;
}

class SunService {
  const SunService();

  SunPosition posicion(LatLng lugar, DateTime horaLocal) {
    final calc = SolarCalculator(
      Instant.fromDateTime(horaLocal),
      lugar.latitude,
      lugar.longitude,
    );
    final h = calc.sunHorizontalPosition;
    return SunPosition(elevationDeg: h.elevation, azimuthDeg: h.azimuth);
  }

  DateTime ocaso(LatLng lugar, DateTime horaLocal) => SolarCalculator(
        Instant.fromDateTime(horaLocal),
        lugar.latitude,
        lugar.longitude,
      ).sunsetTime.toUtcDateTime().toLocal();
}
