import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/bar.dart';
import '../models/building_height.dart';
import '../models/geo.dart';
import '../models/shadow_map.dart';

/// Todo lo que hace falta de OSM en una zona: bares, edificios y espacio
/// público (calles, plazas, parques).
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

  static const vacia =
      ZonaOsm(bares: [], edificios: [], lineasPublicas: []);
}

/// Un bloque fijo de la rejilla (~555 × 550 m en Barcelona). Las zonas se
/// descargan y se guardan en caché por bloques, así que moverse un poco
/// reutiliza lo ya descargado en vez de pedir otra zona casi igual.
class Tesela {
  final int i; // fila (latitud)
  final int j; // columna (longitud)
  const Tesela(this.i, this.j);

  static const tamLat = 0.005;
  static const tamLon = 0.0066;

  factory Tesela.de(LatLng p) => Tesela(
        (p.latitude / tamLat).floor(),
        (p.longitude / tamLon).floor(),
      );

  String get clave => '${i}_$j';
  double get sur => i * tamLat;
  double get oeste => j * tamLon;
  double get norte => (i + 1) * tamLat;
  double get este => (j + 1) * tamLon;
  LatLng get centro => LatLng(sur + tamLat / 2, oeste + tamLon / 2);

  /// Teselas que cubren la caja [s,w]–[n,e].
  static List<Tesela> cubriendo(double s, double w, double n, double e) {
    final a = Tesela.de(LatLng(s, w)), b = Tesela.de(LatLng(n, e));
    return [
      for (var i = a.i; i <= b.i; i++)
        for (var j = a.j; j <= b.j; j++) Tesela(i, j),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is Tesela && other.i == i && other.j == j;
  @override
  int get hashCode => Object.hash(i, j);
}

/// Zona de "ciudad" (~11 × 11 km) cuyos locales se descargan de una vez y se
/// guardan en el móvil, para que en esa ciudad salgan al instante como en
/// Barcelona (que ya viene empaquetada).
class Region {
  final int i;
  final int j;
  const Region(this.i, this.j);

  static const tamLat = 0.1;
  static const tamLon = 0.13;

  factory Region.de(LatLng p) => Region(
        (p.latitude / tamLat).floor(),
        (p.longitude / tamLon).floor(),
      );

  String get clave => '${i}_$j';
  double get sur => i * tamLat;
  double get oeste => j * tamLon;
  double get norte => (i + 1) * tamLat;
  double get este => (j + 1) * tamLon;

  @override
  bool operator ==(Object other) =>
      other is Region && other.i == i && other.j == j;
  @override
  int get hashCode => Object.hash(i, j);
}

/// Locales empaquetados en la app (assets/data/bares.json, generado con
/// tool/generar_bares.py). Se pintan al instante, sin red.
class BaresEmpaquetados {
  final List<Bar> bares;

  /// Caja cubierta [s, w, n, e]. Fuera de ella solo hay locales de Overpass.
  final List<double> bbox;
  final String generado;

  const BaresEmpaquetados(this.bares, this.bbox, this.generado);

  bool cubre(LatLng p) =>
      bbox.length == 4 &&
      p.latitude >= bbox[0] &&
      p.longitude >= bbox[1] &&
      p.latitude <= bbox[2] &&
      p.longitude <= bbox[3];

  /// La región entera cae dentro de lo empaquetado: no hace falta bajarla.
  bool cubreRegion(Region r) =>
      bbox.length == 4 &&
      r.sur >= bbox[0] &&
      r.oeste >= bbox[1] &&
      r.norte <= bbox[2] &&
      r.este <= bbox[3];

  static Future<BaresEmpaquetados> cargar() async {
    try {
      final txt = await rootBundle.loadString('assets/data/bares.json');
      return await Isolate.run(() {
        final d = jsonDecode(txt) as Map<String, dynamic>;
        return BaresEmpaquetados(
          [
            for (final f in (d['bares'] as List))
              Bar.fromFila((f as List).cast<dynamic>()),
          ],
          [for (final v in (d['bbox'] as List)) (v as num).toDouble()],
          (d['generado'] ?? '').toString(),
        );
      });
    } catch (_) {
      return const BaresEmpaquetados([], [], '');
    }
  }
}

class OsmAreaService {
  OsmAreaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _userAgent = 'terrazeo/2.0 (Flutter)';

  /// Edificios y calles cambian poco: un mes de caché.
  static const Duration _ttlCache = Duration(days: 30);

  /// Si el servidor no ha contestado en este tiempo, se prueba también el
  /// siguiente (sin cancelar el primero). Evita mandar siempre 3 peticiones.
  static const Duration _escalonado = Duration(seconds: 6);

  /// Versión del formato de caché: subirla invalida las cachés viejas.
  static const _versionCache = 'v2';

  static const amenityBares =
      'bar|pub|cafe|restaurant|biergarten|fast_food|ice_cream';
  static const _viasPublicas =
      'footway|path|pedestrian|living_street|steps|residential|service|'
      'unclassified|tertiary|secondary|track|road|cycleway';

  /// Carga [teselas] (caché en disco o Overpass). Devuelve las que han
  /// llegado; si la red falla, las que faltan no aparecen en el resultado.
  /// Lanza solo si no se pudo cargar ninguna.
  Future<Map<Tesela, ZonaOsm>> cargarTeselas(List<Tesela> teselas) async {
    final res = <Tesela, ZonaOsm>{};
    final faltan = <Tesela>[];
    final dir = await _cacheDir();

    for (final t in teselas) {
      final f = dir == null ? null : _fichero(dir, t);
      if (f != null && await f.exists()) {
        final edad = DateTime.now().difference(await f.lastModified());
        if (edad < _ttlCache) {
          try {
            res[t] = await Isolate.run(
                () => _parsearElementos(jsonDecode(f.readAsStringSync())));
            continue;
          } catch (_) {}
        }
      }
      faltan.add(t);
    }
    if (faltan.isEmpty) return res;

    // Una sola petición para la caja que envuelve todas las que faltan.
    final s = faltan.map((t) => t.sur).reduce(math.min);
    final w = faltan.map((t) => t.oeste).reduce(math.min);
    final n = faltan.map((t) => t.norte).reduce(math.max);
    final e = faltan.map((t) => t.este).reduce(math.max);
    final bb = '$s,$w,$n,$e';
    final query = '''
[out:json][timeout:60];
(
  nwr["amenity"~"^($amenityBares)\$"]($bb);
  way["building"]($bb);
  way["highway"~"^($_viasPublicas)\$"]["foot"!~"no|private"]["access"!~"private|no"]($bb);
  way["leisure"~"^(park|garden|common|playground)\$"]($bb);
  way["place"="square"]($bb);
  way["highway"="pedestrian"]["area"="yes"]($bb);
);
out center geom tags;
''';

    final String body;
    final cron = Stopwatch()..start();
    try {
      body = await _overpass(query);
      debugPrint('[osm] ${faltan.length} teselas en ${cron.elapsedMilliseconds} ms '
          '(${body.length ~/ 1024} KB)');
    } catch (e) {
      debugPrint('[osm] Overpass falló tras ${cron.elapsedMilliseconds} ms: $e');
      if (res.isEmpty) rethrow;
      return res;
    }

    // Reparto por teselas + parseo fuera del hilo de la interfaz.
    final claves = [for (final t in faltan) (t.i, t.j)];
    final porTesela = await Isolate.run(() => repartir(body, claves));

    for (final t in faltan) {
      final elementos = porTesela[t.clave] ?? const [];
      if (dir != null) {
        try {
          await _fichero(dir, t).writeAsString(jsonEncode(elementos));
        } catch (_) {}
      }
      res[t] = await Isolate.run(() => _parsearElementos(elementos));
    }
    return res;
  }

  /// Locales de toda una [Region] (una sola consulta, solo locales). Se
  /// guardan en disco con el mismo formato compacto que assets/data/bares.json
  /// y duran [_ttlCache]. Lanza si no hay caché y Overpass falla.
  Future<List<Bar>> cargarRegion(Region r) async {
    final dir = await _cacheDir();
    final f = dir == null
        ? null
        : File('${dir.path}/t${_versionCache}_ciudad_${r.clave}.json');
    if (f != null && await f.exists()) {
      if (DateTime.now().difference(await f.lastModified()) < _ttlCache) {
        try {
          return await Isolate.run(() => [
                for (final fila in jsonDecode(f.readAsStringSync()) as List)
                  Bar.fromFila((fila as List).cast<dynamic>()),
              ]);
        } catch (_) {}
      }
    }

    final query = '[out:json][timeout:120];'
        'nwr["amenity"~"^($amenityBares)\$"]'
        '(${r.sur},${r.oeste},${r.norte},${r.este});'
        'out center tags;';
    final cron = Stopwatch()..start();
    final body = await _overpass(query, limite: const Duration(seconds: 150));
    final filas = await Isolate.run(() => filasDeOverpass(body));
    debugPrint('[osm] ciudad ${r.clave}: ${filas.length} locales en '
        '${cron.elapsedMilliseconds} ms');
    if (f != null) {
      try {
        await f.writeAsString(jsonEncode(filas));
      } catch (_) {}
    }
    return [for (final fila in filas) Bar.fromFila(fila)];
  }

  /// Respuesta de Overpass (locales) → filas compactas
  /// `[osmId, lat, lon, nombre, amenity, terraza]`.
  @visibleForTesting
  static List<List<dynamic>> filasDeOverpass(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final filas = <List<dynamic>>[];
    for (final raw in (data['elements'] as List? ?? const [])) {
      final el = raw as Map<String, dynamic>;
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final c = el['center'] as Map?;
      final lat = (el['lat'] ?? c?['lat']) as num?;
      final lon = (el['lon'] ?? c?['lon']) as num?;
      if (lat == null || lon == null) continue;
      final amenity = (tags['amenity'] ?? 'bar').toString();
      final outdoor = (tags['outdoor_seating'] ?? '').toString().toLowerCase();
      filas.add([
        '${el['type']}/${el['id']}',
        lat.toDouble(),
        lon.toDouble(),
        (tags['name'] ?? '').toString(),
        amenity,
        outdoor == 'yes' || outdoor == 'terrace' || amenity == 'biergarten'
            ? 1
            : 0,
      ]);
    }
    return filas;
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

  // --- Parseo (se ejecuta en un isolate) ----------------------------------

  /// Reparte los elementos de una respuesta de Overpass entre las teselas
  /// pedidas, según su centro. Así cada elemento queda en una sola tesela
  /// (sin duplicados) y cada tesela se puede guardar en caché por separado.
  @visibleForTesting
  static Map<String, List<dynamic>> repartir(
      String body, List<(int, int)> claves) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final salida = {for (final (i, j) in claves) '${i}_$j': <dynamic>[]};
    for (final el in (data['elements'] as List? ?? const [])) {
      final m = el as Map<String, dynamic>;
      // Con `out geom` los ways traen `bounds` + `geometry` pero no `center`:
      // se calcula aquí (sirve para repartir y para los locales que son ways).
      final bnd = m['bounds'] as Map?;
      if (m['center'] == null && m['lat'] == null && bnd != null) {
        m['center'] = {
          'lat': ((bnd['minlat'] as num) + (bnd['maxlat'] as num)) / 2,
          'lon': ((bnd['minlon'] as num) + (bnd['maxlon'] as num)) / 2,
        };
      }
      final c = m['center'] as Map?;
      final lat = (m['lat'] ?? c?['lat']) as num?;
      final lon = (m['lon'] ?? c?['lon']) as num?;
      if (lat == null || lon == null) continue;
      final t = Tesela.de(LatLng(lat.toDouble(), lon.toDouble()));
      salida[t.clave]?.add(m);
    }
    return salida;
  }

  static final _reBares = RegExp('^($amenityBares)\$');

  static ZonaOsm _parsearElementos(List<dynamic> elements) {
    final bares = <Bar>[];
    final edificiosCrudos =
        <({List<LatLng> ring, Map<String, dynamic> tags})>[];
    final lineas = <List<LatLng>>[];

    for (final raw in elements) {
      final el = (raw as Map).cast<String, dynamic>();
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};

      final amenity = (tags['amenity'] ?? '').toString();
      if (_reBares.hasMatch(amenity)) {
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

  // --- Overpass (escalonado) + caché en disco -----------------------------

  /// Pide [query] al primer servidor; si tarda más de [_escalonado], también
  /// al siguiente, y así. Gana la primera respuesta válida.
  Future<String> _overpass(String query,
      {Duration limite = const Duration(seconds: 60)}) {
    final completer = Completer<String>();
    final errores = <String>[];
    var lanzados = 0, terminados = 0;
    Timer? siguiente;

    void lanzar() {
      if (completer.isCompleted || lanzados >= _endpoints.length) return;
      final endpoint = _endpoints[lanzados++];
      siguiente?.cancel();
      siguiente = Timer(_escalonado, lanzar);

      void fallo(String msg) {
        errores.add(msg);
        terminados++;
        if (completer.isCompleted) return;
        if (lanzados < _endpoints.length) {
          lanzar(); // no esperes al temporizador si este ya ha fallado
        } else if (terminados == lanzados) {
          completer.completeError(
              Exception('Overpass no disponible: ${errores.join(' | ')}'));
        }
      }

      _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'User-Agent': _userAgent,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'data': query},
          )
          .timeout(limite)
          .then((resp) {
        if (completer.isCompleted) return;
        if (resp.statusCode == 200) {
          terminados++;
          siguiente?.cancel();
          completer.complete(utf8.decode(resp.bodyBytes));
        } else {
          fallo('HTTP ${resp.statusCode} $endpoint');
        }
      }).catchError((Object e) {
        fallo('$e ($endpoint)');
      });
    }

    lanzar();
    return completer.future.whenComplete(() => siguiente?.cancel());
  }

  Directory? _dirCache;

  Future<Directory?> _cacheDir() async {
    if (_dirCache != null) return _dirCache;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/overpass_cache');
      if (!await d.exists()) await d.create(recursive: true);
      // Borra cachés de formatos anteriores (zonas circulares, v1…).
      unawaited(d
          .list()
          .where((f) => !f.path.split('/').last.startsWith('t$_versionCache'))
          .forEach((f) => f.delete().catchError((_) => f))
          .catchError((_) {}));
      return _dirCache = d;
    } catch (_) {
      return null;
    }
  }

  File _fichero(Directory dir, Tesela t) =>
      File('${dir.path}/t${_versionCache}_${t.clave}.json');

  void dispose() => _client.close();
}
