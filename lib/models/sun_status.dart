/// Estado de sol/sombra en un punto y momento dados.
enum SunStatus {
  pleno, // sol directo, cielo despejado
  solConNubes, // sol directo pero con nubes
  nublado, // muy nublado: da igual la geometría
  sombraPorEdificios, // de día, pero un edificio tapa el sol
  noche, // el sol está bajo el horizonte
  solParcial, // terraza: parte de las mesas al sol y parte a la sombra
}

extension SunStatusInfo on SunStatus {
  bool get haySolDirecto =>
      this == SunStatus.pleno ||
      this == SunStatus.solConNubes ||
      this == SunStatus.solParcial;
}

/// Combina la geometría (¿un edificio tapa el sol?) con la nubosidad de AEMET.
///
/// Con [fraccionEnSombra] (los puntos de una terraza que quedan a la sombra,
/// de 0 a 1): dos tercios o más → sombra; un tercio o menos → sol; en medio,
/// sol parcial.
SunStatus combinarSunStatus({
  required bool esDeDia,
  required bool tapadoPorEdificio,
  double? cloudFraction,
  double? fraccionEnSombra,
}) {
  if (!esDeDia) return SunStatus.noche;
  if (tapadoPorEdificio) return SunStatus.sombraPorEdificios;
  if (fraccionEnSombra != null && fraccionEnSombra >= 2 / 3) {
    return SunStatus.sombraPorEdificios;
  }
  if (cloudFraction != null && cloudFraction >= 0.7) return SunStatus.nublado;
  if (fraccionEnSombra != null && fraccionEnSombra > 1 / 3) {
    return SunStatus.solParcial;
  }
  if (cloudFraction != null && cloudFraction >= 0.35) {
    return SunStatus.solConNubes;
  }
  return SunStatus.pleno;
}
