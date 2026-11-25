import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrazeo/models/weather_conditions.dart';
import 'package:terrazeo/services/aemet_service.dart';
import 'package:terrazeo/services/open_meteo_service.dart';
import 'package:terrazeo/services/weather_service.dart';

typedef _T = ({WeatherConditions? ahora, List<WeatherConditions> prevision});

WeatherConditions _w(double t) => WeatherConditions(
      timestamp: DateTime(2026, 7, 1, 12),
      esPrevision: false,
      sky: const SkyState(),
      temperatureC: t,
    );

/// AEMET falso: tarda [retraso] y devuelve [res]. Cuenta las llamadas.
class _Aemet extends AemetService {
  _Aemet(this.retraso, this.res) : super();
  final Duration retraso;
  final _T res;
  int llamadas = 0;

  @override
  Future<({String codigo, double distanciaM})?> municipioCercano(
          LatLng p) async =>
      (codigo: '08019', distanciaM: 500.0);

  @override
  Future<_T> condicionesYPrevisionEnPunto(LatLng p) async {
    llamadas++;
    await Future<void>.delayed(retraso);
    return res;
  }
}

class _OpenMeteo extends OpenMeteoService {
  @override
  Future<_T> todo(LatLng p) async => (ahora: _w(10), prevision: [_w(11), _w(12)]);
}

void main() {
  const bcn = LatLng(41.383, 2.1755);
  const paris = LatLng(48.8566, 2.3522);

  test('AEMET rápido: solo se emite AEMET, una vez', () async {
    final aemet = _Aemet(const Duration(milliseconds: 50),
        (ahora: _w(20), prevision: [_w(21)]));
    final s = WeatherService(aemet: aemet, openMeteo: _OpenMeteo());
    final emitidos = await s.condicionesYPrevisionEnVivo(bcn).toList();
    expect(emitidos, hasLength(1));
    expect(emitidos.single.ahora!.temperatureC, 20);
    expect(aemet.llamadas, 1);
  });

  test('AEMET lento: primero Open-Meteo y luego AEMET', () async {
    final aemet = _Aemet(WeatherService.esperaAemet * 2,
        (ahora: _w(20), prevision: [_w(21)]));
    final s = WeatherService(aemet: aemet, openMeteo: _OpenMeteo());
    final reloj = Stopwatch()..start();
    final tiempos = <int>[];
    final temps = <double?>[];
    await for (final t in s.condicionesYPrevisionEnVivo(bcn)) {
      tiempos.add(reloj.elapsedMilliseconds);
      temps.add(t.ahora?.temperatureC);
    }
    expect(temps, [10, 20]);
    // Open-Meteo sale al acabar la espera, sin aguardar a AEMET.
    expect(tiempos.first,
        lessThan(WeatherService.esperaAemet.inMilliseconds + 500));
  });

  test('AEMET sin predicción (límite de uso): se completa con Open-Meteo',
      () async {
    final aemet = _Aemet(
        const Duration(milliseconds: 10), (ahora: _w(20), prevision: const []));
    final s = WeatherService(aemet: aemet, openMeteo: _OpenMeteo());
    final r = await s.condicionesYPrevision(bcn);
    expect(r.ahora!.temperatureC, 20);
    expect(r.prevision, hasLength(2));
  });

  test('Fuera de España solo Open-Meteo, sin preguntar a AEMET', () async {
    final aemet = _Aemet(Duration.zero, (ahora: _w(20), prevision: [_w(21)]));
    final s = WeatherService(aemet: aemet, openMeteo: _OpenMeteo());
    final emitidos = await s.condicionesYPrevisionEnVivo(paris).toList();
    expect(emitidos.single.ahora!.temperatureC, 10);
    expect(aemet.llamadas, 0);
  });

  test('Open-Meteo recibe la zona (2 decimales), no la ubicación exacta', () {
    final q = OpenMeteoService.consulta(const LatLng(41.383712, 2.175549))
        .queryParameters;
    expect(q['latitude'], '41.38');
    expect(q['longitude'], '2.18');
  });
}
