import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'building_height.dart';
import 'geo.dart';
import 'shadow_map.dart';

typedef Crudo = ({List<LatLng> ring, Map<String, dynamic> tags});

/// Qué edificios proyectan sombra, teniendo en cuenta las partes
/// (`building:part`, Simple 3D Buildings): cada parte con su altura.
///
/// - Un edificio cuyas partes cubren al menos [cobertura] de su planta se
///   sustituye por sus partes (una manzana de 6 plantas con patios de 1-2 ya
///   no da sombra de 6 plantas desde el patio).
/// - Si las partes cubren menos (solo una torre, por ejemplo), se queda el
///   contorno con su altura y se añaden las partes.
/// - Las partes sin contorno en la misma cuadrícula (contorno de la vecina)
///   también se añaden: como mucho, una sombra repetida.
///
/// El contorno se sigue usando aparte para "¿este punto cae dentro de un
/// edificio?" y para el viento.
List<BuildingFootprint> sombrasConPartes(
  List<Crudo> contornos,
  List<Crudo> partes,
  BuildingHeightEstimator estimador, {
  double cobertura = 0.8,
}) {
  final out = <BuildingFootprint>[];
  if (partes.isEmpty) {
    for (final c in contornos) {
      out.add(BuildingFootprint(ring: c.ring, heightM: estimador.estimar(c.tags)));
    }
    return out;
  }

  final cajas = [for (final c in contornos) _Caja.de(c.ring)];
  final partesDe = List.generate(contornos.length, (_) => <int>[]);
  final huerfanas = <int>[];
  for (var k = 0; k < partes.length; k++) {
    final c = _centro(partes[k].ring);
    var asignada = false;
    for (var i = 0; i < contornos.length; i++) {
      if (cajas[i].contiene(c) && Geo.dentroDePoligono(c, contornos[i].ring)) {
        partesDe[i].add(k);
        asignada = true;
        break;
      }
    }
    if (!asignada) huerfanas.add(k);
  }

  BuildingFootprint huella(Crudo e) =>
      BuildingFootprint(ring: e.ring, heightM: estimador.estimar(e.tags));

  for (var i = 0; i < contornos.length; i++) {
    final ps = partesDe[i];
    if (ps.isEmpty) {
      out.add(huella(contornos[i]));
      continue;
    }
    final area = areaM2(contornos[i].ring);
    var cubierta = 0.0;
    for (final k in ps) {
      cubierta += areaM2(partes[k].ring);
    }
    if (area <= 0 || cubierta < cobertura * area) out.add(huella(contornos[i]));
    for (final k in ps) {
      out.add(huella(partes[k]));
    }
  }
  for (final k in huerfanas) {
    out.add(huella(partes[k]));
  }
  return out;
}

/// Área de un anillo en m² (plano local, buena a escala de edificio).
double areaM2(List<LatLng> r) {
  if (r.length < 3) return 0;
  final lat0 = r.first.latitude * math.pi / 180;
  final kx = 111320 * math.cos(lat0), ky = 110574.0;
  var s = 0.0;
  for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
    s += (r[j].longitude * kx) * (r[i].latitude * ky) -
        (r[i].longitude * kx) * (r[j].latitude * ky);
  }
  return s.abs() / 2;
}

LatLng _centro(List<LatLng> r) {
  var la = 0.0, lo = 0.0;
  final n = r.length > 1 && r.first == r.last ? r.length - 1 : r.length;
  for (var i = 0; i < n; i++) {
    la += r[i].latitude;
    lo += r[i].longitude;
  }
  return LatLng(la / n, lo / n);
}

class _Caja {
  _Caja(this.s, this.w, this.n, this.e);
  final double s, w, n, e;
  factory _Caja.de(List<LatLng> r) {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in r) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    return _Caja(s, w, n, e);
  }
  bool contiene(LatLng p) =>
      p.latitude >= s && p.latitude <= n && p.longitude >= w && p.longitude <= e;
}
