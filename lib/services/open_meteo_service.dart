import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/weather_conditions.dart';

/// Cliente de Open-Meteo (https://open-meteo.com): sin clave de API y con
/// cobertura mundial.
///
/// Se usa fuera de España, donde AEMET no llega, y como red de seguridad si
/// AEMET falla. Devuelve el mismo modelo [WeatherConditions] que [AemetService]
/// para que el resto de la app no note de dónde vienen los datos.
///
/// Se piden las horas en UTC (`timezone=UTC`) y se convierten a hora local del
/// dispositivo, igual que hace AEMET con su campo `fint`.
class OpenMeteoService {
  OpenMeteoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.open-meteo.com/v1/forecast';
  static const _campos =
      'temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,cloud_cover';

  Future<Map<String, dynamic>> _fetch(LatLng p) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': p.latitude.toStringAsFixed(4),
      'longitude': p.longitude.toStringAsFixed(4),
      'current': _campos,
      'hourly': _campos,
      'wind_speed_unit': 'kmh',
      'forecast_days': '3',
      'timezone': 'UTC',
    });
    final resp =
        await _client.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Open-Meteo respondió ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<WeatherConditions?> condicionesActuales(LatLng p) async {
    final data = await _fetch(p);
    return condicionesDesdeCurrent(data['current'] as Map<String, dynamic>?);
  }

  Future<List<WeatherConditions>> previsionHoraria(LatLng p) async {
    final data = await _fetch(p);
    return previsionDesdeHourly(data['hourly'] as Map<String, dynamic>?);
  }

  /// "Ahora" y previsión horaria en una sola petición (Open-Meteo no separa
  /// endpoints como AEMET).
  Future<({WeatherConditions? ahora, List<WeatherConditions> prevision})> todo(
    LatLng p,
  ) async {
    final data = await _fetch(p);
    return (
      ahora: condicionesDesdeCurrent(data['current'] as Map<String, dynamic>?),
      prevision:
          previsionDesdeHourly(data['hourly'] as Map<String, dynamic>?),
    );
  }

  // --- Parseo (puro, testeable sin red) --------------------------------------

  static WeatherConditions? condicionesDesdeCurrent(Map<String, dynamic>? c) {
    if (c == null) return null;
    final t = DateTime.tryParse('${c['time']}Z');
    if (t == null) return null;
    final dirDeg = _num(c['wind_direction_10m']);
    return WeatherConditions(
      timestamp: t.toLocal(),
      esPrevision: false,
      sky: _sky(c['cloud_cover']),
      windSpeedKmh: _num(c['wind_speed_10m']),
      windGustKmh: _num(c['wind_gusts_10m']),
      windDirectionDeg: dirDeg?.round(),
      windDirectionCardinal: dirDeg == null
          ? null
          : WeatherConditions.cardinalFromDegrees(dirDeg),
      temperatureC: _num(c['temperature_2m']),
    );
  }

  static List<WeatherConditions> previsionDesdeHourly(Map<String, dynamic>? h) {
    if (h == null) return const [];
    final tiempos = (h['time'] as List?) ?? const [];
    final temp = (h['temperature_2m'] as List?) ?? const [];
    final viento = (h['wind_speed_10m'] as List?) ?? const [];
    final racha = (h['wind_gusts_10m'] as List?) ?? const [];
    final dir = (h['wind_direction_10m'] as List?) ?? const [];
    final nubes = (h['cloud_cover'] as List?) ?? const [];

    T? at<T>(List l, int i) => i < l.length ? l[i] as T? : null;

    final out = <WeatherConditions>[];
    for (var i = 0; i < tiempos.length; i++) {
      final t = DateTime.tryParse('${tiempos[i]}Z');
      if (t == null) continue;
      final dirDeg = _num(at<dynamic>(dir, i));
      out.add(WeatherConditions(
        timestamp: t.toLocal(),
        esPrevision: true,
        sky: _sky(at<dynamic>(nubes, i)),
        windSpeedKmh: _num(at<dynamic>(viento, i)),
        windGustKmh: _num(at<dynamic>(racha, i)),
        windDirectionDeg: dirDeg?.round(),
        windDirectionCardinal: dirDeg == null
            ? null
            : WeatherConditions.cardinalFromDegrees(dirDeg),
        temperatureC: _num(at<dynamic>(temp, i)),
      ));
    }
    return out;
  }

  /// Open-Meteo da nubosidad en % (0-100); el modelo la quiere como fracción.
  static SkyState _sky(dynamic pct) {
    final v = _num(pct);
    if (v == null) return const SkyState();
    return SkyState(cloudFraction: (v / 100).clamp(0.0, 1.0));
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void dispose() => _client.close();
}
