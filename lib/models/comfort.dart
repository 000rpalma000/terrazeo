import 'sun_status.dart';

/// Cómo de a gusto se está ahora mismo en un sitio al aire libre.
enum ComfortLevel { muyAgradable, agradable, justo, incomodo }

/// Frase principal del veredicto.
enum ComfortHeadline {
  agradable,
  brisaAgradable,
  solFuerte,
  calorSombra,
  frescoMejorSol,
  ventoso,
  frio,
  noche,
}

/// Matices que se muestran como etiquetas.
enum ComfortFlag { solFuerte, sombra, ventoso, brisa, resguardado, fresco, calor }

class ComfortVerdict {
  final ComfortLevel level;

  /// Temperatura "de sensación" aproximada (sol suma, viento resta).
  final double sensacionC;

  final ComfortHeadline headline;
  final Set<ComfortFlag> flags;

  const ComfortVerdict({
    required this.level,
    required this.sensacionC,
    required this.headline,
    required this.flags,
  });
}

/// Heurística sencilla de confort para una terraza.
///
/// No pretende ser rigurosa: combina temperatura, si da el sol y el viento en
/// una única valoración orientativa. Fácil de ajustar.
ComfortVerdict evaluarConfort({
  required SunStatus sunStatus,
  double? tempC,
  double? windKmh,
}) {
  final t = tempC ?? 20.0;
  final w = windKmh ?? 0.0;

  var sensacion = t;
  switch (sunStatus) {
    case SunStatus.pleno:
      sensacion += 5;
      break;
    case SunStatus.solConNubes:
      sensacion += 2;
      break;
    case SunStatus.nublado:
    case SunStatus.sombraPorEdificios:
    case SunStatus.noche:
      break;
  }
  sensacion -= w / 12.0;

  final flags = <ComfortFlag>{};
  if (sunStatus == SunStatus.pleno && t >= 26) flags.add(ComfortFlag.solFuerte);
  if (sunStatus == SunStatus.sombraPorEdificios ||
      sunStatus == SunStatus.nublado) {
    flags.add(ComfortFlag.sombra);
  }
  if (w >= 25) {
    flags.add(ComfortFlag.ventoso);
  } else if (w >= 8 && sensacion >= 21) {
    flags.add(ComfortFlag.brisa);
  } else if (w < 6) {
    flags.add(ComfortFlag.resguardado);
  }
  if (sensacion < 16) flags.add(ComfortFlag.fresco);
  if (sensacion > 30) flags.add(ComfortFlag.calor);

  final ComfortLevel level;
  if (w >= 32 || sensacion >= 34 || sensacion <= 12) {
    level = ComfortLevel.incomodo;
  } else if (sensacion >= 21 && sensacion <= 28 && w < 22) {
    level = ComfortLevel.muyAgradable;
  } else if (sensacion >= 18 && sensacion <= 31 && w < 28) {
    level = ComfortLevel.agradable;
  } else {
    level = ComfortLevel.justo;
  }

  final ComfortHeadline headline;
  if (sunStatus == SunStatus.noche) {
    headline = ComfortHeadline.noche;
  } else if (flags.contains(ComfortFlag.calor) &&
      flags.contains(ComfortFlag.sombra)) {
    headline = ComfortHeadline.calorSombra;
  } else if (flags.contains(ComfortFlag.solFuerte)) {
    headline = ComfortHeadline.solFuerte;
  } else if (flags.contains(ComfortFlag.ventoso)) {
    headline = ComfortHeadline.ventoso;
  } else if (flags.contains(ComfortFlag.fresco) && !sunStatus.haySolDirecto) {
    headline = ComfortHeadline.frescoMejorSol;
  } else if (flags.contains(ComfortFlag.fresco)) {
    headline = ComfortHeadline.frio;
  } else if (flags.contains(ComfortFlag.brisa) &&
      (level == ComfortLevel.muyAgradable || level == ComfortLevel.agradable)) {
    headline = ComfortHeadline.brisaAgradable;
  } else {
    headline = ComfortHeadline.agradable;
  }

  return ComfortVerdict(
    level: level,
    sensacionC: sensacion,
    headline: headline,
    flags: flags,
  );
}
