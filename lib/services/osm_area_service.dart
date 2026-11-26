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
import '../models/indice_espacial.dart';
import '../models/shadow_map.dart';
import 'datos_lat41.dart';
import 'overpass.dart';

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
/// tool/datos/generar_teselas.py). Se pintan al instante, sin red.
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

  /// La caja [s, w, n, e] cae entera dentro de lo empaquetado.
  bool cubreZona(double s, double w, double n, double e) =>
      bbox.length == 4 &&
      s >= bbox[0] &&
      w >= bbox[1] &&
      n <= bbox[2] &&
      e <= bbox[3];

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
  late final _op = Overpass(_client, userAgent: _userAgent);
  late final _datos = DatosLat41(_client, directorio: _cacheDir);

  static const _userAgent = 'terrazeo/2.0 (Flutter)';

  /// Edificios y calles cambian poco: un mes de caché.
  static const Duration _ttlCache = Duration(days: 30);

  /// Versión del formato de caché: subirla invalida las cachés viejas.
  static const _versionCache = 'v2';

  static const amenityBares =
      'bar|pub|cafe|restaurant|biergarten|fast_food|ice_cream';
  static const _viasPublicas =
      'footway|path|pedestrian|living_street|steps|residential|service|'
      'unclassified|tertiary|secondary|track|road|cycleway';

  /// Carga [teselas]: primero las guardadas en disco y después, de una vez,
  /// las que falten desde Overpass. Si la red falla, las que faltan no
  /// aparecen en el resultado. Lanza solo si no se pudo cargar ninguna.
  Future<Map<Tesela, ZonaOsm>> cargarTeselas(List<Tesela> teselas) async {
    final res = await leerGuardadas(teselas);
    final faltan = [
      for (final t in teselas)
        if (!res.containsKey(t)) t,
    ];
    if (faltan.isEmpty) return res;
    try {
      res.addAll(await descargarTeselas(faltan));
    } catch (_) {
      if (res.isEmpty) rethrow;
    }
    return res;
  }

  /// Las [teselas] que hay guardadas en disco y no han caducado. No usa la
  /// red: es rápido y sirve para pintar lo conocido mientras llega el resto.
  /// Todas se procesan en un mismo isolate (arrancar uno por tesela cuesta
  /// más de lo que se gana).
  Future<Map<Tesela, ZonaOsm>> leerGuardadas(List<Tesela> teselas) async {
    final dir = await _cacheDir();
    if (dir == null) return {};
    final vigentes = <Tesela>[];
    for (final t in teselas) {
      final f = _fichero(dir, t);
      try {
        if (!await f.exists()) continue;
        final edad = DateTime.now().difference(await f.lastModified());
        if (edad < _ttlCache) vigentes.add(t);
      } catch (_) {}
    }
    if (vigentes.isEmpty) return {};
    final zonas =
        await _leerTeselas([for (final t in vigentes) _fichero(dir, t).path]);
    return {
      for (var k = 0; k < vigentes.length; k++)
        if (zonas[k] != null) vigentes[k]: zonas[k]!,
    };
  }

  /// Lee y procesa teselas guardadas en otro isolate (`null` si alguna está
  /// dañada). Es estática a propósito: así el cierre que viaja al isolate solo
  /// lleva las rutas (un método de instancia arrastraría el servicio y su
  /// cliente HTTP, que no se pueden enviar).
  static Future<List<ZonaOsm?>> _leerTeselas(List<String> rutas) =>
      Isolate.run(() => [
            for (final ruta in rutas)
              () {
                try {
                  return _parsearElementos(
                      jsonDecode(File(ruta).readAsStringSync()));
                } catch (_) {
                  return null;
                }
              }(),
          ]);

  /// Descarga [faltan] y las guarda en disco: las de las zonas cubiertas
  /// por los datos propios (Barcelona), de `data.lat41lab.com`; el resto, o
  /// si eso falla, de Overpass. Lanza si no llega ninguna.
  Future<Map<Tesela, ZonaOsm>> descargarTeselas(List<Tesela> faltan) async {
    if (faltan.isEmpty) return {};
    final m = await _datos.manifiesto();
    final propias = [
      if (m != null)
        for (final t in faltan)
          if (m.cubre(t.i, t.j)) t,
    ];
    if (propias.isEmpty) return _descargarOverpass(faltan);
    final res = await _descargarPropias(propias, m!);
    final resto = [
      for (final t in faltan)
        if (!res.containsKey(t)) t,
    ];
    if (resto.isEmpty) return res;
    try {
      res.addAll(await _descargarOverpass(resto));
    } catch (_) {
      if (res.isEmpty) rethrow;
    }
    return res;
  }

  /// Vías que cuentan como espacio público (las mismas que se piden a
  /// Overpass).
  static final _viasPublicasSet = _viasPublicas.split('|').toSet();

  /// Cuadrículas de los datos propios, en paralelo. Las que fallan no
  /// aparecen en el resultado (irán por Overpass).
  Future<Map<Tesela, ZonaOsm>> _descargarPropias(
      List<Tesela> ts, Manifiesto m) async {
    final dir = await _cacheDir();
    final res = <Tesela, ZonaOsm>{};
    final cron = Stopwatch()..start();
    await Future.wait([
      for (final t in ts)
        () async {
          try {
            final cuerpo = m.vacia(t.i, t.j) ? null : await _datos.cuadricula(t.clave);
            final (json, zona) = await _convertirEnIsolate(cuerpo);
            res[t] = zona;
            if (dir != null) {
              try {
                await _fichero(dir, t).writeAsString(json);
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('[lat41] ${t.clave}: $e');
          }
        }(),
    ]);
    debugPrint('[lat41] ${res.length}/${ts.length} cuadrículas en '
        '${cron.elapsedMilliseconds} ms');
    return res;
  }

  /// Convierte una cuadrícula propia (o una vacía, con `null`) a elementos
  /// de Overpass, la procesa y devuelve también el JSON para la caché.
  static Future<(String, ZonaOsm)> _convertirEnIsolate(String? cuerpo) =>
      Isolate.run(() {
        final els = cuerpo == null
            ? const <Map<String, dynamic>>[]
            : DatosLat41.aElementos(cuerpo, vias: _viasPublicasSet);
        return (jsonEncode(els), _parsearElementos(els));
      });

  /// Descarga [faltan] de Overpass en una sola petición (la caja que las
  /// envuelve) y las guarda en disco. Lanza si Overpass falla.
  Future<Map<Tesela, ZonaOsm>> _descargarOverpass(List<Tesela> faltan) async {
    final res = <Tesela, ZonaOsm>{};
    if (faltan.isEmpty) return res;
    final dir = await _cacheDir();

    // Una sola petición para la caja que envuelve todas las que faltan.
    final s = faltan.map((t) => t.sur).reduce(math.min);
    final w = faltan.map((t) => t.oeste).reduce(math.min);
    final n = faltan.map((t) => t.norte).reduce(math.max);
    final e = faltan.map((t) => t.este).reduce(math.max);
    final bb = '$s,$w,$n,$e';
    final query = '''
[out:json][timeout:25];
(
  nwr["amenity"~"^($amenityBares)\$"]($bb);
  way["building"]($bb);
  way["highway"~"^($_viasPublicas)\$"]["foot"!~"no|private"]["access"!~"private|no"]($bb);
  way["leisure"~"^(park|garden|common|playground)\$"]($bb);
  way["place"="square"]($bb);
  way["highway"="pedestrian"]["area"="yes"]($bb);
);
out center geom tags qt;
''';

    final String body;
    final cron = Stopwatch()..start();
    try {
      body = await _overpass(query);
      debugPrint('[osm] ${faltan.length} teselas en ${cron.elapsedMilliseconds} ms '
          '(${body.length ~/ 1024} KB)');
    } catch (e) {
      debugPrint('[osm] Overpass falló tras ${cron.elapsedMilliseconds} ms: $e');
      rethrow;
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

  /// Si los datos propios cubren toda la caja: entonces sus locales llegan
  /// con las cuadrículas y no hace falta pedir la ciudad a Overpass.
  Future<bool> datosPropiosCubren(
      double s, double w, double n, double e) async {
    final m = await _datos.manifiesto();
    if (m == null) return false;
    final a = Tesela.de(LatLng(s, w)), b = Tesela.de(LatLng(n, e));
    for (var i = a.i; i <= b.i; i++) {
      for (var j = a.j; j <= b.j; j++) {
        if (!m.cubre(i, j)) return false;
      }
    }
    return true;
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

    final query = '[out:json][timeout:60];'
        'nwr["amenity"~"^($amenityBares)\$"]'
        '(${r.sur},${r.oeste},${r.norte},${r.este});'
        'out center tags;';
    final cron = Stopwatch()..start();
    // Cliente propio para poder cortarla (ver [cancelarRegion]).
    final cliente = _clienteRegion = http.Client();
    final String body;
    try {
      // En segundo plano y se corta si hacen falta edificios: puede esperar
      // más que las cuadrículas.
      body = await _overpass(query,
          limite: const Duration(seconds: 60),
          total: const Duration(seconds: 120),
          cliente: cliente);
    } finally {
      cliente.close();
      if (identical(_clienteRegion, cliente)) _clienteRegion = null;
    }
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
  /// `[osmId, lat, lon, nombre, amenity, terraza, horario]` (ver
  /// tool/datos/FORMATO.md; terraza 1 confirmada, -1 no, 0 sin confirmar).
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
      final terraza =
          Terraza.deEtiqueta(tags['outdoor_seating']?.toString(), amenity);
      filas.add([
        '${el['type']}/${el['id']}',
        lat.toDouble(),
        lon.toDouble(),
        (tags['name'] ?? '').toString(),
        amenity,
        switch (terraza) {
          Terraza.confirmada => 1,
          Terraza.no => -1,
          Terraza.sinConfirmar => 0,
        },
        (tags['opening_hours'] ?? '').toString().trim(),
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
    return ajustarConIndices(
        p, IndiceEdificios(edificios), IndiceSegmentos(lineas),
        maxM: maxM);
  }

  /// Igual que [ajustarAEspacioPublico] pero con los edificios y las vías ya
  /// indexados: solo mira lo que hay en las celdas de alrededor de [p], en vez
  /// de recorrerlo todo por cada punto.
  static LatLng? ajustarConIndices(
    LatLng p,
    IndiceEdificios edificios,
    IndiceSegmentos vias, {
    double maxM = 60,
  }) {
    if (!edificios.dentroDeAlguno(p)) return p;
    LatLng? mejor;
    var mejorD = maxM;
    for (final (a, b) in vias.cerca(p, maxM)) {
      final c = Geo.puntoMasCercanoEnSegmento(p, a, b);
      final d = Geo.distancia(p, c);
      if (d < mejorD && !edificios.dentroDeAlguno(c)) {
        mejorD = d;
        mejor = c;
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

  /// El mismo procesado que usa la app, para las pruebas con datos reales.
  @visibleForTesting
  static ZonaOsm parsearParaPruebas(List<dynamic> elementos) =>
      _parsearElementos(elementos);

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

  // --- Overpass + caché en disco -----------------------------------------

  http.Client? _clienteRegion;

  /// Corta la descarga de los locales de una región, si hay una en marcha,
  /// para dejar Overpass libre a los edificios. Esa descarga falla y se
  /// reintenta más adelante.
  void cancelarRegion() {
    final c = _clienteRegion;
    if (c == null) return;
    debugPrint('[osm] corto la descarga de la ciudad: hacen falta edificios');
    _clienteRegion = null;
    c.close();
  }

  /// Consulta Overpass con reintentos (ver [Overpass]).
  Future<String> _overpass(String query,
          {Duration? limite, Duration? total, http.Client? cliente}) =>
      _op.consultar(query, cliente: cliente, limite: limite, total: total);

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
