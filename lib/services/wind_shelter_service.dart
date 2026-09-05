import 'package:latlong2/latlong.dart';

import '../models/geo.dart';
import '../models/shadow_map.dart';

/// Estima cuánto **resguardan del viento** los edificios cercanos a un punto:
/// mira si hay construcción a barlovento (de donde viene el viento) y, si la
/// hay, cuánto tapa según su altura y su distancia.
///
/// Es una heurística geométrica, del mismo nivel de fidelidad que el motor de
/// sombras: no resuelve el flujo del aire. Un edificio de altura `H` a
/// distancia `D` a barlovento deja tras de sí una zona de calma fuerte hasta
/// ~2·H y que se disipa hacia ~7·H.
///
/// **No** modela: encañonamiento (calles alineadas con el viento que lo
/// aceleran), turbulencia/racheo de esquina, porosidad (soportales, huecos,
/// árboles), ni la altura real de la terraza (todo se evalúa a ras de suelo).
class WindShelterService {
  const WindShelterService();

  /// Distancia máxima a la que se busca un edificio a barlovento.
  static const double alcanceM = 100;

  /// Paso de muestreo al avanzar por cada rayo.
  static const double pasoM = 5;

  /// Altura mínima para que un edificio cuente como pantalla.
  static const double alturaMinimaM = 3;

  /// A cuántas "alturas de edificio" por detrás llega el efecto de resguardo.
  static const double alcanceEstelaEnAlturas = 7;

  /// Ni el mejor rincón queda del todo en calma: el aire rebordea el edificio.
  static const double reduccionMaxima = 0.9;

  /// Rayos que se lanzan hacia barlovento: el central y pares oblicuos, para
  /// captar también edificios que tapan de refilón.
  static const List<({double desvioDeg, double peso})> _rayos = [
    (desvioDeg: 0, peso: 3),
    (desvioDeg: -25, peso: 1),
    (desvioDeg: 25, peso: 1),
    (desvioDeg: -50, peso: 0.5),
    (desvioDeg: 50, peso: 0.5),
  ];

  /// Factor de resguardo 0..1 (0 = a cielo abierto, 1 = totalmente a resguardo)
  /// en [punto], para un viento que sopla **desde** [vientoDesdeDeg] (grados
  /// meteorológicos). [edificios] conviene tenerlos ya filtrados a la zona.
  double abrigo(
    LatLng punto,
    List<BuildingFootprint> edificios,
    double? vientoDesdeDeg,
  ) {
    if (vientoDesdeDeg == null || edificios.isEmpty) return 0;

    // Cajas envolventes de los edificios que podrían entrar en el alcance
    // (se calculan una vez y sirven de descarte rápido en el marchado).
    final cerca = <_EdificioBbox>[];
    for (final e in edificios) {
      if (e.heightM < alturaMinimaM || e.ring.length < 3) continue;
      if (Geo.distancia(punto, e.ring.first) > alcanceM + 150) continue;
      cerca.add(_EdificioBbox.of(e));
    }
    if (cerca.isEmpty) return 0;

    var suma = 0.0;
    var pesos = 0.0;
    for (final rayo in _rayos) {
      final rumbo = (vientoDesdeDeg + rayo.desvioDeg) % 360;
      suma += rayo.peso * _abrigoEnRayo(punto, rumbo, cerca);
      pesos += rayo.peso;
    }
    return (suma / pesos).clamp(0.0, 1.0);
  }

  double _abrigoEnRayo(
    LatLng origen,
    double rumbo,
    List<_EdificioBbox> edificios,
  ) {
    for (var d = pasoM; d <= alcanceM; d += pasoM) {
      final s = Geo.destino(origen, rumbo, d);
      for (final e in edificios) {
        if (!e.contieneBbox(s)) continue;
        if (Geo.dentroDePoligono(s, e.edificio.ring)) {
          final alcanceEstela = alcanceEstelaEnAlturas * e.edificio.heightM;
          return (1 - d / alcanceEstela).clamp(0.0, 1.0);
        }
      }
    }
    return 0;
  }

  /// Viento que se sentiría en el punto tras aplicar el resguardo.
  static double vientoLocal(double vientoKmh, double abrigo) =>
      vientoKmh * (1 - abrigo.clamp(0.0, 1.0) * reduccionMaxima);
}

class _EdificioBbox {
  final BuildingFootprint edificio;
  final double minLat, maxLat, minLon, maxLon;

  _EdificioBbox._(
      this.edificio, this.minLat, this.maxLat, this.minLon, this.maxLon);

  factory _EdificioBbox.of(BuildingFootprint e) {
    var minLat = e.ring.first.latitude, maxLat = minLat;
    var minLon = e.ring.first.longitude, maxLon = minLon;
    for (final p in e.ring) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return _EdificioBbox._(e, minLat, maxLat, minLon, maxLon);
  }

  bool contieneBbox(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLon &&
      p.longitude <= maxLon;
}
