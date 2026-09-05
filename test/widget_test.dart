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

  const bcn = 41.39; // Barcelona, hemisferio norte
  final veranoNorte = DateTime(2026, 7, 21, 14); // pico de verano boreal
  final inviernoNorte = DateTime(2026, 1, 19, 13); // pico de invierno boreal

  test('evaluarConfort: en verano, sol pleno y sin viento -> incómodo', () {
    final v = evaluarConfort(
      sunStatus: SunStatus.pleno,
      windKmh: 3,
      instante: veranoNorte,
      latitud: bcn,
    );
    expect(v.buscaSombra, isTrue);
    expect(v.flags, contains(ComfortFlag.solFuerte));
    expect(v.level, ComfortLevel.incomodo);
    expect(v.headline, ComfortHeadline.solFuerte);
  });

  test('evaluarConfort: en verano, sombra con brisa -> el combo ideal', () {
    final v = evaluarConfort(
      sunStatus: SunStatus.sombraPorEdificios,
      windKmh: 12,
      instante: veranoNorte,
      latitud: bcn,
    );
    expect(v.level, ComfortLevel.muyAgradable);
    expect(v.flags, contains(ComfortFlag.brisa));
    expect(v.headline, ComfortHeadline.brisaAgradable);
  });

  test('evaluarConfort: mucho viento -> incómodo y ventoso aunque haya sombra', () {
    final v = evaluarConfort(
      sunStatus: SunStatus.sombraPorEdificios,
      windKmh: 45,
      instante: veranoNorte,
      latitud: bcn,
    );
    expect(v.level, ComfortLevel.incomodo);
    expect(v.headline, ComfortHeadline.ventoso);
  });

  test('evaluarConfort: 22°C no pesa igual en invierno que en verano', () {
    final enInvierno = evaluarConfort(
      sunStatus: SunStatus.pleno,
      windKmh: 5,
      tempC: 22,
      instante: inviernoNorte,
      latitud: bcn,
    );
    expect(enInvierno.buscaSombra, isFalse);
    expect(enInvierno.level, ComfortLevel.muyAgradable);
    expect(enInvierno.headline, ComfortHeadline.solAgradable);

    final enVerano = evaluarConfort(
      sunStatus: SunStatus.pleno,
      windKmh: 5,
      tempC: 25, // el propio ejemplo del usuario: 25° en verano sí pide sombra
      instante: veranoNorte,
      latitud: bcn,
    );
    expect(enVerano.buscaSombra, isTrue);
    expect(enVerano.level, ComfortLevel.incomodo);
    expect(enVerano.headline, ComfortHeadline.solFuerte);
  });

  test('evaluarConfort: enero es pleno verano en el hemisferio sur', () {
    final buenosAires = evaluarConfort(
      sunStatus: SunStatus.pleno,
      windKmh: 5,
      instante: inviernoNorte, // 19 de enero
      latitud: -34.6, // Buenos Aires: allí es pleno verano
    );
    expect(buenosAires.buscaSombra, isTrue);

    final barcelona = evaluarConfort(
      sunStatus: SunStatus.pleno,
      windKmh: 5,
      instante: inviernoNorte,
      latitud: bcn, // misma fecha, hemisferio norte: pleno invierno
    );
    expect(barcelona.buscaSombra, isFalse);
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
