import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/weather_conditions.dart';

/// Cliente de la API OpenData de AEMET.
///
/// La API funciona en dos pasos: la primera petición devuelve un JSON con una
/// URL en el campo `datos`; hay que descargar esa URL para obtener el contenido
/// real (codificado en ISO-8859-1).
class AemetService {
  AemetService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? dotenv.env['AEMET_API_KEY'] ?? '';

  final http.Client _client;
  final String _apiKey;

  static const _base = 'https://opendata.aemet.es/opendata/api';

  /// Código INE del municipio (Barcelona = 08019).
  static const municipioBarcelona = '08019';

  /// Estaciones de observación cercanas a Barcelona.
  /// 0076  = Barcelona Aeropuerto (El Prat) — referencia habitual de ciudad.
  /// 0201D = Barcelona, Observatori Fabra (en la montaña, más ventoso).
  static const estacionBarcelona = '0076';

  bool get tieneApiKey => _apiKey.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Predicción horaria (para "planificar más tarde")
  // ---------------------------------------------------------------------------

  Future<List<WeatherConditions>> previsionHoraria({
    String municipio = municipioBarcelona,
  }) async {
    final payload = await _fetch(
      '/prediccion/especifica/municipio/horaria/$municipio',
    );
    if (payload is! List || payload.isEmpty) return const [];

    final dias = (((payload.first as Map)['prediccion'] as Map?)?['dia']
            as List?) ??
        const [];

    final result = <WeatherConditions>[];
    for (final diaRaw in dias.cast<Map<String, dynamic>>()) {
      final fecha = DateTime.tryParse(diaRaw['fecha']?.toString() ?? '');
      if (fecha == null) continue;

      final cielo = _porPeriodo(diaRaw['estadoCielo']);
      final temp = _porPeriodo(diaRaw['temperatura']);
      final vientoRacha = (diaRaw['vientoAndRachaMax'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];

      // vientoAndRachaMax mezcla entradas de viento (con direccion/velocidad)
      // y de racha máxima (con value), ambas con el mismo `periodo`.
      final vientoPorPeriodo = <String, Map<String, dynamic>>{};
      final rachaPorPeriodo = <String, double>{};
      for (final v in vientoRacha) {
        final periodo = v['periodo']?.toString() ?? '';
        if (v['velocidad'] != null) {
          vientoPorPeriodo[periodo] = v;
        } else if (v['value'] != null) {
          final r = double.tryParse(v['value'].toString());
          if (r != null) rachaPorPeriodo[periodo] = r;
        }
      }

      for (var hora = 0; hora < 24; hora++) {
        final periodo = hora.toString().padLeft(2, '0');
        final cieloRaw = cielo[periodo];
        final vientoRaw = vientoPorPeriodo[periodo];
        if (cieloRaw == null && vientoRaw == null) continue;

        final dir = (vientoRaw?['direccion'] as List?)?.first?.toString();
        final velKmh = double.tryParse(
          (vientoRaw?['velocidad'] as List?)?.first?.toString() ?? '',
        );

        result.add(
          WeatherConditions(
            timestamp: DateTime(
              fecha.year,
              fecha.month,
              fecha.day,
              hora,
            ),
            esPrevision: true,
            sky: SkyState.fromAemet(
              cieloRaw?['value']?.toString(),
              cieloRaw?['descripcion']?.toString(),
            ),
            windSpeedKmh: velKmh,
            windGustKmh: rachaPorPeriodo[periodo],
            windDirectionDeg: WeatherConditions.degreesFromCardinal(dir),
            windDirectionCardinal: dir,
            temperatureC: double.tryParse(
              temp[periodo]?['value']?.toString() ?? '',
            ),
          ),
        );
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Observación real (para "ahora")
  // ---------------------------------------------------------------------------

  Future<WeatherConditions?> observacionActual({
    String idema = estacionBarcelona,
  }) async {
    final payload = await _fetch(
      '/observacion/convencional/datos/estacion/$idema',
    );
    if (payload is! List || payload.isEmpty) return null;

    final registros = payload.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) =>
          (a['fint']?.toString() ?? '').compareTo(b['fint']?.toString() ?? ''));
    final ultimo = registros.last;

    // `fint` viene en UTC (sufijo +0000); lo pasamos a hora local.
    final fecha = DateTime.tryParse(ultimo['fint']?.toString() ?? '')
            ?.toLocal() ??
        DateTime.now();
    final vvMs = _num(ultimo['vv']);
    final vmaxMs = _num(ultimo['vmax']);
    final dvDeg = _num(ultimo['dv']);

    return WeatherConditions(
      timestamp: fecha,
      esPrevision: false,
      // la observación convencional no trae estado del cielo fiable.
      sky: const SkyState(),
      windSpeedKmh: vvMs == null ? null : vvMs * 3.6,
      windGustKmh: vmaxMs == null ? null : vmaxMs * 3.6,
      windDirectionDeg: dvDeg?.round(),
      windDirectionCardinal:
          dvDeg == null ? null : WeatherConditions.cardinalFromDegrees(dvDeg),
      temperatureC: _num(ultimo['ta']),
    );
  }

  /// Condiciones "ahora": viento y temperatura de la observación real, con el
  /// estado del cielo tomado de la predicción de la hora en curso.
  Future<WeatherConditions?> condicionesActuales({
    String idema = estacionBarcelona,
    String municipio = municipioBarcelona,
  }) async {
    WeatherConditions? obs;
    List<WeatherConditions> prevision = const [];
    try {
      obs = await observacionActual(idema: idema);
    } catch (_) {}
    try {
      prevision = await previsionHoraria(municipio: municipio);
    } catch (_) {}

    final ahora = DateTime.now();
    final horaActual = _masCercana(prevision, ahora);

    if (obs == null) return horaActual;
    if (horaActual == null) return obs;
    return obs.copyWith(sky: horaActual.sky);
  }

  static WeatherConditions? _masCercana(
    List<WeatherConditions> lista,
    DateTime objetivo,
  ) {
    if (lista.isEmpty) return null;
    WeatherConditions mejor = lista.first;
    var mejorDelta =
        (mejor.timestamp.difference(objetivo)).abs().inMinutes;
    for (final w in lista.skip(1)) {
      final d = (w.timestamp.difference(objetivo)).abs().inMinutes;
      if (d < mejorDelta) {
        mejor = w;
        mejorDelta = d;
      }
    }
    return mejor;
  }

  // ---------------------------------------------------------------------------
  // Infraestructura
  // ---------------------------------------------------------------------------

  Future<dynamic> _fetch(String path) async {
    if (_apiKey.isEmpty) {
      throw Exception('Falta AEMET_API_KEY en .env');
    }

    final metaResp = await _client.get(
      Uri.parse('$_base$path'),
      headers: {'api_key': _apiKey, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));

    if (metaResp.statusCode == 429) {
      throw Exception('AEMET: demasiadas peticiones, inténtalo en un momento');
    }
    if (metaResp.statusCode != 200) {
      throw Exception('AEMET respondió ${metaResp.statusCode}');
    }

    final meta = jsonDecode(metaResp.body) as Map<String, dynamic>;
    final datosUrl = meta['datos']?.toString();
    if (datosUrl == null) {
      throw Exception('AEMET: ${meta['descripcion'] ?? 'sin datos'}');
    }

    final datosResp = await _client
        .get(Uri.parse(datosUrl))
        .timeout(const Duration(seconds: 20));
    if (datosResp.statusCode != 200) {
      throw Exception('AEMET (datos) respondió ${datosResp.statusCode}');
    }

    // Los ficheros de datos de AEMET vienen en ISO-8859-1.
    return jsonDecode(latin1.decode(datosResp.bodyBytes));
  }

  static Map<String, Map<String, dynamic>> _porPeriodo(dynamic lista) {
    final out = <String, Map<String, dynamic>>{};
    if (lista is List) {
      for (final e in lista) {
        if (e is Map && e['periodo'] != null) {
          out[e['periodo'].toString()] = e.cast<String, dynamic>();
        }
      }
    }
    return out;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  void dispose() => _client.close();
}
