import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/geo.dart';
import '../models/shadow_map.dart';
import 'sun_service.dart';

/// Proyecta las plantas de los edificios en polígonos de sombra sobre el suelo,
/// para una posición del sol dada.
///
/// Modelo (edificio como prisma extruido, suelo plano, rayos de sol paralelos):
/// la sombra de cada edificio es su planta desplazada una distancia
/// `altura / tan(elevación)` en la dirección opuesta al sol. Se representa como
/// la planta original + un cuadrilátero por cada arista (arista, arista
/// desplazada). Así se maneja bien cualquier forma, incluidas manzanas con
/// patios, sin la sobreestimación de una envolvente convexa.
///
/// Solo se extruyen las aristas del lado contrario al sol: las que miran al
/// sol quedan dentro de la planta más la sombra de las otras, así que el
/// resultado es el mismo con la mitad de polígonos.
///
/// No modela: oclusión entre edificios (irrelevante para "sí/no hay sombra"),
/// relieve del terreno, salientes de tejado.
class ShadowService {
  const ShadowService({this.sombraMaximaM = 400});

  /// Tope de longitud de sombra (con sol muy bajo tiende a infinito).
  final double sombraMaximaM;

  ShadowMap construir(
    List<BuildingFootprint> edificios,
    LatLng referencia,
    DateTime instante, {
    SunService sun = const SunService(),
  }) {
    final pos = sun.posicion(referencia, instante);

    if (pos.elevationDeg <= 3) {
      return ShadowMap.noche(instante);
    }

    final rumboSombra = (pos.azimuthDeg + 180) % 360;
    // Dirección de la sombra en el plano (x = este, y = norte).
    final sx = math.sin(rumboSombra * math.pi / 180);
    final sy = math.cos(rumboSombra * math.pi / 180);
    final tan = math.tan(pos.elevationDeg * math.pi / 180);
    final polys = <ShadowPolygon>[];

    for (final ed in edificios) {
      final largo =
          (ed.heightM / (tan <= 0 ? 0.0001 : tan)).clamp(0.0, sombraMaximaM);
      if (largo < 1) continue;

      final ring = ed.ring;
      if (ring.length < 3) continue;

      // La propia planta (el edificio también tapa el sol sobre sí mismo).
      polys.add(ShadowPolygon(ring));

      // Orientación del anillo (en el plano local) para saber qué lado de
      // cada arista es el de fuera.
      final kx = math.cos(ring.first.latitude * math.pi / 180);
      var area2 = 0.0;
      for (var i = 0; i < ring.length - 1; i++) {
        area2 += ring[i].longitude * kx * ring[i + 1].latitude -
            ring[i + 1].longitude * kx * ring[i].latitude;
      }
      final antihorario = area2 > 0;

      // Un cuadrilátero por arista del lado de la sombra, extruido.
      for (var i = 0; i < ring.length - 1; i++) {
        final a = ring[i];
        final b = ring[i + 1];
        if (a == b) continue;
        final dx = (b.longitude - a.longitude) * kx;
        final dy = b.latitude - a.latitude;
        // Normal hacia fuera: (dy, -dx) si el anillo va en sentido
        // antihorario; la contraria si va en el horario.
        final dot = antihorario ? dy * sx - dx * sy : -dy * sx + dx * sy;
        if (dot <= 0) continue; // mira al sol: su sombra ya está cubierta
        final a2 = Geo.destino(a, rumboSombra, largo);
        final b2 = Geo.destino(b, rumboSombra, largo);
        polys.add(ShadowPolygon([a, b, b2, a2]));
      }
    }

    return ShadowMap(
      instante: instante,
      sunAzimuthDeg: pos.azimuthDeg,
      sunElevationDeg: pos.elevationDeg,
      polygons: polys,
    );
  }
}
