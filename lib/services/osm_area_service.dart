import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/bar.dart';
import '../models/building_height.dart';
import '../models/geo.dart';
import '../models/shadow_map.dart';

/// Todo lo que hace falta de OSM en una zona: bares, edificios y espacio
/// público (calles, plazas, parques) — en una sola consulta a Overpass.
class ZonaOsm {
  final List<Bar> bares;
  final List<BuildingFootprint> edificios;

  /// Geometrías por las que se puede estar de pie (para "mover al espacio
  /// abierto más cercano").
  final List<List<LatLng>> lineasPublicas;

  const ZonaOsm({
    required this.bares,
    required this.edificios,
    required this.lineasPublicas,
  });
}

class OsmAreaService {
  OsmAreaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoints = [
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _userAgent = 'places_barcelona/1.0 (Flutter)';
  static const Duration _ttlCache = Duration(days: 7);

  static const _amenityBares =
      'bar|pub|cafe|restaurant|biergarten|fast_food|ice_cream';
  static const _viasPublicas =
      'footway|path|pedestrian|living_street|steps|residential|service|'
      'unclassified|tertiary|secondary|track|road|cycleway';

  Future<ZonaOsm> cargarZona(
    LatLng centro, {
    int radioBaresM = 300,
    int radioContextoM = 420,
  }) async {
    final lat = centro.latitude, lon = centro.longitude;
    final query = '''
[out:json][timeout:30];
(
  nwr["amenity"~"^($_amenityBares)\$"](around:$radioBaresM,$lat,$lon);
  way["building"](around:$radioContextoM,$lat,$lon);
  way["highway"~"^($_viasPublicas)\$"]["foot"!~"no|private"]["access"!~"private|no"](around:$radioContextoM,$lat,$lon);
  way["leisure"~"^(park|garden|common|playground)\$"](around:$radioContextoM,$lat,$lon);
  way["place"="square"](around:$radioContextoM,$lat,$lon);
  way["highway"="pedestrian"]["area"="yes"](around:$radioContextoM,$lat,$lon);
);
out center geom tags;
''';

    final data = await _fetchConCache(
      query,
      _clave(centro, radioBaresM, radioContextoM),
    );
    final elements =
        (data['elements'] as List? ?? const []).cast<Map<String, dynamic>>();

    final bares = <Bar>[];
    final edificiosCrudos =
        <({List<LatLng> ring, Map<String, dynamic> tags})>[];
    final lineas = <List<LatLng>>[];

    for (final el in elements) {
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};

      final amenity = (tags['amenity'] ?? '').toString();
      if (RegExp('^($_amenityBares)\$').hasMatch(amenity)) {
        final tieneCoord = el['lat'] != null ||
            (el['center'] is Map && el['center']['lat'] != null);
        if (tieneCoord) {
          try {
            bares.add(Bar.fromOverpass(el));
          } catch (_) {}
        }
        continue;
      }

      if (el['type'] != 'way') continue;
      final geom = (el['geometry'] as List?)?.cast<Map>();
      if (geom == null || geom.length < 2) continue;
      final pts = [
        for (final g in geom)
          LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
      ];

      if (tags.containsKey('building')) {
        if (pts.length >= 3) edificiosCrudos.add((ring: pts, tags: tags));
      } else {
        lineas.add(pts);
      }
    }

    final estimador = BuildingHeightEstimator()
      ..calibrar(edificiosCrudos.map((e) => e.tags));
    final edificios = [
      for (final e in edificiosCrudos)
        BuildingFootprint(ring: e.ring, heightM: estimador.estimar(e.tags)),
    ];

    return ZonaOsm(bares: bares, edificios: edificios, lineasPublicas: lineas);
  }

  /// Si [p] cae dentro de un edificio, devuelve el punto público más cercano
  /// (≤ [maxM] m). Si no está sobre un edificio, devuelve [p] (mismo objeto).
  /// `null` si está en un edificio y no hay espacio público cerca.
  ///
  /// Barato: proyecta [p] sobre cada segmento de vía (con descarte por caja
  /// envolvente), sin muestrear.
  static LatLng? ajustarAEspacioPublico(
    LatLng p,
    List<BuildingFootprint> edificios,
    List<List<LatLng>> lineas, {
    double maxM = 60,
  }) {
    if (!edificios.any((b) => Geo.dentroDePoligono(p, b.ring))) return p;

    final tol = maxM / 111320.0; // ~grados
    LatLng? mejor;
    var mejorD = maxM;
    for (final linea in lineas) {
      for (var i = 0; i < linea.length - 1; i++) {
        final a = linea[i], b = linea[i + 1];
        // descarte rápido por caja del segmento ampliada
        if (p.latitude < math.min(a.latitude, b.latitude) - tol ||
            p.latitude > math.max(a.latitude, b.latitude) + tol ||
            p.longitude < math.min(a.longitude, b.longitude) - tol ||
            p.longitude > math.max(a.longitude, b.longitude) + tol) {
          continue;
        }
        final c = Geo.puntoMasCercanoEnSegmento(p, a, b);
        final d = Geo.distancia(p, c);
        if (d < mejorD && !edificios.any((e) => Geo.dentroDePoligono(c, e.ring))) {
          mejorD = d;
          mejor = c;
        }
      }
    }
    return mejor;
  }

  // --- Overpass (carrera) + caché en disco --------------------------------

  Future<Map<String, dynamic>> _overpassRace(String query) async {
    final completer = Completer<Map<String, dynamic>>();
    final errores = <String>[];
    var pendientes = _endpoints.length;

    void fallo(String msg) {
      errores.add(msg);
      if (--pendientes == 0 && !completer.isCompleted) {
        completer.completeError(
          Exception('Overpass no disponible: ${errores.join(' | ')}'),
        );
      }
    }

    for (final endpoint in _endpoints) {
      _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'User-Agent': _userAgent,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 45))
          .then((resp) {
        if (completer.isCompleted) return;
        if (resp.statusCode == 200) {
          try {
            completer.complete(
              jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>,
            );
          } catch (e) {
            fallo('json $endpoint: $e');
          }
        } else {
          fallo('HTTP ${resp.statusCode} $endpoint');
        }
      }).catchError((Object e) {
        if (!completer.isCompleted) fallo('$e ($endpoint)');
      });
    }

    return completer.future
        .timeout(const Duration(seconds: 50), onTimeout: () {
      throw Exception('Overpass no respondió a tiempo');
    });
  }

  Directory? _dirCache;

  Future<Directory?> _cacheDir() async {
    if (_dirCache != null) return _dirCache;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/overpass_cache');
      if (!await d.exists()) await d.create(recursive: true);
      return _dirCache = d;
    } catch (_) {
      return null;
    }
  }

  String _clave(LatLng p, int rB, int rC) {
    final q = '${(p.latitude / 0.0025).round()}_'
        '${(p.longitude / 0.0025).round()}_${rB}_$rC';
    return 'z${q.hashCode}';
  }

  Future<Map<String, dynamic>> _fetchConCache(String query, String clave) async {
    final dir = await _cacheDir();
    final file = dir == null ? null : File('${dir.path}/$clave.json');
    if (file != null && await file.exists()) {
      if (DateTime.now().difference(await file.lastModified()) < _ttlCache) {
        try {
          return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
    final data = await _overpassRace(query);
    if (file != null) {
      try {
        await file.writeAsString(jsonEncode(data));
      } catch (_) {}
    }
    return data;
  }

  void dispose() => _client.close();
}
