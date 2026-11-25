import 'package:latlong2/latlong.dart';

import '../models/geo.dart';
import '../models/indice_espacial.dart';
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
    return abrigoConIndice(punto, IndiceEdificios(edificios), vientoDesdeDeg);
  }

  /// Igual que [abrigo] con los edificios ya indexados: cada paso del rayo
  /// mira solo los edificios de su celda.
  double abrigoConIndice(
    LatLng punto,
    IndiceEdificios edificios,
    double? vientoDesdeDeg,
  ) {
    if (vientoDesdeDeg == null || edificios.n == 0) return 0;
    var suma = 0.0;
    var pesos = 0.0;
    for (final rayo in _rayos) {
      final rumbo = (vientoDesdeDeg + rayo.desvioDeg) % 360;
      suma += rayo.peso * _abrigoEnRayo(punto, rumbo, edificios);
      pesos += rayo.peso;
    }
    return (suma / pesos).clamp(0.0, 1.0);
  }

  double _abrigoEnRayo(
    LatLng origen,
    double rumbo,
    IndiceEdificios edificios,
  ) {
    for (var d = pasoM; d <= alcanceM; d += pasoM) {
      final s = Geo.destino(origen, rumbo, d);
      final e = edificios.edificioEn(s, alturaMinM: alturaMinimaM);
      if (e != null) {
        final alcanceEstela = alcanceEstelaEnAlturas * e.heightM;
        return (1 - d / alcanceEstela).clamp(0.0, 1.0);
      }
    }
    return 0;
  }

  /// Viento que se sentiría en el punto tras aplicar el resguardo.
  static double vientoLocal(double vientoKmh, double abrigo) =>
      vientoKmh * (1 - abrigo.clamp(0.0, 1.0) * reduccionMaxima);
}
