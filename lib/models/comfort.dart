import 'dart:math' as math;

import 'sun_status.dart';

/// Cómo de a gusto se está ahora mismo en un sitio al aire libre.
enum ComfortLevel { muyAgradable, agradable, justo, incomodo }

/// Frase principal del veredicto.
enum ComfortHeadline {
  agradable,
  brisaAgradable, // sombra + brisa, en modo "busco sombra"
  solFuerte, // sol pleno sin viento, en modo "busco sombra" -> malo
  solAgradable, // sol pleno y calma, en modo "busco sol" -> bueno
  frioViento, // sombra o viento, en modo "busco sol" -> malo
  ventoso,
  noche,
}

/// Matices que se muestran como etiquetas (describen la condición, no el
/// veredicto: son las mismas se busque sol o sombra).
enum ComfortFlag { solFuerte, sombra, ventoso, brisa, resguardado }

class ComfortVerdict {
  final ComfortLevel level;
  final ComfortHeadline headline;
  final Set<ComfortFlag> flags;

  /// `true` si, dadas la época del año y la temperatura, lo que conviene es
  /// sombra y ventilación (modo "verano"); `false` si conviene sol y calma
  /// (modo "invierno"). Solo para depuración/transparencia.
  final bool buscaSombra;

  const ComfortVerdict({
    required this.level,
    required this.headline,
    required this.flags,
    required this.buscaSombra,
  });
}

/// Heurística de confort basada en **sol/sombra, viento — y qué conviene
/// según la época del año y la temperatura actual**.
///
/// La misma exposición al sol es buena o mala según el momento: si hace calor
/// (verano, o un día cálido) lo ideal es sombra + brisa; si hace frío
/// (invierno, o un día fresco) lo ideal es justo lo contrario, sol y calma.
/// Y una misma temperatura no pesa igual en cada época: 22 °C en enero pide
/// sol; 22 °C en agosto pide sombra. Por eso el umbral que decide "toca
/// sombra" se desplaza según lo avanzada que esté la estación (calculada a
/// partir de la fecha **y del hemisferio real del punto**, con su latitud,
/// para que funcione en cualquier ciudad).
ComfortVerdict evaluarConfort({
  required SunStatus sunStatus,
  required DateTime instante,
  required double latitud,
  double? windKmh,
  double? tempC,
  double abrigo = 0,
}) {
  final w = windKmh ?? 0.0;
  // Si los edificios cortan el viento de forma clara, el sitio es "resguardado"
  // aunque el pronóstico regional traiga algo de brisa (que aquí ya no llega).
  final resguardadoPorEdificios = abrigo >= 0.35;
  final haySombra =
      sunStatus == SunStatus.sombraPorEdificios || sunStatus == SunStatus.nublado;
  final solPleno = sunStatus == SunStatus.pleno;
  final esDeNoche = sunStatus == SunStatus.noche;

  final factorVerano = _factorEstacional(instante, latitud); // 0 invierno..1 verano
  // El umbral de "toca sombra" baja en verano (basta con 23°C) y sube en
  // invierno (hace falta un día raro, de 27°C+, para que compense la sombra).
  final umbralSombra = _lerp(27, 23, factorVerano);
  final buscaSombra = tempC != null ? tempC >= umbralSombra : factorVerano >= 0.5;

  final flags = <ComfortFlag>{};
  if (solPleno) flags.add(ComfortFlag.solFuerte);
  if (haySombra) flags.add(ComfortFlag.sombra);
  if (w >= 30) {
    flags.add(ComfortFlag.ventoso);
  } else if (w >= 8 && !resguardadoPorEdificios) {
    flags.add(ComfortFlag.brisa);
  } else {
    flags.add(ComfortFlag.resguardado);
  }

  // El viento excesivo estropea cualquier sitio, se busque sol o sombra.
  if (w >= 40) {
    return ComfortVerdict(
      level: ComfortLevel.incomodo,
      headline: ComfortHeadline.ventoso,
      flags: flags,
      buscaSombra: buscaSombra,
    );
  }
  if (esDeNoche) {
    return ComfortVerdict(
      level: ComfortLevel.agradable,
      headline: ComfortHeadline.noche,
      flags: flags,
      buscaSombra: buscaSombra,
    );
  }

  ComfortLevel level;
  ComfortHeadline headline;

  if (buscaSombra) {
    // Modo "hace calor": lo ideal es sombra + brisa.
    if (haySombra) {
      if (w >= 8 && w < 30) {
        level = ComfortLevel.muyAgradable;
        headline = ComfortHeadline.brisaAgradable;
      } else if (w >= 30) {
        level = ComfortLevel.justo;
        headline = ComfortHeadline.ventoso;
      } else {
        level = ComfortLevel.agradable;
        headline = ComfortHeadline.agradable;
      }
    } else if (solPleno) {
      level = w >= 8 ? ComfortLevel.justo : ComfortLevel.incomodo;
      headline = ComfortHeadline.solFuerte;
    } else {
      // sol con nubes
      level = w >= 8 ? ComfortLevel.agradable : ComfortLevel.justo;
      headline = w >= 8 ? ComfortHeadline.brisaAgradable : ComfortHeadline.agradable;
    }
  } else {
    // Modo "hace frío": lo ideal es sol + calma (justo al revés).
    if (solPleno) {
      if (w < 15) {
        level = ComfortLevel.muyAgradable;
        headline = ComfortHeadline.solAgradable;
      } else if (w < 30) {
        level = ComfortLevel.justo;
        headline = ComfortHeadline.ventoso;
      } else {
        level = ComfortLevel.incomodo;
        headline = ComfortHeadline.ventoso;
      }
    } else if (haySombra) {
      level = w < 8 ? ComfortLevel.justo : ComfortLevel.incomodo;
      headline = ComfortHeadline.frioViento;
    } else {
      // sol con nubes
      level = w < 15 ? ComfortLevel.agradable : ComfortLevel.justo;
      headline = w < 15 ? ComfortHeadline.solAgradable : ComfortHeadline.ventoso;
    }
  }

  return ComfortVerdict(
    level: level,
    headline: headline,
    flags: flags,
    buscaSombra: buscaSombra,
  );
}

double _lerp(double invierno, double verano, double t) =>
    invierno + (verano - invierno) * t;

/// 0 = pleno invierno, 1 = pleno verano, con transición suave a lo largo del
/// año. El pico de verano se desplaza medio año según el hemisferio (según el
/// signo de la latitud), para que tenga sentido en cualquier ciudad.
double _factorEstacional(DateTime instante, double latitud) {
  final diaDelAnio =
      instante.difference(DateTime(instante.year, 1, 1)).inDays + 1;
  final picoVeranoNorte = 202.0; // ~21 de julio
  final pico = latitud >= 0 ? picoVeranoNorte : picoVeranoNorte - 182.5;
  final angulo = 2 * math.pi * (diaDelAnio - pico) / 365.25;
  return (1 + math.cos(angulo)) / 2;
}
