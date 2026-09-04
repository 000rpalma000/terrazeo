import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Rectángulo geográfico (suroeste / noreste).
class GeoBounds {
  final LatLng suroeste;
  final LatLng noreste;
  const GeoBounds(this.suroeste, this.noreste);

  double get south => suroeste.latitude;
  double get west => suroeste.longitude;
  double get north => noreste.latitude;
  double get east => noreste.longitude;
}

/// Utilidades geométricas sobre coordenadas WGS84.
///
/// A escala de ciudad tratamos lat/lon casi como un plano: es suficiente para
/// "¿este punto está dentro de esta sombra?" y para longitudes de calle.
class Geo {
  Geo._();

  static const double radioTierraM = 6378137.0;

  static double _rad(double deg) => deg * math.pi / 180;
  static double _deg(double rad) => rad * 180 / math.pi;

  /// Distancia en metros entre dos puntos (haversine).
  static double distancia(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radioTierraM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// Longitud total de una polilínea en metros.
  static double longitudPolilinea(List<LatLng> pts) {
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += distancia(pts[i], pts[i + 1]);
    }
    return total;
  }

  /// Punto a [distanciaM] metros de [origen] con rumbo [rumboDeg] (desde el norte).
  static LatLng destino(LatLng origen, double rumboDeg, double distanciaM) {
    final br = _rad(rumboDeg);
    final lat1 = _rad(origen.latitude);
    final lon1 = _rad(origen.longitude);
    final dr = distanciaM / radioTierraM;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(dr) +
          math.cos(lat1) * math.sin(dr) * math.cos(br),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(br) * math.sin(dr) * math.cos(lat1),
          math.cos(dr) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(_deg(lat2), _deg(lon2));
  }

  /// Puntos equiespaciados (~[pasoM] m) a lo largo de una polilínea, para
  /// muestrear si un tramo está en sombra.
  static List<LatLng> muestrear(List<LatLng> pts, {double pasoM = 15}) {
    if (pts.length < 2) return List.of(pts);
    final out = <LatLng>[pts.first];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final d = distancia(a, b);
      final n = (d / pasoM).floor();
      for (var k = 1; k <= n; k++) {
        final t = (k * pasoM) / d;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    out.add(pts.last);
    return out;
  }

  /// Distancia en metros de [p] al segmento [a]-[b] (aprox. equirectangular
  /// local, buena a escala de ciudad).
  static double distanciaASegmento(LatLng p, LatLng a, LatLng b) {
    final lat0 = _rad(a.latitude);
    double x(LatLng q) =>
        _rad(q.longitude - a.longitude) * math.cos(lat0) * radioTierraM;
    double y(LatLng q) => _rad(q.latitude - a.latitude) * radioTierraM;

    final px = x(p), py = y(p);
    final bx = x(b), by = y(b);
    final len2 = bx * bx + by * by;
    final t =
        len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
    final dx = px - t * bx, dy = py - t * by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Punto del segmento [a]-[b] más cercano a [p] (aprox. equirectangular).
  static LatLng puntoMasCercanoEnSegmento(LatLng p, LatLng a, LatLng b) {
    final lat0 = _rad(a.latitude);
    final cosLat = math.cos(lat0);
    double x(LatLng q) => _rad(q.longitude - a.longitude) * cosLat;
    double y(LatLng q) => _rad(q.latitude - a.latitude);
    final px = x(p), py = y(p);
    final bx = x(b), by = y(b);
    final len2 = bx * bx + by * by;
    final t =
        len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Distancia mínima de [p] a una polilínea.
  static double distanciaAPolilinea(LatLng p, List<LatLng> pts) {
    if (pts.length == 1) return distancia(p, pts.first);
    var min = double.infinity;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = distanciaASegmento(p, pts[i], pts[i + 1]);
      if (d < min) min = d;
    }
    return min;
  }

  /// Reduce una polilínea quedándose con puntos separados al menos [pasoM] m
  /// (conserva siempre el primero y el último).
  static List<LatLng> decimar(List<LatLng> pts, double pasoM) {
    if (pts.length <= 2) return List.of(pts);
    final out = <LatLng>[pts.first];
    for (final p in pts.skip(1)) {
      if (distancia(out.last, p) >= pasoM) out.add(p);
    }
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }

  /// Test punto-en-polígono por lanzamiento de rayo. [anillo] no necesita
  /// repetir el primer vértice al final.
  static bool dentroDePoligono(LatLng p, List<LatLng> anillo) {
    var dentro = false;
    final n = anillo.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = anillo[i].longitude, yi = anillo[i].latitude;
      final xj = anillo[j].longitude, yj = anillo[j].latitude;
      final cruza = (yi > p.latitude) != (yj > p.latitude) &&
          p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi;
      if (cruza) dentro = !dentro;
    }
    return dentro;
  }

  /// Envolvente convexa (Andrew's monotone chain). Se usa para aproximar la
  /// sombra de un edificio como el casco de su base + su base desplazada.
  static List<LatLng> cascoConvexo(List<LatLng> puntos) {
    if (puntos.length < 4) return List.of(puntos);
    final pts = List.of(puntos)
      ..sort((a, b) => a.longitude != b.longitude
          ? a.longitude.compareTo(b.longitude)
          : a.latitude.compareTo(b.latitude));

    double cross(LatLng o, LatLng a, LatLng b) =>
        (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);

    final lower = <LatLng>[];
    for (final p in pts) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <LatLng>[];
    for (final p in pts.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  /// Rectángulo que engloba todos los puntos, ampliado [margenM] metros.
  static GeoBounds limites(
    List<LatLng> pts, {
    double margenM = 250,
  }) {
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLon = pts.first.longitude, maxLon = pts.first.longitude;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    final dLat = margenM / 111320.0;
    final dLon = margenM /
        (111320.0 * math.cos(_rad((minLat + maxLat) / 2)).abs().clamp(0.01, 1));
    return GeoBounds(
      LatLng(minLat - dLat, minLon - dLon),
      LatLng(maxLat + dLat, maxLon + dLon),
    );
  }
}
