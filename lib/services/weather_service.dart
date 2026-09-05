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

  /// "Ahora" + predicción en una pasada. Comparte la decisión de fuente y, con
  /// Open-Meteo, ahorra una petición (trae ambas cosas juntas).
  Future<({WeatherConditions? ahora, List<WeatherConditions> prevision})>
      condicionesYPrevision(LatLng p) async {
    if (await _usarAemet(p)) {
      WeatherConditions? ahora;
      List<WeatherConditions> prevision = const [];
      try {
        ahora = await _aemet.condicionesActualesEnPunto(p);
      } catch (_) {}
      try {
        prevision = await _aemet.previsionHorariaEnPunto(p);
      } catch (_) {}
      if (ahora != null || prevision.isNotEmpty) {
        return (ahora: ahora, prevision: prevision);
      }
    }
    try {
      return await _openMeteo.todo(p);
    } catch (_) {
      return (ahora: null, prevision: const <WeatherConditions>[]);
    }
  }

  void dispose() {
    _aemet.dispose();
    _openMeteo.dispose();
  }
}
