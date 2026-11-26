import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrazeo/models/bar.dart';
import 'package:terrazeo/services/osm_area_service.dart';

void main() {
  group('Tesela', () {
    test('un punto cae dentro de su tesela', () {
      final p = LatLng(41.3870, 2.1700);
      final t = Tesela.de(p);
      expect(p.latitude, inInclusiveRange(t.sur, t.norte));
      expect(p.longitude, inInclusiveRange(t.oeste, t.este));
    });

    test('puntos cercanos comparten tesela (reutilizan caché)', () {
      expect(Tesela.de(LatLng(41.3871, 2.1701)),
          Tesela.de(LatLng(41.3874, 2.1705)));
    });

    test('cubriendo devuelve todas las teselas de la caja', () {
      final ts = Tesela.cubriendo(41.380, 2.160, 41.390, 2.175);
      // 0.010° de lat / 0.005 → 2-3 filas; 0.015° de lon / 0.0066 → 3-4 cols.
      expect(ts.length, inInclusiveRange(6, 12));
      expect(ts.toSet().length, ts.length);
      expect(ts, contains(Tesela.de(LatLng(41.385, 2.167))));
    });
  });

  test('Bar.fromFila lee el formato empaquetado', () {
    final b = Bar.fromFila(['node/1', 41.38, 2.17, '', 'cafe', 1]);
    expect(b.osmId, 'node/1');
    expect(b.nombre, 'Cafetería'); // sin nombre → nombre por tipo
    expect(b.tipo, 'cafe');
    expect(b.terrazaDeclarada, isTrue);
    expect(b.punto.latitude, 41.38);
  });

  test('assets/data/bares.json es válido y usa los mismos ids que Overpass',
      () {
    final d = jsonDecode(File('assets/data/bares.json').readAsStringSync())
        as Map<String, dynamic>;
    final bares = (d['bares'] as List).cast<List>();
    expect(bares.length, greaterThan(1000));
    expect((d['bbox'] as List).length, 4);
    for (final f in bares.take(50)) {
      final b = Bar.fromFila(f.cast<dynamic>());
      expect(b.osmId, matches(RegExp(r'^(node|way|relation)/\d+$')));
    }
  });

  test('Los locales empaquetados cubren el centro de Barcelona (sin bajar la ciudad)',
      () {
    final d = jsonDecode(File('assets/data/bares.json').readAsStringSync())
        as Map<String, dynamic>;
    final bbox = [for (final v in d['bbox'] as List) (v as num).toDouble()];
    final emp = BaresEmpaquetados(const [], bbox, '');
    // Gòtic con ~1 km de margen: cubierto.
    expect(emp.cubreZona(41.366, 2.160, 41.400, 2.191), isTrue);
    // Madrid: no.
    expect(emp.cubreZona(40.40, -3.72, 40.43, -3.69), isFalse);
    // La región de 11 km del centro se sale por el sur (41,30 < 41,317):
    // por eso no basta con mirar la región entera.
    expect(emp.cubreRegion(Region.de(const LatLng(41.383, 2.1755))), isFalse);
  });

  test('repartir asigna ways sin center (out geom) por su caja', () {
    final t = Tesela.de(LatLng(41.3870, 2.1700));
    final body = jsonEncode({
      'elements': [
        {
          'type': 'way',
          'id': 1,
          'bounds': {
            'minlat': 41.3869, 'minlon': 2.1699,
            'maxlat': 41.3871, 'maxlon': 2.1701,
          },
          'geometry': [
            {'lat': 41.3869, 'lon': 2.1699},
            {'lat': 41.3871, 'lon': 2.1699},
            {'lat': 41.3871, 'lon': 2.1701},
          ],
          'tags': {'building': 'yes'},
        },
        {
          'type': 'node', 'id': 2, 'lat': 41.3870, 'lon': 2.1700,
          'tags': {'amenity': 'bar'},
        },
        // Fuera de las teselas pedidas: se descarta.
        {'type': 'node', 'id': 3, 'lat': 40.0, 'lon': 2.0, 'tags': {}},
      ],
    });
    final r = OsmAreaService.repartir(body, [(t.i, t.j)]);
    expect(r[t.clave]!.length, 2);
  });

  test('Region agrupa una ciudad y filasDeOverpass usa el formato compacto',
      () {
    expect(Region.de(LatLng(40.4168, -3.7038)),
        Region.de(LatLng(40.42, -3.70))); // Madrid centro: misma región
    final filas = OsmAreaService.filasDeOverpass(jsonEncode({
      'elements': [
        {
          'type': 'way', 'id': 7,
          'center': {'lat': 40.42, 'lon': -3.70},
          'tags': {'amenity': 'cafe', 'outdoor_seating': 'yes'},
        },
        {
          'type': 'node', 'id': 9, 'lat': 40.41, 'lon': -3.71,
          'tags': {'amenity': 'bar', 'outdoor_seating': 'no',
                   'opening_hours': 'Mo-Su 18:00-02:00'},
        },
        {'type': 'node', 'id': 8, 'tags': {'amenity': 'bar'}}, // sin coords
      ],
    }));
    expect(filas.length, 2);
    final b = Bar.fromFila(filas.first);
    expect(b.osmId, 'way/7');
    expect(b.terrazaDeclarada, isTrue);
    final c = Bar.fromFila(filas.last);
    expect(c.terraza, Terraza.no);
    expect(c.abiertoEn(DateTime(2026, 11, 25, 1)), isTrue);
  });
}
