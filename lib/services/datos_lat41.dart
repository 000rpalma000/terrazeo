import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' as http;

/// Datos propios de Lat41 Lab: edificios, calles y locales de OpenStreetMap
/// ya cortados en las mismas cuadrículas que usa la app, servidos desde
/// Cloudflare (`data.lat41lab.com`). En las zonas cubiertas sustituyen a
/// Overpass: llegan en ~100 ms en vez de 30-70 s y no dependen de un
/// servicio público saturado. Formato en `tool/datos/FORMATO.md`.
class DatosLat41 {
  DatosLat41(this._client, {String? base, this.directorio})
      : base = base ?? _baseDefinida;

  static const _baseDefinida = String.fromEnvironment('DATOS_URL',
      defaultValue: 'https://data.lat41lab.com/osm/v1');

  final http.Client _client;
  final String base;

  /// Carpeta donde guardar el manifiesto (para arrancar sin red).
  final Future<Directory?> Function()? directorio;

  static const _vigenciaManifiesto = Duration(hours: 24);

  Future<Manifiesto?>? _manifiesto;

  /// El manifiesto vigente: del disco si es de hoy, si no de la red (y si la
  /// red falla, el último guardado aunque sea viejo). `null` si no hay
  /// ninguno: entonces todo va por Overpass.
  Future<Manifiesto?> manifiesto() => _manifiesto ??= _cargarManifiesto()
    ..then((m) {
      if (m == null) _manifiesto = null; // se reintenta la próxima vez
    });

  Future<Manifiesto?> _cargarManifiesto() async {
    final dir = await directorio?.call();
    final f = dir == null ? null : File('${dir.path}/lat41_manifest.json');
    String? guardado;
    if (f != null && await f.exists()) {
      try {
        guardado = await f.readAsString();
        if (DateTime.now().difference(await f.lastModified()) <
            _vigenciaManifiesto) {
          return Manifiesto.parse(guardado);
        }
      } catch (_) {}
    }
    try {
      final r = await _client
          .get(Uri.parse('$base/manifest.json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final txt = utf8.decode(r.bodyBytes);
        final m = Manifiesto.parse(txt);
        if (f != null) {
          try {
            await f.writeAsString(txt);
          } catch (_) {}
        }
        return m;
      }
      debugPrint('[lat41] manifiesto: HTTP ${r.statusCode}');
    } catch (e) {
      debugPrint('[lat41] manifiesto no disponible: $e');
    }
    if (guardado != null) {
      try {
        return Manifiesto.parse(guardado);
      } catch (_) {}
    }
    return null;
  }

  /// Cuerpo de la cuadrícula `i_j`, o lanza si no se puede descargar.
  Future<String> cuadricula(String clave) async {
    final r = await _client
        .get(Uri.parse('$base/$clave.json'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw HttpException('lat41 $clave: HTTP ${r.statusCode}');
    }
    return utf8.decode(r.bodyBytes);
  }

  /// Convierte una cuadrícula al formato de elementos de Overpass
  /// (`type`, `id`, `tags`, `nodes`, `geometry`, `bounds`, `lat`/`lon`), el
  /// que ya entienden los procesadores de la app. Con [vias], solo se
  /// quedan las vías de esos tipos.
  static List<Map<String, dynamic>> aElementos(String cuerpo,
      {Set<String>? vias}) {
    final d = jsonDecode(cuerpo) as Map<String, dynamic>;
    final out = <Map<String, dynamic>>[];
    for (final w in (d['w'] as List? ?? const [])) {
      final l = w as List;
      final tags = (l[2] as Map).cast<String, dynamic>();
      if (l[1] == 'h' && vias != null && !vias.contains(tags['highway'])) {
        continue;
      }
      final c = (l[4] as List).cast<int>();
      var lat = c[0], lon = c[1];
      final geom = <Map<String, double>>[
        {'lat': lat / 1e6, 'lon': lon / 1e6},
      ];
      var minLat = lat, maxLat = lat, minLon = lon, maxLon = lon;
      for (var k = 2; k + 1 < c.length; k += 2) {
        lat += c[k];
        lon += c[k + 1];
        geom.add({'lat': lat / 1e6, 'lon': lon / 1e6});
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      }
      out.add({
        'type': 'way',
        'id': l[0],
        'tags': tags,
        if (l[3] is List) 'nodes': l[3],
        'geometry': geom,
        'bounds': {
          'minlat': minLat / 1e6,
          'minlon': minLon / 1e6,
          'maxlat': maxLat / 1e6,
          'maxlon': maxLon / 1e6,
        },
      });
    }
    for (final n in (d['n'] as List? ?? const [])) {
      final f = n as List;
      final partes = (f[0] as String).split('/');
      out.add({
        'type': partes[0],
        'id': int.parse(partes[1]),
        'lat': (f[1] as num).toDouble(),
        'lon': (f[2] as num).toDouble(),
        'tags': {
          if ((f[3] as String).isNotEmpty) 'name': f[3],
          'amenity': f[4],
          if (f[5] == 1) 'outdoor_seating': 'yes',
        },
      });
    }
    return out;
  }
}

/// Qué cuadrículas cubren los datos propios.
class Manifiesto {
  Manifiesto(this.version, this.coberturas, this.huellas, this.datosOsm);

  final int version;
  final List<({int i0, int i1, int j0, int j1})> coberturas;

  /// Cuadrículas con datos → huella del archivo.
  final Map<String, String> huellas;
  final String datosOsm;

  @visibleForTesting
  static Manifiesto parse(String txt) {
    final d = jsonDecode(txt) as Map<String, dynamic>;
    return Manifiesto(
      (d['v'] as num).toInt(),
      [
        for (final c in (d['cobertura'] as List))
          (
            i0: (c['i0'] as num).toInt(),
            i1: (c['i1'] as num).toInt(),
            j0: (c['j0'] as num).toInt(),
            j1: (c['j1'] as num).toInt(),
          ),
      ],
      (d['cuadriculas'] as Map).cast<String, String>(),
      (d['datos_osm'] ?? '').toString(),
    );
  }

  /// La cuadrícula (i, j) está dentro de la zona cubierta.
  bool cubre(int i, int j) =>
      coberturas.any((c) => i >= c.i0 && i <= c.i1 && j >= c.j0 && j <= c.j1);

  /// Cubierta y sin nada dentro (mar, montaña): no hay que pedirla.
  bool vacia(int i, int j) => cubre(i, j) && !huellas.containsKey('${i}_$j');
}
