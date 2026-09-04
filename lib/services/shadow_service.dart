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

      // Un cuadrilátero por arista, extruido en la dirección de la sombra.
      for (var i = 0; i < ring.length - 1; i++) {
        final a = ring[i];
        final b = ring[i + 1];
        if (a == b) continue;
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
