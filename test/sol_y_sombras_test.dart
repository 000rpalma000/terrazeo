import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrazeo/models/geo.dart';
import 'package:terrazeo/models/indice_espacial.dart';
import 'package:terrazeo/models/shadow_map.dart';
import 'package:terrazeo/services/datos_lat41.dart';
import 'package:terrazeo/services/osm_area_service.dart';
import 'package:terrazeo/services/shadow_service.dart';
import 'package:terrazeo/services/sun_service.dart';

/// Comprobaciones del cálculo de sol y sombra, con referencias
/// independientes y un caso real (Plaça de Vicenç Martorell, Barcelona,
/// 26/11/2026 hacia las 11:30).
void main() {
  const plaza = LatLng(41.38378, 2.16821);

  group('Posición del sol (referencia: ecuaciones de NOAA, con refracción)', () {
    // Valores calculados aparte con las ecuaciones de NOAA ("Solar
    // Calculation Details"), en UTC.
    final casos = [
      (DateTime.utc(2026, 11, 26, 10, 30), 25.67, 162.22),
      (DateTime.utc(2026, 11, 26, 8, 0), 9.82, 129.41),
      (DateTime.utc(2026, 11, 26, 13, 0), 24.86, 200.95),
      (DateTime.utc(2026, 7, 15, 10, 0), 58.31, 119.84),
    ];
    for (final (t, elev, az) in casos) {
      test('$t', () {
        final s = const SunService().posicion(plaza, t);
        expect(s.elevationDeg, closeTo(elev, 0.2));
        expect(s.azimuthDeg, closeTo(az, 0.2));
      });
    }

    test('la hora local de Barcelona (UTC+1 en noviembre, +2 en julio) es '
        'el mismo instante que su UTC', () {
      final local = DateTime(2026, 11, 26, 11, 30);
      // Solo tiene sentido si las pruebas corren en hora de Madrid; si no,
      // basta con que el instante sea el mismo.
      final utc = local.toUtc();
      final a = const SunService().posicion(plaza, local);
      final b = const SunService().posicion(plaza, utc);
      expect(a.elevationDeg, closeTo(b.elevationDeg, 1e-9));
      expect(a.azimuthDeg, closeTo(b.azimuthDeg, 1e-9));
    });
  });

  group('Dirección y longitud de las sombras', () {
    // Un edificio cuadrado de 10 × 10 m y 20 m de alto, con su centro en el
    // origen.
    BuildingFootprint cubo(LatLng c, double alto) {
      LatLng m(double norte, double este) =>
          Geo.destino(Geo.destino(c, 0, norte), 90, este);
      return BuildingFootprint(
          ring: [m(-5, -5), m(-5, 5), m(5, 5), m(5, -5), m(-5, -5)],
          heightM: alto);
    }

    test('a mediodía de invierno la sombra va al norte, con su longitud', () {
      final t = DateTime.utc(2026, 12, 21, 11, 51); // mediodía solar aprox.
      final sm = const ShadowService().construir([cubo(plaza, 20)], plaza, t);
      final sol = const SunService().posicion(plaza, t);
      final largo = 20 / tanDeg(sol.elevationDeg); // ~ 31 m
      // Al norte, dentro de la sombra; al sur y a los lados, al sol.
      expect(sm.enSombra(Geo.destino(plaza, 0, 5 + largo - 3)), isTrue);
      expect(sm.enSombra(Geo.destino(plaza, 0, 5 + largo + 3)), isFalse);
      expect(sm.enSombra(Geo.destino(plaza, 180, 8)), isFalse);
      expect(sm.enSombra(Geo.destino(plaza, 90, 12)), isFalse);
    });

    test('por la mañana la sombra va hacia el noroeste (opuesta al sol)', () {
      final t = DateTime.utc(2026, 11, 26, 8, 30); // sol al sureste
      final sm = const ShadowService().construir([cubo(plaza, 20)], plaza, t);
      final sol = const SunService().posicion(plaza, t);
      final rumbo = (sol.azimuthDeg + 180) % 360;
      expect(sm.enSombra(Geo.destino(plaza, rumbo, 20)), isTrue);
      expect(sm.enSombra(Geo.destino(plaza, sol.azimuthDeg, 20)), isFalse);
    });
  });

  test('extruir solo las aristas del lado de la sombra da la misma sombra '
      'que extruirlas todas (datos reales, varias horas)', () {
    final z = OsmAreaService.parsearParaPruebas(DatosLat41.aElementos(
        File('test/fixtures/plaza_martorell.json').readAsStringSync()));
    const c = LatLng(41.3841, 2.1690);
    for (final h in [8, 10, 12, 14, 16]) {
      final t = DateTime.utc(2026, 11, 26, h);
      final nuevo = const ShadowService().construir(z.sombras, c, t);
      // El método anterior: planta + un cuadrilátero por cada arista.
      final rumbo = (nuevo.sunAzimuthDeg + 180) % 360;
      final tg = math.tan(nuevo.sunElevationDeg * math.pi / 180);
      final polys = <ShadowPolygon>[];
      for (final e in z.sombras) {
        final largo = (e.heightM / tg).clamp(0.0, 400.0);
        if (largo < 1) continue;
        polys.add(ShadowPolygon(e.ring));
        for (var i = 0; i < e.ring.length - 1; i++) {
          final a = e.ring[i], b = e.ring[i + 1];
          if (a == b) continue;
          polys.add(ShadowPolygon([a, b, Geo.destino(b, rumbo, largo), Geo.destino(a, rumbo, largo)]));
        }
      }
      final viejo = ShadowMap(
          instante: t,
          sunAzimuthDeg: nuevo.sunAzimuthDeg,
          sunElevationDeg: nuevo.sunElevationDeg,
          polygons: polys);
      expect(nuevo.polygons.length, lessThan(polys.length * 0.7));
      var distintos = 0, total = 0;
      for (var i = -40; i <= 40; i++) {
        for (var j = -40; j <= 40; j++) {
          final p = LatLng(c.latitude + i * 0.00003, c.longitude + j * 0.00004);
          total++;
          if (nuevo.enSombra(p) != viejo.enSombra(p)) distintos++;
        }
      }
      // Solo pueden diferir puntos exactamente sobre un borde.
      expect(distintos / total, lessThan(0.001), reason: 'a las $h UTC');
    }
  });

  group('Plaça de Vicenç Martorell, 26/11/2026 a las 11:30', () {
    // Datos de OSM de la plaza (recorte de 250 m de data.lat41lab.com,
    // noviembre de 2026).
    final zona = OsmAreaService.parsearParaPruebas(DatosLat41.aElementos(
        File('test/fixtures/plaza_martorell.json').readAsStringSync()));
    final edif = IndiceEdificios(zona.edificios);
    final vias = IndiceSegmentos(zona.lineasPublicas);
    // Como la app: sombras del tramo de 5 minutos (11:30 + 150 s).
    final hora = DateTime.utc(2026, 11, 26, 10, 32, 30);
    final sombras = const ShadowService()
        .construir(zona.edificios, const LatLng(41.3841, 2.1690), hora);

    LatLng dondeEvalua(String osmId) {
      final b = zona.bares.firstWhere((b) => b.osmId == osmId);
      return OsmAreaService.ajustarConIndices(b.punto, edif, vias)!;
    }

    test('los puntos de OSM están dentro del edificio y la app los saca a '
        'la vía pública a pocos metros', () {
      for (final id in [
        'node/4319328292', 'node/673967678', 'node/673967568', 'node/672140180',
      ]) {
        final b = zona.bares.firstWhere((b) => b.osmId == id);
        expect(edif.dentroDeAlguno(b.punto), isTrue, reason: id);
        final p = dondeEvalua(id);
        expect(edif.dentroDeAlguno(p), isFalse, reason: id);
        expect(Geo.distancia(b.punto, p), lessThan(8), reason: id);
      }
    });

    test('las terrazas del lado norte (miran al sur) están al sol, como se '
        'vio en la plaza', () {
      expect(sombras.enSombra(dondeEvalua('node/673967678')), isFalse); // Chelo
      expect(sombras.enSombra(dondeEvalua('node/673967568')), isFalse); // D'Annunzio
      expect(sombras.enSombra(dondeEvalua('node/672140180')), isFalse); // Kasparo
    });
  });
}

double tanDeg(double g) => math.tan(g * math.pi / 180);
