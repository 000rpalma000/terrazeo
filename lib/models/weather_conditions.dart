import 'dart:math' as math;

/// Fuerza del viento en una escala sencilla derivada de la escala Beaufort.
enum WindStrength {
  calm, // < 5 km/h
  light, // 5 - 12 km/h
  breezy, // 12 - 20 km/h
  windy, // 20 - 35 km/h
  veryWindy, // > 35 km/h
}

extension WindStrengthInfo on WindStrength {
  String get etiqueta {
    switch (this) {
      case WindStrength.calm:
        return 'En calma';
      case WindStrength.light:
        return 'Brisa ligera';
      case WindStrength.breezy:
        return 'Algo de viento';
      case WindStrength.windy:
        return 'Viento';
      case WindStrength.veryWindy:
        return 'Mucho viento';
    }
  }

  static WindStrength fromKmh(double kmh) {
    if (kmh < 5) return WindStrength.calm;
    if (kmh < 12) return WindStrength.light;
    if (kmh < 20) return WindStrength.breezy;
    if (kmh < 35) return WindStrength.windy;
    return WindStrength.veryWindy;
  }
}

/// Estado del cielo, mapeado desde los códigos `estadoCielo` de AEMET.
class SkyState {
  final int? code;
  final String? descripcion;

  /// Fracción de nubes estimada 0..1 (aproximada a partir del código).
  final double cloudFraction;

  const SkyState({this.code, this.descripcion, this.cloudFraction = 0});

  bool get esDespejado => cloudFraction <= 0.25;
  bool get esNoche => descripcion?.toLowerCase().contains('noche') ?? false;

  /// Códigos AEMET: https://opendata.aemet.es/dos" (tabla de estado del cielo).
  /// 11 despejado · 12 poco nuboso · 13/14 nuboso · 15/16 muy nuboso/cubierto
  /// 17 nubes altas · 2x/3x/4x con precipitación. El sufijo `n` = noche.
  factory SkyState.fromAemet(String? raw, String? descripcion) {
    if (raw == null || raw.isEmpty) {
      return SkyState(descripcion: descripcion);
    }
    final numeric = int.tryParse(raw.replaceAll('n', ''));
    double cloud;
    switch (numeric) {
      case 11:
        cloud = 0.0;
        break;
      case 12:
      case 17:
        cloud = 0.2;
        break;
      case 13:
        cloud = 0.45;
        break;
      case 14:
        cloud = 0.65;
        break;
      case 15:
        cloud = 0.85;
        break;
      case 16:
        cloud = 1.0;
        break;
      default:
        // 2x/3x/4x -> precipitación, cielo muy cubierto.
        cloud = (numeric != null && numeric >= 20) ? 0.9 : 0.5;
    }
    return SkyState(
      code: numeric,
      descripcion: descripcion,
      cloudFraction: cloud,
    );
  }
}

/// Condiciones puntuales (ahora) o previstas (una hora concreta) en un lugar.
class WeatherConditions {
  final DateTime timestamp;

  /// `true` si proviene de la predicción horaria; `false` si es observación real.
  final bool esPrevision;

  final double? windSpeedKmh;
  final double? windGustKmh;

  /// Dirección meteorológica: grados desde los que sopla el viento (0 = norte).
  final int? windDirectionDeg;
  final String? windDirectionCardinal;

  final double? temperatureC;
  final SkyState sky;

  const WeatherConditions({
    required this.timestamp,
    required this.esPrevision,
    required this.sky,
    this.windSpeedKmh,
    this.windGustKmh,
    this.windDirectionDeg,
    this.windDirectionCardinal,
    this.temperatureC,
  });

  WindStrength get windStrength =>
      WindStrengthInfo.fromKmh(windSpeedKmh ?? 0);

  /// Ráfagas notablemente más fuertes que el viento medio.
  bool get rafagasDestacables =>
      windGustKmh != null &&
      windSpeedKmh != null &&
      windGustKmh! - windSpeedKmh! >= 15;

  WeatherConditions copyWith({SkyState? sky}) => WeatherConditions(
        timestamp: timestamp,
        esPrevision: esPrevision,
        sky: sky ?? this.sky,
        windSpeedKmh: windSpeedKmh,
        windGustKmh: windGustKmh,
        windDirectionDeg: windDirectionDeg,
        windDirectionCardinal: windDirectionCardinal,
        temperatureC: temperatureC,
      );

  static const _cardinales = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', //
    'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO',
  ];

  static String cardinalFromDegrees(num deg) {
    final i = ((deg % 360) / 22.5).round() % 16;
    return _cardinales[i];
  }

  static int? degreesFromCardinal(String? c) {
    if (c == null) return null;
    final map = {
      'N': 0, 'NNE': 23, 'NE': 45, 'ENE': 68, 'E': 90, 'ESE': 113,
      'SE': 135, 'SSE': 158, 'S': 180, 'SSW': 203, 'SW': 225, 'WSW': 248,
      'W': 270, 'WNW': 293, 'NW': 315, 'NNW': 338,
      // variantes en español que devuelve AEMET
      'SSO': 203, 'SO': 225, 'OSO': 248, 'O': 270, 'ONO': 293, 'NO': 315,
      'NNO': 338, 'C': null,
    };
    return map[c.toUpperCase()];
  }

  /// Ángulo en radianes para dibujar una flecha que apunta *hacia donde va* el
  /// viento (opuesto a la dirección meteorológica).
  double? get flechaHaciaDondeVaRad {
    final d = windDirectionDeg;
    if (d == null) return null;
    return (d + 180) * math.pi / 180;
  }
}
