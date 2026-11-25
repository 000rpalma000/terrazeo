import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:terrazeo/services/overpass.dart';

const _lleno = '# 502 Gateway Timeout\n\nThis Overpass API server is currently at '
    'capacity. All query workers are busy and the request queue is full.';

/// Overpass con tiempos cortos para probar (las proporciones son las reales).
Overpass _op(http.Client c, {Duration total = const Duration(seconds: 5)}) =>
    Overpass(
      c,
      userAgent: 'test',
      servidores: const ['https://a/api', 'https://b/api', 'https://c/api'],
      limitePorServidor: const Duration(milliseconds: 400),
      limiteTotal: total,
      relevo: const Duration(milliseconds: 150),
      esperas: const [
        Duration(milliseconds: 20),
        Duration(milliseconds: 40),
        Duration(milliseconds: 80),
      ],
    );

void main() {
  test('Todos llenos: 4 intentos repartidos, esperas crecientes y error claro',
      () async {
    final llamadas = <String>[];
    final reloj = Stopwatch()..start();
    final tiempos = <int>[];
    final c = MockClient((r) async {
      llamadas.add(r.url.host);
      tiempos.add(reloj.elapsedMilliseconds);
      return http.Response(_lleno, 502);
    });
    await expectLater(
      _op(c).consultar('q'),
      throwsA(isA<OverpassNoDisponible>()
          .having((e) => e.saturado, 'saturado', isTrue)),
    );
    expect(llamadas, ['a', 'b', 'c', 'a']);
    // Entre intentos: ≥20, ≥40 y ≥80 ms.
    expect(tiempos[1] - tiempos[0], greaterThanOrEqualTo(20));
    expect(tiempos[2] - tiempos[1], greaterThanOrEqualTo(40));
    expect(tiempos[3] - tiempos[2], greaterThanOrEqualTo(80));
    expect(reloj.elapsedMilliseconds, lessThan(1000));
  });

  test('Uno lleno y el siguiente bien: devuelve la respuesta buena', () async {
    final c = MockClient((r) async => r.url.host == 'a'
        ? http.Response(_lleno, 502)
        : http.Response('{"elements":[]}', 200));
    expect(await _op(c).consultar('q'), '{"elements":[]}');
  });

  test('Respeta Retry-After: no vuelve a ese servidor antes de tiempo',
      () async {
    final llamadas = <String>[];
    final c = MockClient((r) async {
      llamadas.add(r.url.host);
      if (r.url.host == 'a') {
        return http.Response('demasiadas', 429, headers: {'retry-after': '60'});
      }
      return http.Response('ocupado', 503);
    });
    await expectLater(_op(c).consultar('q'),
        throwsA(isA<OverpassNoDisponible>()));
    expect(llamadas.where((h) => h == 'a'), hasLength(1));
    expect(llamadas, hasLength(4));
  });

  test('Un servidor que no contesta no bloquea: se prueba otro al relevo',
      () async {
    final c = MockClient((r) async {
      if (r.url.host == 'a') {
        await Future<void>.delayed(const Duration(seconds: 10));
      }
      return http.Response('{"ok":1}', 200);
    });
    final reloj = Stopwatch()..start();
    expect(await _op(c).consultar('q'), '{"ok":1}');
    expect(reloj.elapsedMilliseconds, lessThan(400)); // relevo a los 150 ms
  });

  test('Límite total: si nadie contesta, falla a tiempo', () async {
    final c = MockClient((r) async {
      await Future<void>.delayed(const Duration(seconds: 10));
      return http.Response('tarde', 200);
    });
    final reloj = Stopwatch()..start();
    await expectLater(
        _op(c, total: const Duration(milliseconds: 700)).consultar('q'),
        throwsA(isA<OverpassNoDisponible>()));
    expect(reloj.elapsedMilliseconds, lessThan(1000));
  });

  test('Retry-After en formato fecha HTTP', () {
    final d = HttpFecha.parse('Wed, 21 Oct 2026 07:28:00 GMT');
    expect(d, DateTime.utc(2026, 10, 21, 7, 28));
  });
}
