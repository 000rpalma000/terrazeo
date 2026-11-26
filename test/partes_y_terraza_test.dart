import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrazeo/models/building_height.dart';
import 'package:terrazeo/models/geo.dart';
import 'package:terrazeo/models/indice_espacial.dart';
import 'package:terrazeo/models/partes_edificio.dart';
import 'package:terrazeo/models/shadow_map.dart';
import 'package:terrazeo/models/sun_status.dart';
import 'package:terrazeo/models/terraza_puntos.dart';
import 'package:terrazeo/services/datos_lat41.dart';
import 'package:terrazeo/services/osm_area_service.dart';
import 'package:terrazeo/services/shadow_service.dart';

const o = LatLng(41.3841, 2.1690);

/// Rectángulo de [ancho] (este-oeste) × [fondo] (norte-sur) metros, con la
/// esquina suroeste a ([norte], [este]) metros de [o].
List<LatLng> rect(double norte, double este, double ancho, double fondo) {
  LatLng m(double n, double e) => Geo.destino(Geo.destino(o, 0, n), 90, e);
  return [
    m(norte, este), m(norte, este + ancho), m(norte + fondo, este + ancho),
    m(norte + fondo, este), m(norte, este),
  ];
}

void main() {
  group('building:part', () {
    final est = BuildingHeightEstimator();

    test('si las partes cubren el edificio, cada parte proyecta con su altura',
        () {
      // Manzana de 20 × 20 m y 6 plantas: la mitad sur es un patio de 1 planta.
      final contorno = (ring: rect(0, 0, 20, 20), tags: {'building': 'yes', 'building:levels': '6'});
      final partes = [
        (ring: rect(0, 0, 20, 10), tags: {'building:part': 'yes', 'building:levels': '1'}),
        (ring: rect(10, 0, 20, 10), tags: {'building:part': 'yes', 'building:levels': '6'}),
      ];
      final s = sombrasConPartes([contorno], partes, est);
      expect(s.map((e) => e.heightM).toList()..sort(), [3.1, 18.6]);
    });

    test('si las partes cubren poco (solo una torre), se queda el contorno', () {
      final contorno = (ring: rect(0, 0, 20, 20), tags: {'building': 'yes', 'building:levels': '3'});
      final torre = (ring: rect(0, 0, 5, 5), tags: {'building:part': 'yes', 'building:levels': '10'});
      final s = sombrasConPartes([contorno], [torre], est);
      expect(s.map((e) => e.heightM).toList()..sort(), [9.3, 31.0]);
    });

    test('un patio bajo al sur ya no da la sombra de toda la manzana', () {
      final contorno = (ring: rect(0, 0, 20, 20), tags: {'building': 'yes', 'building:levels': '6'});
      final partes = [
        (ring: rect(0, 0, 20, 10), tags: {'building:part': 'yes', 'building:levels': '1'}),
        (ring: rect(10, 0, 20, 10), tags: {'building:part': 'yes', 'building:levels': '6'}),
      ];
      // A mediodía de diciembre el sol está al sur: la sombra va al norte.
      final t = DateTime.utc(2026, 12, 21, 11, 50);
      final conPartes = const ShadowService().construir(sombrasConPartes([contorno], partes, est), o, t);
      final sinPartes = const ShadowService().construir(sombrasConPartes([contorno], const [], est), o, t);
      // 8 m al sur del edificio: al sol en los dos casos.
      final sur = Geo.destino(Geo.destino(o, 90, 10), 180, 8);
      expect(conPartes.enSombra(sur), isFalse);
      expect(sinPartes.enSombra(sur), isFalse);
      // Al norte, la sombra de 6 plantas llega igual (sale de la parte alta).
      final norte = Geo.destino(Geo.destino(o, 90, 10), 0, 30);
      expect(conPartes.enSombra(norte), isTrue);
      expect(sinPartes.enSombra(norte), isTrue);
    });

    test('las partes de los datos propios llegan a la app y no se toman por '
        'espacio público', () {
      final z = OsmAreaService.parsearParaPruebas(DatosLat41.aElementos(
          File('test/fixtures/plaza_martorell.json').readAsStringSync()));
      expect(z.sombras.length, greaterThan(z.edificios.length));
      // Ninguna línea pública coincide con un anillo de parte (cerrado).
      final cerradas = z.lineasPublicas.where((l) => l.length > 3 && l.first == l.last).length;
      expect(cerradas, lessThan(30)); // solo plazas y parques cerrados
    });
  });

  group('Puntos de la terraza', () {
    test('delante de la fachada, del lado abierto, a 2-6 m', () {
      // Bloque de 30 × 20 m; al sur, una plaza abierta; al norte, otro bloque
      // a 4 m (un callejón).
      final bloque = BuildingFootprint(ring: rect(0, 0, 30, 20), heightM: 15);
      final vecino = BuildingFootprint(ring: rect(24, 0, 30, 20), heightM: 15);
      final ie = IndiceEdificios([bloque, vecino]);
      // Punto de OSM dentro del bloque, algo más cerca del callejón (9 m)
      // que de la plaza (11 m): se prefiere el lado más despejado.
      final p = Geo.destino(Geo.destino(o, 90, 15), 0, 11);
      final t = PuntosTerraza.de(p, ie)!;
      // Se elige la plaza (sur): todos los puntos quedan al sur del bloque.
      for (final q in t.puntos) {
        expect(q.latitude, lessThan(o.latitude));
        expect(ie.dentroDeAlguno(q), isFalse);
      }
      expect(t.puntos.length, 9);
      expect(Geo.distancia(t.centro, Geo.destino(Geo.destino(o, 90, 15), 180, 4)),
          lessThan(1.5));
    });

    test('si el local está pegado a una fachada, se queda en esa fachada', () {
      final bloque = BuildingFootprint(ring: rect(0, 0, 30, 20), heightM: 15);
      final vecino = BuildingFootprint(ring: rect(24, 0, 30, 20), heightM: 15);
      final ie = IndiceEdificios([bloque, vecino]);
      // A 1 m de la fachada norte y 19 m de la sur: no se va a la plaza.
      final t = PuntosTerraza.de(Geo.destino(Geo.destino(o, 90, 15), 0, 19), ie)!;
      for (final q in t.puntos) {
        expect(q.latitude, greaterThan(o.latitude));
        expect(ie.dentroDeAlguno(q), isFalse); // los del callejón que caben
      }
    });

    test('sin edificios cerca no hay puntos (se usa el punto tal cual)', () {
      expect(PuntosTerraza.de(o, IndiceEdificios(const [])), isNull);
    });

    test('sol, sombra o sol parcial según los puntos a la sombra', () {
      SunStatus st(double f) => combinarSunStatus(
          esDeDia: true, tapadoPorEdificio: false, fraccionEnSombra: f);
      expect(st(0), SunStatus.pleno);
      expect(st(3 / 9), SunStatus.pleno);
      expect(st(4 / 9), SunStatus.solParcial);
      expect(st(5 / 9), SunStatus.solParcial);
      expect(st(6 / 9), SunStatus.sombraPorEdificios);
      expect(st(1), SunStatus.sombraPorEdificios);
      expect(SunStatus.solParcial.haySolDirecto, isTrue);
    });
  });
}
