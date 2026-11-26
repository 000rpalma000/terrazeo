import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrazeo/config/locales_config.dart';
import 'package:terrazeo/models/recomanat.dart';

void main() {
  final ahora = DateTime.utc(2026, 11, 26, 12);

  String json(List<Map<String, dynamic>> locales) =>
      jsonEncode({'v': 1, 'locales': locales});

  test('solo cuentan los que tienen el periodo pagado vigente', () {
    final m = Recomanat.parse(
        json([
          {'osm': 'node/1', 'fin': '2026-12-20T00:00:00Z', 'estado': 'activo'},
          {'osm': 'node/2', 'fin': '2026-11-20T00:00:00Z', 'estado': 'activo'},
          // Dado de baja pero aún dentro de lo pagado: sigue hasta el final.
          {'osm': 'way/3', 'fin': '2026-11-30T00:00:00Z', 'estado': 'baja'},
          {'osm': 'node/4'}, // sin fecha: se ignora
          {'fin': '2026-12-20T00:00:00Z'}, // sin local: se ignora
        ]),
        ahora);
    expect(m.keys, unorderedEquals(['node/1', 'way/3']));
  });

  test('texto en el idioma de la app o en otro, y foto solo https', () {
    final m = Recomanat.parse(
        json([
          {
            'osm': 'node/1',
            'fin': '2027-01-01T00:00:00Z',
            'nombre': 'Bar Gòtic',
            'foto': 'http://inseguro.example/foto.jpg',
            'texto': {'ca': 'Terrassa al sol', 'es': '', 'en': 'Sunny terrace'},
          },
          {
            'osm': 'node/2',
            'fin': '2027-01-01T00:00:00Z',
            'foto': 'https://data.lat41lab.com/fotos/2.jpg',
          },
        ]),
        ahora);
    final r = m['node/1']!;
    expect(r.texto('en'), 'Sunny terrace');
    expect(r.texto('es'), 'Terrassa al sol'); // "es" vacío: el siguiente
    expect(r.texto('de'), 'Terrassa al sol');
    expect(r.foto, isNull);
    expect(m['node/2']!.foto, startsWith('https://'));
    expect(m['node/2']!.texto('ca'), isNull);
  });

  test('un archivo raro no rompe nada', () {
    expect(Recomanat.parse('[]', ahora), isEmpty);
    expect(Recomanat.parse('{"locales": 3}', ahora), isEmpty);
  });

  test('el enlace de pago lleva el local en client_reference_id', () {
    final u = LocalesConfig.pagoPara('node/123');
    expect(u.host, 'buy.stripe.com');
    expect(u.queryParameters['client_reference_id'], 'node_123');
    expect(LocalesConfig.paginaLocales('ca').toString(),
        'https://lat41lab.com/locals.html?lang=ca');
    // iPhone: la web; Android: el pago con el local.
    expect(LocalesConfig.destacarPara('node/1', 'es', ios: true).toString(),
        'https://lat41lab.com/locals.html?lang=es');
    expect(LocalesConfig.destacarPara('node/1', 'es', ios: false)
        .queryParameters['client_reference_id'], 'node_1');
  });
}
