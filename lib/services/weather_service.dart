import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../models/weather_conditions.dart';
import 'aemet_service.dart';
import 'open_meteo_service.dart';

/// Punto de entrada único para el tiempo. Decide la fuente según dónde esté el
/// punto:
///
///  * **En España** → AEMET (observación real + predicción oficial), eligiendo
///    estación y municipio por cercanía.
///  * **Fuera de España** → Open-Meteo (cobertura mundial, sin clave).
///
/// El "está en España" no usa una tabla de fronteras: mira a qué distancia
/// queda el municipio de AEMET más cercano. Los ~8000 municipios cubren todo
/// el país con una densidad de pocos km, así que un punto realmente en España
/// casi siempre cae muy cerca de uno, y uno de fuera queda lejos. Mismo
/// espíritu autocalibrante que el resto de la app.
///
/// Si AEMET falla dentro de España (sin clave, corte de red, límite de
/// peticiones), cae también a Open-Meteo para no quedarse sin datos.
typedef _Tiempo = ({WeatherConditions? ahora, List<WeatherConditions> prevision});

class WeatherService {
  WeatherService({AemetService? aemet, OpenMeteoService? openMeteo})
      : _aemet = aemet ?? AemetService(),
        _openMeteo = openMeteo ?? OpenMeteoService();

  final AemetService _aemet;
  final OpenMeteoService _openMeteo;

  /// Distancia máxima al municipio AEMET más cercano para considerar el punto
  /// "en España" (con margen para zonas rayanas).
  static const margenEspanaM = 25000.0;

  /// Rectángulos generosos que contienen España (Península + Baleares, y
  /// Canarias). Sólo sirven para descartar rápido puntos claramente lejanos
  /// (París, Londres…) y ahorrarles la descarga del maestro de municipios de
  /// AEMET. Dentro de la caja, la cercanía al municipio decide de verdad, así
  /// que da igual que la caja incluya el sur de Francia o Portugal.
  static bool plausibleEspana(LatLng p) {
    final lat = p.latitude, lon = p.longitude;
    final peninsulaYBaleares =
        lat >= 35.0 && lat <= 44.5 && lon >= -10.0 && lon <= 5.1;
    final canarias =
        lat >= 27.0 && lat <= 29.5 && lon >= -18.5 && lon <= -13.0;
    return peninsulaYBaleares || canarias;
  }

  Future<bool> _usarAemet(LatLng p) async {
    if (!plausibleEspana(p)) return false;
    final m = await _aemet.municipioCercano(p);
    return m != null && m.distanciaM <= margenEspanaM;
  }

  /// Condiciones "ahora" en [p].
  Future<WeatherConditions?> condicionesActuales(LatLng p) async {
    if (await _usarAemet(p)) {
      try {
        final r = await _aemet.condicionesActualesEnPunto(p);
        if (r != null) return r;
      } catch (_) {}
    }
    try {
      return await _openMeteo.condicionesActuales(p);
    } catch (_) {
      return null;
    }
  }

  /// Predicción horaria en [p].
  Future<List<WeatherConditions>> previsionHoraria(LatLng p) async {
    if (await _usarAemet(p)) {
      try {
        final r = await _aemet.previsionHorariaEnPunto(p);
        if (r.isNotEmpty) return r;
      } catch (_) {}
    }
    try {
      return await _openMeteo.previsionHoraria(p);
    } catch (_) {
      return const [];
    }
  }

  /// Cuánto se espera a AEMET antes de enseñar Open-Meteo.
  static const esperaAemet = Duration(milliseconds: 800);

  /// "Ahora" + predicción en [p], **en cuanto se pueda**:
  ///
  ///  * Open-Meteo y AEMET se piden a la vez.
  ///  * Si AEMET (solo en España) contesta antes de [esperaAemet], se emite
  ///    solo AEMET.
  ///  * Si tarda, se emite primero Open-Meteo y luego, cuando llega, AEMET.
  ///  * Si AEMET trae el "ahora" pero no la predicción (límite de uso de la
  ///    clave), la predicción se toma de Open-Meteo.
  ///
  /// Puede no emitir nada si fallan las dos fuentes.
  Stream<({WeatherConditions? ahora, List<WeatherConditions> prevision})>
      condicionesYPrevisionEnVivo(LatLng p) async* {
    final om = _openMeteo.todo(p).then<_Tiempo?>((v) => v, onError: (_) => null);
    if (!plausibleEspana(p)) {
      final r = await om;
      if (r != null) yield r;
      return;
    }
    final aemet = _aemetCompleto(p);
    final primero = await Future.any<(bool, _Tiempo?)>([
      aemet.then((v) => (true, v)),
      Future.delayed(esperaAemet, () => (false, null)),
    ]);
    if (primero.$1 && primero.$2 != null) {
      yield await _completar(primero.$2!, om);
      return;
    }
    final r = await om;
    if (r != null) yield r;
    if (primero.$1) return; // AEMET ya contestó, sin datos
    final a = await aemet;
    if (a != null) yield await _completar(a, om);
  }

  /// Igual que [condicionesYPrevisionEnVivo] pero solo el resultado final.
  Future<({WeatherConditions? ahora, List<WeatherConditions> prevision})>
      condicionesYPrevision(LatLng p) async {
    _Tiempo r = (ahora: null, prevision: const <WeatherConditions>[]);
    await for (final t in condicionesYPrevisionEnVivo(p)) {
      r = t;
    }
    return r;
  }

  /// AEMET en [p], o `null` si el punto no está en España o no hay datos.
  Future<_Tiempo?> _aemetCompleto(LatLng p) async {
    try {
      if (!await _usarAemet(p)) return null;
      final r = await _aemet.condicionesYPrevisionEnPunto(p);
      if (r.ahora == null && r.prevision.isEmpty) return null;
      return r;
    } catch (_) {
      return null;
    }
  }

  /// Rellena la predicción con la de Open-Meteo si AEMET no la trajo.
  static Future<_Tiempo> _completar(_Tiempo a, Future<_Tiempo?> om) async {
    if (a.prevision.isNotEmpty) return a;
    final r = await om;
    return (ahora: a.ahora ?? r?.ahora, prevision: r?.prevision ?? const []);
  }

  void dispose() {
    _aemet.dispose();
    _openMeteo.dispose();
  }
}
