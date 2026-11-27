import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrazeo/models/ciutat.dart';

void main() {
  test('ciutats.json: nombres por idioma, caja y venta', () {
    final c = Ciutat.parse(jsonEncode({
      'v': 1,
      'ciutats': [
        {
          'id': 'barcelona',
          'nom': {'ca': 'Barcelona', 'es': 'Barcelona', 'en': 'Barcelona'},
          'pais': 'es',
          'pais_nom': {'ca': 'Espanya', 'es': 'España', 'en': 'Spain'},
          'caixa': [41.317, 2.052, 41.469, 2.229],
          'venda_recomanats': true,
        },
        {
          'id': 'londres',
          'nom': {'ca': 'Londres', 'es': 'Londres', 'en': 'London'},
          'pais': 'gb',
          'pais_nom': {'ca': 'Regne Unit', 'es': 'Reino Unido', 'en': 'United Kingdom'},
          'caixa': [51.37, -0.34, 51.64, 0.09],
          'venda_recomanats': false,
        },
        {'id': 'rota'}, // incompleta: se ignora
      ],
    }));
    expect(c.map((x) => x.id), ['barcelona', 'londres']);
    expect(c[0].conte(const LatLng(41.383, 2.1755)), isTrue);
    expect(c[0].conte(const LatLng(40.4168, -3.7038)), isFalse);
    expect(c[1].nom('en'), 'London');
    expect(c[1].nom('de'), 'London'); // sin alemán: inglés
    expect(c[1].paisNom('ca'), 'Regne Unit');
    expect(c[0].vendaRecomanats, isTrue);
    expect(c[1].vendaRecomanats, isFalse);
  });

  test('Regió Metropolitana: dentro de la caja solo cuenta el contorno real',
      () {
    // ciutats.json generado por generar_ciutats.py (Barcelona y Madrid).
    final c = Ciutat.parse(File('test/fixtures/ciutats_regio.json').readAsStringSync());
    final bcn = c.firstWhere((x) => x.id == 'barcelona');
    final mad = c.firstWhere((x) => x.id == 'madrid');
    expect(bcn.contorn, isNotEmpty);
    expect(mad.contorn, isEmpty); // ciudad con caja: como siempre
    expect(bcn.nom('ca'), 'Barcelona i àrea metropolitana');
    for (final (nom, p) in [
      ('Barcelona', const LatLng(41.3874, 2.1686)),
      ('Granollers', const LatLng(41.608, 2.287)),
      ('Vilafranca del Penedès', const LatLng(41.346, 1.698)),
      ('Sitges', const LatLng(41.237, 1.805)),
      ('Castellterçol', const LatLng(41.751, 2.120)),
    ]) {
      expect(bcn.conte(p), isTrue, reason: nom);
    }
    // Dentro de la caja de la Regió, pero fuera de sus 164 municipios.
    for (final (nom, p) in [
      ('Igualada', const LatLng(41.579, 1.617)),
      ('Moià', const LatLng(41.811, 2.096)),
      ('Manresa', const LatLng(41.728, 1.824)),
      ('Mar, a 20 km de la costa', const LatLng(41.30, 2.50)),
    ]) {
      expect(bcn.conte(p), isFalse, reason: nom);
    }
    expect(mad.conte(const LatLng(40.4168, -3.7038)), isTrue);
  });
}
