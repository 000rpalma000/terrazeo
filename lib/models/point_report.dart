import 'package:latlong2/latlong.dart';

import 'bar.dart';
import 'comfort.dart';
import 'sun_status.dart';
import 'weather_conditions.dart';

/// Informe de sol / viento / temperatura / confort en un sitio.
class PointReport {
  /// Bar/terraza al que corresponde, si se abrió desde uno.
  final Bar? bar;

  /// Veredicto de confort (a gusto / pega el sol / hay brisa…).
  final ComfortVerdict comfort;

  /// Punto realmente evaluado (puede diferir del original si estaba sobre un
  /// edificio: se movió al espacio abierto más cercano).
  final LatLng punto;
  final bool ajustado;

  /// Instante para el que se calcula (ahora o una hora elegida).
  final DateTime instante;
  final bool esPrevision;

  // --- Sol ---
  final SunStatus sunStatus;
  final double sunElevationDeg;
  final double sunAzimuthDeg;
  final double? cloudFraction;

  /// Minutos de sol que quedan hasta el ocaso (si es de día).
  final Duration? solRestante;

  // --- Tiempo (AEMET) ---
  final double? windSpeedKmh;
  final double? windGustKmh;
  final int? windDirectionDeg;
  final String? windDirectionCardinal;
  final double? temperatureC;

  const PointReport({
    required this.comfort,
    required this.punto,
    required this.ajustado,
    required this.instante,
    required this.esPrevision,
    required this.sunStatus,
    required this.sunElevationDeg,
    required this.sunAzimuthDeg,
    this.bar,
    this.cloudFraction,
    this.solRestante,
    this.windSpeedKmh,
    this.windGustKmh,
    this.windDirectionDeg,
    this.windDirectionCardinal,
    this.temperatureC,
  });

  WindStrength get windStrength =>
      WindStrengthInfo.fromKmh(windSpeedKmh ?? 0);

  bool get rafagasDestacables =>
      windGustKmh != null &&
      windSpeedKmh != null &&
      windGustKmh! - windSpeedKmh! >= 15;

  bool get haySol => sunStatus.haySolDirecto;
}
