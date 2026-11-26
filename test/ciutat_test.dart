import 'dart:convert';

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
}
