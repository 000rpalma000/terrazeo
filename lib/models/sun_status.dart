/// Estado de sol/sombra en un punto y momento dados.
enum SunStatus {
  pleno, // sol directo, cielo despejado
  solConNubes, // sol directo pero con nubes
  nublado, // muy nublado: da igual la geometría
  sombraPorEdificios, // de día, pero un edificio tapa el sol
  noche, // el sol está bajo el horizonte
}

extension SunStatusInfo on SunStatus {
  bool get haySolDirecto =>
      this == SunStatus.pleno || this == SunStatus.solConNubes;
}

/// Combina la geometría (¿un edificio tapa el sol?) con la nubosidad de AEMET.
SunStatus combinarSunStatus({
  required bool esDeDia,
  required bool tapadoPorEdificio,
  double? cloudFraction,
}) {
  if (!esDeDia) return SunStatus.noche;
  if (tapadoPorEdificio) return SunStatus.sombraPorEdificios;
  if (cloudFraction != null && cloudFraction >= 0.7) return SunStatus.nublado;
  if (cloudFraction != null && cloudFraction >= 0.35) {
    return SunStatus.solConNubes;
  }
  return SunStatus.pleno;
}
