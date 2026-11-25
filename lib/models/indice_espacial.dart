import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'shadow_map.dart';

/// Rejilla regular (~55 m de lado) para encontrar rápido qué hay cerca de un
/// punto sin recorrer todos los elementos. Cada elemento se apunta en todas
/// las celdas que toca su caja envolvente.
class _Rejilla<T> {
  static const double celda = 0.0005; // grados (~55 m en latitud)
  final Map<int, List<T>> _celdas = {};

  static int _i(double lat) => (lat / celda).floor();
  static int _j(double lon) => (lon / celda).floor();
  // j ∈ [-360000, 360000] → j + 400000 cabe en 6 cifras.
  static int _k(int i, int j) => i * 1000000 + (j + 400000);

  void poner(T e, double minLat, double minLon, double maxLat, double maxLon) {
    for (var i = _i(minLat); i <= _i(maxLat); i++) {
      for (var j = _j(minLon); j <= _j(maxLon); j++) {
        (_celdas[_k(i, j)] ??= <T>[]).add(e);
      }
    }
  }

  List<T>? en(LatLng p) => _celdas[_k(_i(p.latitude), _j(p.longitude))];

  /// Elementos de las celdas que tocan la caja de [radioM] alrededor de [p].
  /// Puede repetir elementos (si ocupan varias celdas).
  Iterable<T> cerca(LatLng p, double radioM) sync* {
    final dLat = radioM / 111320.0;
    final dLon =
        radioM / (111320.0 * math.cos(p.latitude * math.pi / 180).abs());
    for (var i = _i(p.latitude - dLat); i <= _i(p.latitude + dLat); i++) {
      for (var j = _j(p.longitude - dLon); j <= _j(p.longitude + dLon); j++) {
        final l = _celdas[_k(i, j)];
        if (l != null) yield* l;
      }
    }
  }
}

class _Caja {
  final BuildingFootprint e;
  final double minLat, maxLat, minLon, maxLon;

  _Caja(this.e, this.minLat, this.maxLat, this.minLon, this.maxLon);

  factory _Caja.de(BuildingFootprint e) {
    var minLat = e.ring.first.latitude, maxLat = minLat;
    var minLon = e.ring.first.longitude, maxLon = minLon;
    for (final p in e.ring) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return _Caja(e, minLat, maxLat, minLon, maxLon);
  }

  bool contiene(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLon &&
      p.longitude <= maxLon;
}

/// Índice espacial de plantas de edificios: "¿en qué edificio cae este
/// punto?" mirando solo los de su celda.
class IndiceEdificios {
  IndiceEdificios(Iterable<BuildingFootprint> edificios) {
    for (final e in edificios) {
      if (e.ring.length < 3) continue;
      final c = _Caja.de(e);
      _rejilla.poner(c, c.minLat, c.minLon, c.maxLat, c.maxLon);
      n++;
    }
  }

  static final vacio = IndiceEdificios(const []);

  final _rejilla = _Rejilla<_Caja>();

  /// Edificios indexados.
  int n = 0;

  /// Un edificio de al menos [alturaMinM] que contiene [p], o `null`.
  BuildingFootprint? edificioEn(LatLng p, {double alturaMinM = 0}) {
    final l = _rejilla.en(p);
    if (l == null) return null;
    for (final c in l) {
      if (c.e.heightM < alturaMinM) continue;
      if (c.contiene(p) && Geo.dentroDePoligono(p, c.e.ring)) return c.e;
    }
    return null;
  }

  bool dentroDeAlguno(LatLng p) => edificioEn(p) != null;
}

/// Índice espacial de tramos (segmentos) de vías y espacios públicos.
class IndiceSegmentos {
  IndiceSegmentos(Iterable<List<LatLng>> lineas) {
    for (final l in lineas) {
      for (var k = 0; k < l.length - 1; k++) {
        final a = l[k], b = l[k + 1];
        _rejilla.poner(
          (a, b),
          math.min(a.latitude, b.latitude),
          math.min(a.longitude, b.longitude),
          math.max(a.latitude, b.latitude),
          math.max(a.longitude, b.longitude),
        );
        n++;
      }
    }
  }

  static final vacio = IndiceSegmentos(const []);

  final _rejilla = _Rejilla<(LatLng, LatLng)>();

  /// Segmentos indexados.
  int n = 0;

  /// Segmentos cuya caja toca la de [radioM] alrededor de [p] (puede repetir).
  Iterable<(LatLng, LatLng)> cerca(LatLng p, double radioM) =>
      _rejilla.cerca(p, radioM);
}
