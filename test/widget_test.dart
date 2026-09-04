import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:terrazeo/models/comfort.dart';
import 'package:terrazeo/models/geo.dart';
import 'package:terrazeo/models/shadow_map.dart';
import 'package:terrazeo/models/sun_status.dart';
import 'package:terrazeo/services/osm_area_service.dart';
import 'package:terrazeo/services/sun_service.dart';
import 'package:terrazeo/widgets/report_widgets.dart';

void main() {
  test('combinarSunStatus prioriza noche > edificio > nubes', () {
    expect(
      combinarSunStatus(esDeDia: false, tapadoPorEdificio: true),
      SunStatus.noche,
    );
    expect(
      combinarSunStatus(
          esDeDia: true, tapadoPorEdificio: true, cloudFraction: 0.0),
      SunStatus.sombraPorEdificios,
    );
    expect(
      combinarSunStatus(
          esDeDia: true, tapadoPorEdificio: false, cloudFraction: 0.9),
      SunStatus.nublado,
    );
    expect(
      combinarSunStatus(
          esDeDia: true, tapadoPorEdificio: false, cloudFraction: 0.5),
      SunStatus.solConNubes,
    );
    expect(
      combinarSunStatus(
          esDeDia: true, tapadoPorEdificio: false, cloudFraction: 0.1),
      SunStatus.pleno,
    );
  });

  test('evaluarConfort: sol fuerte y calor -> incómodo', () {
    final v = evaluarConfort(
        sunStatus: SunStatus.pleno, tempC: 33, windKmh: 3);
    expect(v.flags, contains(ComfortFlag.solFuerte));
    expect(v.level, anyOf(ComfortLevel.incomodo, ComfortLevel.justo));
    expect(v.headline,
        anyOf(ComfortHeadline.solFuerte, ComfortHeadline.calorSombra));
  });

  test('evaluarConfort: templado a la sombra con brisa -> agradable', () {
    final v = evaluarConfort(
        sunStatus: SunStatus.sombraPorEdificios, tempC: 25, windKmh: 12);
    expect(v.level,
        anyOf(ComfortLevel.muyAgradable, ComfortLevel.agradable));
    expect(v.flags, contains(ComfortFlag.brisa));
  });

  test('evaluarConfort: mucho viento -> incómodo y ventoso', () {
    final v = evaluarConfort(
        sunStatus: SunStatus.pleno, tempC: 24, windKmh: 40);
    expect(v.level, ComfortLevel.incomodo);
    expect(v.headline, ComfortHeadline.ventoso);
  });

  test('SunService: mediodía de verano en Barcelona, sol alto', () {
    final pos = const SunService()
        .posicion(LatLng(41.3874, 2.1686), DateTime(2026, 6, 21, 14));
    expect(pos.esDeDia, isTrue);
    expect(pos.elevationDeg, greaterThan(50));
  });

  test('ShadowMap: punto dentro de un polígono de sombra', () {
    final poly = ShadowPolygon([
      LatLng(41.3870, 2.1680),
      LatLng(41.3870, 2.1684),
      LatLng(41.3873, 2.1684),
      LatLng(41.3873, 2.1680),
    ]);
    final mapa = ShadowMap(
      instante: DateTime(2026, 6, 21, 12),
      sunAzimuthDeg: 180,
      sunElevationDeg: 45,
      polygons: [poly],
    );
    expect(mapa.enSombra(LatLng(41.38715, 2.1682)), isTrue);
    expect(mapa.enSombra(LatLng(41.3860, 2.1682)), isFalse);
  });

  test('ajustarAEspacioPublico: fuera de edificio devuelve el mismo punto', () {
    final p = LatLng(41.3900, 2.1700);
    final res = OsmAreaService.ajustarAEspacioPublico(p, const [], const []);
    expect(identical(res, p), isTrue);
  });

  test('ajustarAEspacioPublico: dentro de un edificio salta a la calle', () {
    final edificio = BuildingFootprint(
      ring: [
        LatLng(41.3900, 2.1700),
        LatLng(41.3900, 2.1704),
        LatLng(41.3903, 2.1704),
        LatLng(41.3903, 2.1700),
      ],
      heightM: 15,
    );
    final calle = [LatLng(41.3899, 2.1699), LatLng(41.3899, 2.1706)];
    final p = LatLng(41.39015, 2.1702); // dentro del edificio
    final res = OsmAreaService.ajustarAEspacioPublico(p, [edificio], [calle]);
    expect(res, isNotNull);
    expect(Geo.dentroDePoligono(res!, edificio.ring), isFalse);
    expect(Geo.distancia(p, res), lessThan(60));
  });

  test('Geo.dentroDePoligono', () {
    final anillo = [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
    ];
    expect(Geo.dentroDePoligono(LatLng(1, 1), anillo), isTrue);
    expect(Geo.dentroDePoligono(LatLng(3, 3), anillo), isFalse);
  });

  testWidgets('SunBadge se dibuja para cada estado', (tester) async {
    for (final s in SunStatus.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SunBadge(status: s))),
      );
      expect(find.byType(SunBadge), findsOneWidget);
    }
  });
}
