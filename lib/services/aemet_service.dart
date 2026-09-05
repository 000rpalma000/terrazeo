import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/geo.dart';
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

  // ---------------------------------------------------------------------------
  // Resolución por coordenadas (para funcionar en cualquier punto de España,
  // no solo Barcelona). El municipio / estación se eligen por cercanía a
  // partir de los maestros de AEMET, cacheados en disco.
  // ---------------------------------------------------------------------------

  /// Código del municipio AEMET más cercano a [p] y su distancia en metros.
  /// `null` si no se pudo cargar el maestro.
  Future<({String codigo, double distanciaM})?> municipioCercano(LatLng p) async {
    try {
      return _masCercanoEnLista(await _municipiosMin(), p);
    } catch (_) {
      return null;
    }
  }

  /// Indicativo (idema) de la estación de observación más cercana a [p] y su
  /// distancia en metros. `null` si no se pudo cargar el maestro.
  Future<({String codigo, double distanciaM})?> estacionCercana(LatLng p) async {
    try {
      return _masCercanoEnLista(await _estacionesMin(), p);
    } catch (_) {
      return null;
    }
  }

  Future<List<WeatherConditions>> previsionHorariaEnPunto(LatLng p) async {
    final m = await municipioCercano(p);
    if (m == null) return const [];
    return previsionHoraria(municipio: m.codigo);
  }

  Future<WeatherConditions?> observacionActualEnPunto(LatLng p) async {
    final e = await estacionCercana(p);
    if (e == null) return null;
    return observacionActual(idema: e.codigo);
  }

  /// Igual que [condicionesActuales] pero eligiendo estación y municipio por
  /// cercanía a [p].
  Future<WeatherConditions?> condicionesActualesEnPunto(LatLng p) async {
    WeatherConditions? obs;
    List<WeatherConditions> prevision = const [];
    try {
      obs = await observacionActualEnPunto(p);
    } catch (_) {}
    try {
      prevision = await previsionHorariaEnPunto(p);
    } catch (_) {}

    final horaActual = _masCercana(prevision, DateTime.now());
    if (obs == null) return horaActual;
    if (horaActual == null) return obs;
    return obs.copyWith(sky: horaActual.sky);
  }

  /// Convierte "411734N" / "020412E" (grados-minutos-segundos pegados, con letra
  /// de hemisferio) a grados decimales. Formato fijo 2+2+2 dígitos.
  static double? parseDms(String s) {
    final limpio = s.trim().toUpperCase();
    if (limpio.length < 7) return null;
    final hemi = limpio[limpio.length - 1];
    final digitos = limpio.substring(0, limpio.length - 1);
    if (digitos.length != 6 || int.tryParse(digitos) == null) return null;
    final g = int.parse(digitos.substring(0, 2));
    final m = int.parse(digitos.substring(2, 4));
    final seg = int.parse(digitos.substring(4, 6));
    final valor = g + m / 60 + seg / 3600;
    return (hemi == 'S' || hemi == 'W' || hemi == 'O') ? -valor : valor;
  }

  /// De una lista de `{c: codigo, a: lat, o: lon}` devuelve el más cercano a [p].
  static ({String codigo, double distanciaM})? _masCercanoEnLista(
    List<Map<String, dynamic>> lista,
    LatLng p,
  ) {
    Map<String, dynamic>? mejor;
    double? mejorD;
    for (final m in lista) {
      final lat = (m['a'] as num?)?.toDouble();
      final lon = (m['o'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final d = Geo.distancia(p, LatLng(lat, lon));
      if (mejorD == null || d < mejorD) {
        mejorD = d;
        mejor = m;
      }
    }
    if (mejor == null || mejorD == null) return null;
    return (codigo: mejor['c'] as String, distanciaM: mejorD);
  }

  Future<List<Map<String, dynamic>>> _municipiosMin() => _maestroConCache(
        'municipios.json',
        '/maestro/municipios',
        (e) {
          final m = e as Map;
          final codigo = m['id']?.toString();
          final lat = double.tryParse(m['latitud_dec']?.toString() ?? '');
          final lon = double.tryParse(m['longitud_dec']?.toString() ?? '');
          if (codigo == null || lat == null || lon == null) return null;
          return {
            'c': codigo.replaceFirst(RegExp('^id'), ''),
            'a': lat,
            'o': lon,
          };
        },
      );

  Future<List<Map<String, dynamic>>> _estacionesMin() => _maestroConCache(
        'estaciones.json',
        '/valores/climatologicos/inventarioestaciones/todasestaciones',
        (e) {
          final m = e as Map;
          final idema = m['indicativo']?.toString();
          final lat = parseDms(m['latitud']?.toString() ?? '');
          final lon = parseDms(m['longitud']?.toString() ?? '');
          if (idema == null || lat == null || lon == null) return null;
          return {'c': idema, 'a': lat, 'o': lon};
        },
      );

  static const _ttlMaestro = Duration(days: 60);
  Directory? _dirCache;

  Future<Directory?> _cacheDir() async {
    if (_dirCache != null) return _dirCache;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/aemet_cache');
      if (!await d.exists()) await d.create(recursive: true);
      return _dirCache = d;
    } catch (_) {
      return null;
    }
  }

  /// Descarga un maestro de AEMET (lista grande y casi estática), lo reduce a
  /// `{c, a, o}` por entrada y lo guarda en disco. En llamadas siguientes lee
  /// del disco mientras no caduque el TTL.
  Future<List<Map<String, dynamic>>> _maestroConCache(
    String archivo,
    String path,
    Map<String, dynamic>? Function(dynamic) reducir,
  ) async {
    final dir = await _cacheDir();
    final file = dir == null ? null : File('${dir.path}/$archivo');

    if (file != null && await file.exists()) {
      final edad = DateTime.now().difference(await file.lastModified());
      if (edad < _ttlMaestro) {
        try {
          final cache = jsonDecode(await file.readAsString()) as List;
          return cache.cast<Map<String, dynamic>>();
        } catch (_) {}
      }
    }

    final raw = await _fetch(path);
    if (raw is! List) {
      throw Exception('AEMET: formato inesperado en $path');
    }
    final min = <Map<String, dynamic>>[];
    for (final e in raw) {
      final r = reducir(e);
      if (r != null) min.add(r);
    }
    if (file != null && min.isNotEmpty) {
      try {
        await file.writeAsString(jsonEncode(min));
      } catch (_) {}
    }
    return min;
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
