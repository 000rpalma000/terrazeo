import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'indice_espacial.dart';

/// Dónde están, más o menos, las mesas de una terraza: delante de la
/// fachada del local, del lado abierto.
///
/// El punto de OSM de un local suele estar dentro del edificio. Se busca la
/// fachada más cercana y se sale en perpendicular hacia el espacio abierto,
/// prefiriendo el lado más despejado (una plaza o una calle peatonal ancha
/// antes que un callejón). Se devuelven puntos a 2, 4 y 6 m de la fachada y
/// a -4, 0 y +4 m a lo largo de ella (los que caen dentro de otro edificio
/// no cuentan).
class PuntosTerraza {
  const PuntosTerraza(this.centro, this.puntos);

  /// Delante de la fachada, a 4 m: el punto que representa la terraza.
  final LatLng centro;
  final List<LatLng> puntos;

  static const _hacia = [2.0, 4.0, 6.0];
  static const _alLado = [-4.0, 0.0, 4.0];

  /// Fachadas a menos de [radioM] del punto; `null` si no hay ninguna (el
  /// local no está junto a un edificio conocido).
  static PuntosTerraza? de(LatLng p, IndiceEdificios ie, {double radioM = 15}) {
    final lat0 = p.latitude * math.pi / 180;
    final kx = 111320 * math.cos(lat0), ky = 110574.0;
    // Plano local en metros alrededor de p.
    (double, double) aM(LatLng q) =>
        ((q.longitude - p.longitude) * kx, (q.latitude - p.latitude) * ky);
    LatLng aG(double x, double y) =>
        LatLng(p.latitude + y / ky, p.longitude + x / kx);

    final candidatas = <({double d, double fx, double fy, double nx, double ny, double tx, double ty})>[];
    for (final e in ie.cercanos(p, radioM)) {
      final r = e.ring;
      for (var i = 0; i < r.length - 1; i++) {
        final (ax, ay) = aM(r[i]);
        final (bx, by) = aM(r[i + 1]);
        final lx = bx - ax, ly = by - ay;
        final l = math.sqrt(lx * lx + ly * ly);
        if (l < 2) continue; // aristas diminutas: esquinas sin fachada
        final t = ((-ax) * lx + (-ay) * ly) / (l * l);
        final tc = t.clamp(0.0, 1.0);
        final fx = ax + lx * tc, fy = ay + ly * tc;
        final d = math.sqrt(fx * fx + fy * fy);
        if (d > radioM) continue;
        // Normal hacia fuera de este edificio.
        var nx = -ly / l, ny = lx / l;
        if (Geo.dentroDePoligono(aG(fx + nx, fy + ny), r)) {
          nx = -nx;
          ny = -ny;
        }
        candidatas.add((d: d, fx: fx, fy: fy, nx: nx, ny: ny, tx: lx / l, ty: ly / l));
      }
    }
    if (candidatas.isEmpty) return null;
    candidatas.sort((a, b) => a.d.compareTo(b.d));
    final dMin = candidatas.first.d;

    // Entre las fachadas casi igual de cercanas, la más despejada.
    double despejado(double fx, double fy, double nx, double ny) {
      for (var s = 2.0; s <= 20; s += 2) {
        if (ie.dentroDeAlguno(aG(fx + nx * s, fy + ny * s))) return s - 2;
      }
      return 20;
    }

    ({double d, double fx, double fy, double nx, double ny, double tx, double ty})? mejor;
    var mejorLibre = -1.0;
    for (final c in candidatas) {
      if (c.d > dMin + 6) break;
      final libre = despejado(c.fx, c.fy, c.nx, c.ny);
      if (libre < 2) continue; // da contra otro edificio: no hay acera
      if (libre > mejorLibre + 1) {
        mejor = c;
        mejorLibre = libre;
      }
    }
    final f = mejor;
    if (f == null) return null;
    final puntos = <LatLng>[];
    for (final h in _hacia) {
      for (final a in _alLado) {
        final q = aG(f.fx + f.nx * h + f.tx * a, f.fy + f.ny * h + f.ty * a);
        if (!ie.dentroDeAlguno(q)) puntos.add(q);
      }
    }
    if (puntos.isEmpty) return null;
    return PuntosTerraza(aG(f.fx + f.nx * 4, f.fy + f.ny * 4), puntos);
  }
}
