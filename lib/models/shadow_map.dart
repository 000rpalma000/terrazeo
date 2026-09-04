import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Planta de un edificio con su altura (de OSM).
class BuildingFootprint {
  final List<LatLng> ring;
  final double heightM;

  const BuildingFootprint({required this.ring, required this.heightM});
}

/// Polígono de sombra ya proyectado sobre el suelo para un instante concreto.
/// Guarda su caja envolvente para descartar rápido.
class ShadowPolygon {
  final List<LatLng> ring;
  final double minLat, maxLat, minLon, maxLon;

  ShadowPolygon(this.ring)
      : minLat = ring.map((p) => p.latitude).reduce(math.min),
        maxLat = ring.map((p) => p.latitude).reduce(math.max),
        minLon = ring.map((p) => p.longitude).reduce(math.min),
        maxLon = ring.map((p) => p.longitude).reduce(math.max);

  bool bboxContiene(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLon &&
      p.longitude <= maxLon;
}

/// Conjunto de sombras de un área para un instante y una posición del sol.
///
/// Las sombras se guardan como muchos polígonos convexos pequeños (la planta de
/// cada edificio + un cuadrilátero por arista, proyectado en la dirección
/// opuesta al sol). Un punto está en sombra si cae dentro de cualquiera de
/// ellos. Un índice espacial (rejilla) evita recorrerlos todos.
class ShadowMap {
  final DateTime instante;
  final double sunAzimuthDeg;
  final double sunElevationDeg;
  final List<ShadowPolygon> polygons;

  /// Lado de celda de la rejilla, en grados (~65 m).
  static const double _cell = 0.0006;
  final Map<int, List<ShadowPolygon>> _grid = {};

  ShadowMap({
    required this.instante,
    required this.sunAzimuthDeg,
    required this.sunElevationDeg,
    required this.polygons,
  }) {
    for (final poly in polygons) {
      final i0 = (poly.minLat / _cell).floor();
      final i1 = (poly.maxLat / _cell).floor();
      final j0 = (poly.minLon / _cell).floor();
      final j1 = (poly.maxLon / _cell).floor();
      for (var i = i0; i <= i1; i++) {
        for (var j = j0; j <= j1; j++) {
          (_grid[_key(i, j)] ??= <ShadowPolygon>[]).add(poly);
        }
      }
    }
  }

  static int _key(int i, int j) => i * 4000000 + (j + 300000);

  /// De noche (o con el sol casi en el horizonte) no hay exposición solar.
  bool get esDeNoche => sunElevationDeg <= 3;

  bool enSombra(LatLng p) {
    if (esDeNoche) return true;
    final celda = _grid[_key(
      (p.latitude / _cell).floor(),
      (p.longitude / _cell).floor(),
    )];
    if (celda == null) return false;
    for (final poly in celda) {
      if (poly.bboxContiene(p) && Geo.dentroDePoligono(p, poly.ring)) {
        return true;
      }
    }
    return false;
  }

  /// Fracción de una lista de puntos de muestreo que cae en sombra (0..1).
  double fraccionEnSombra(List<LatLng> muestras) {
    if (muestras.isEmpty) return esDeNoche ? 1 : 0;
    var enSombraCount = 0;
    for (final m in muestras) {
      if (enSombra(m)) enSombraCount++;
    }
    return enSombraCount / muestras.length;
  }

  /// Mapa "sin sombras" para un instante nocturno.
  factory ShadowMap.noche(DateTime instante) => ShadowMap(
        instante: instante,
        sunAzimuthDeg: 0,
        sunElevationDeg: -90,
        polygons: const [],
      );
}
