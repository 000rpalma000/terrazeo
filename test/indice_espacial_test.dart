import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrazeo/models/geo.dart';
import 'package:terrazeo/models/indice_espacial.dart';
import 'package:terrazeo/models/shadow_map.dart';
import 'package:terrazeo/services/osm_area_service.dart';

/// Ciudad sintética: manzanas de ~30 m separadas por calles cada ~40 m.
({List<BuildingFootprint> edificios, List<List<LatLng>> calles}) _ciudad() {
  const lat0 = 41.38, lon0 = 2.17;
  const paso = 0.00036, lado = 0.00027; // ~40 m y ~30 m
  final edificios = <BuildingFootprint>[];
  for (var i = 0; i < 20; i++) {
    for (var j = 0; j < 20; j++) {
      final s = lat0 + i * paso, w = lon0 + j * paso;
      edificios.add(BuildingFootprint(ring: [
        LatLng(s, w),
        LatLng(s, w + lado),
        LatLng(s + lado, w + lado),
        LatLng(s + lado, w),
        LatLng(s, w),
      ], heightM: 10 + (i * j) % 15));
    }
  }
  final calles = <List<LatLng>>[
    for (var i = 0; i <= 20; i++)
      [
        LatLng(lat0 + i * paso - 0.00005, lon0 - 0.0002),
        LatLng(lat0 + i * paso - 0.00005, lon0 + 20 * paso),
      ],
    for (var j = 0; j <= 20; j++)
      [
        LatLng(lat0 - 0.0002, lon0 + j * paso - 0.00005),
        LatLng(lat0 + 20 * paso, lon0 + j * paso - 0.00005),
      ],
  ];
  return (edificios: edificios, calles: calles);
}

/// El algoritmo de antes (recorrerlo todo), como referencia.
LatLng? _ajustarFuerzaBruta(
    LatLng p, List<BuildingFootprint> eds, List<List<LatLng>> lineas) {
  bool dentro(LatLng q) => eds.any((b) => Geo.dentroDePoligono(q, b.ring));
  if (!dentro(p)) return p;
  LatLng? mejor;
  var mejorD = 60.0;
  for (final l in lineas) {
    for (var i = 0; i < l.length - 1; i++) {
      final c = Geo.puntoMasCercanoEnSegmento(p, l[i], l[i + 1]);
      final d = Geo.distancia(p, c);
      if (d < mejorD && !dentro(c)) {
        mejorD = d;
        mejor = c;
      }
    }
  }
  return mejor;
}

void main() {
  final c = _ciudad();
  final rnd = math.Random(7);
  final puntos = [
    for (var k = 0; k < 400; k++)
      LatLng(41.38 + rnd.nextDouble() * 0.0072,
          2.17 + rnd.nextDouble() * 0.0072),
  ];

  test('IndiceEdificios.edificioEn coincide con recorrerlos todos', () {
    final idx = IndiceEdificios(c.edificios);
    expect(idx.n, 400);
    for (final p in puntos) {
      final bruto = c.edificios.any((b) => Geo.dentroDePoligono(p, b.ring));
      expect(idx.dentroDeAlguno(p), bruto, reason: '$p');
    }
  });

  test('ajustarConIndices da lo mismo que el algoritmo de antes', () {
    final eds = IndiceEdificios(c.edificios);
    final vias = IndiceSegmentos(c.calles);
    var dentro = 0;
    for (final p in puntos) {
      final antes = _ajustarFuerzaBruta(p, c.edificios, c.calles);
      final ahora = OsmAreaService.ajustarConIndices(p, eds, vias);
      if (!identical(antes, p)) dentro++;
      if (antes == null) {
        expect(ahora, isNull, reason: '$p');
      } else {
        expect(Geo.distancia(antes, ahora!), lessThan(0.01), reason: '$p');
      }
    }
    expect(dentro, greaterThan(100)); // la prueba ejercita el caso difícil
  });

  test('IndiceSegmentos.cerca incluye todo segmento a menos del radio', () {
    final vias = IndiceSegmentos(c.calles);
    for (final p in puntos.take(100)) {
      final cerca = vias.cerca(p, 60).toSet();
      for (final l in c.calles) {
        if (Geo.distanciaASegmento(p, l[0], l[1]) <= 60) {
          expect(cerca.contains((l[0], l[1])), isTrue, reason: '$p');
        }
      }
    }
  });
}
