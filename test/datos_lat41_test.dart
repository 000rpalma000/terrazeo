import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrazeo/models/bar.dart';
import 'package:terrazeo/services/datos_lat41.dart';

void main() {
  // Una cuadrícula mínima con el formato de tool/datos/FORMATO.md.
  final cuerpo = jsonEncode({
    'v': 1,
    't': '8276_329',
    'w': [
      // Edificio cuadrado: (41.383000, 2.175000) y deltas.
      [
        11, 'b', {'building': 'yes', 'building:levels': '5'}, 0,
        [41383000, 2175000, 0, 100, 100, 0, 0, -100, -100, 0],
      ],
      // Calle con nodos (para el grafo de Alombra).
      [
        22, 'h', {'highway': 'residential'}, [1, 2],
        [41383200, 2175000, 0, 300],
      ],
      // Carril bici: Alombra no lo quiere.
      [33, 'h', {'highway': 'cycleway'}, [3, 4], [41383300, 2175000, 0, 300]],
      // Plaza.
      [
        44, 'a', {'place': 'square'}, 0,
        [41383400, 2175000, 0, 200, 200, 0, 0, -200, -200, 0],
      ],
    ],
    'n': [
      ['node/55', 41.3831, 2.1751, 'Bar Gòtic', 'bar', 1],
      ['way/66', 41.3832, 2.1752, '', 'cafe', 0],
      ['node/77', 41.3833, 2.1753, 'Sin terraza', 'bar', -1, 'Mo-Su 10:00-20:00'],
    ],
  });

  test('aElementos reconstruye geometría, cajas y etiquetas', () {
    final els = DatosLat41.aElementos(cuerpo);
    final ed = els.firstWhere((e) => e['id'] == 11);
    expect(ed['type'], 'way');
    expect(ed['tags'], {'building': 'yes', 'building:levels': '5'});
    final g = (ed['geometry'] as List).cast<Map>();
    expect(g, hasLength(5));
    expect(g[2]['lat'], closeTo(41.3831, 1e-9));
    expect(g[2]['lon'], closeTo(2.1751, 1e-9));
    expect(g.last, g.first); // anillo cerrado
    expect(ed['bounds'], {
      'minlat': 41.383, 'minlon': 2.175, 'maxlat': 41.3831, 'maxlon': 2.1751,
    });
    expect(ed.containsKey('nodes'), isFalse);
    expect(els.firstWhere((e) => e['id'] == 22)['nodes'], [1, 2]);
  });

  test('aElementos filtra los tipos de vía que pide cada app', () {
    final todas = DatosLat41.aElementos(cuerpo);
    final alombra = DatosLat41.aElementos(cuerpo, vias: {'residential'});
    expect(todas.where((e) => e['id'] == 33), hasLength(1));
    expect(alombra.where((e) => e['id'] == 33), isEmpty);
    // Edificios y plazas no dependen del filtro de vías.
    expect(alombra.where((e) => e['id'] == 11 || e['id'] == 44), hasLength(2));
  });

  test('Los locales salen como los de Overpass', () {
    final els = DatosLat41.aElementos(cuerpo);
    final b1 = Bar.fromOverpass(els.firstWhere((e) => e['id'] == 55));
    expect(b1.osmId, 'node/55');
    expect(b1.nombre, 'Bar Gòtic');
    expect(b1.terrazaDeclarada, isTrue);
    final b2 = Bar.fromOverpass(els.firstWhere((e) => e['id'] == 66));
    expect(b2.osmId, 'way/66');
    expect(b2.nombre, isNotEmpty); // sin nombre: el genérico de su tipo
    expect(b2.terrazaDeclarada, isFalse);
  });

  test('Terraza confirmada, sin confirmar y "no", y horario', () {
    final els = DatosLat41.aElementos(cuerpo);
    Bar bar(int id) => Bar.fromOverpass(els.firstWhere((e) => e['id'] == id));
    expect(bar(55).terraza, Terraza.confirmada);
    expect(bar(66).terraza, Terraza.sinConfirmar);
    expect(bar(77).terraza, Terraza.no);
    expect(bar(66).horario, isNull);
    expect(bar(77).abiertoEn(DateTime(2026, 11, 25, 12)), isTrue);
    expect(bar(77).abiertoEn(DateTime(2026, 11, 25, 21)), isFalse);
    // Las filas de bares.json, igual.
    final f = Bar.fromFila(
        ['node/77', 41.3833, 2.1753, 'Sin terraza', 'bar', -1, 'Mo-Su 10:00-20:00']);
    expect(f.terraza, Terraza.no);
    expect(f.horario, isNotNull);
    // Filas del formato anterior (sin horario).
    expect(Bar.fromFila(['node/1', 41.0, 2.0, '', 'bar', 1]).terraza,
        Terraza.confirmada);
    // Otros valores de outdoor_seating que significan terraza.
    for (final v in ['sidewalk', 'pedestrian_zone', 'parklet', 'only', 'Yes']) {
      expect(Terraza.deEtiqueta(v, 'cafe'), Terraza.confirmada, reason: v);
    }
  });

  test('Manifiesto: cubiertas, con datos y vacías', () {
    final m = Manifiesto.parse(jsonEncode({
      'v': 1,
      'datos_osm': '2026-11-24T21:21:02Z',
      'cobertura': [
        {'i0': 8263, 'i1': 8293, 'j0': 310, 'j1': 337},
      ],
      'cuadriculas': {'8276_329': 'abc123def456'},
    }));
    expect(m.cubre(8276, 329), isTrue);
    expect(m.vacia(8276, 329), isFalse);
    expect(m.cubre(8270, 335), isTrue);
    expect(m.vacia(8270, 335), isTrue); // cubierta y sin nada: mar
    expect(m.cubre(8082, -561), isFalse); // Madrid: por Overpass
    expect(m.vacia(8082, -561), isFalse);
  });
}
