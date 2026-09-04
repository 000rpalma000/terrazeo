/// Estima la altura de un edificio (en metros) a partir de sus etiquetas OSM.
///
/// Cadena de descarte pensada para funcionar en cualquier ciudad, sin tablas
/// por país: se autocalibra con los edificios de la propia zona descargada.
///
///   1. `height` / `building:height`
///   2. `building:levels` (+ `roof:levels`) × metros por planta
///   3. tipo de edificio "pequeño" conocido (casa, garaje, nave industrial…)
///   4. mediana local de plantas (edificios cercanos que sí tienen dato)
///   5. tipo de edificio genérico (apartments, office, church…)
///   6. constante global
class BuildingHeightEstimator {
  BuildingHeightEstimator({
    this.metrosPorPlanta = 3.1,
    this.alturaGlobalM = 10,
  });

  final double metrosPorPlanta;
  final double alturaGlobalM;

  double? _medianaPlantasLocal;

  /// Mediana de plantas de la zona, o `null` si no había ningún dato.
  double? get medianaPlantasLocal => _medianaPlantasLocal;

  /// Llamar UNA vez con las etiquetas de todos los edificios de la zona antes
  /// de estimar, para fijar la referencia local.
  void calibrar(Iterable<Map<String, dynamic>> etiquetasDeCadaEdificio) {
    final plantas = <double>[];
    for (final tags in etiquetasDeCadaEdificio) {
      final l = levels(tags);
      final h = heightTag(tags);
      if (l != null) {
        plantas.add(l);
      } else if (h != null) {
        plantas.add(h / metrosPorPlanta);
      }
    }
    _medianaPlantasLocal = plantas.isEmpty ? null : _mediana(plantas);
  }

  double estimar(Map<String, dynamic> tags) {
    final h = heightTag(tags);
    if (h != null) return h;

    final l = levels(tags);
    if (l != null) return l * metrosPorPlanta;

    final tipo = (tags['building'] ?? '').toString();

    final pequeno = _plantasTipoPequeno[tipo];
    if (pequeno != null) return pequeno * metrosPorPlanta;

    if (_medianaPlantasLocal != null) {
      return _medianaPlantasLocal! * metrosPorPlanta;
    }

    final generico = _plantasTipoGenerico[tipo];
    if (generico != null) return generico * metrosPorPlanta;

    return alturaGlobalM;
  }

  // --- lectura de etiquetas ------------------------------------------------

  static double? heightTag(Map<String, dynamic> tags) {
    final raw = tags['height'] ?? tags['building:height'];
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();

    // pies: 45' , 45 ft , 45'6"  -> aproximamos a los pies enteros
    final pies = RegExp(r"^([\d.]+)\s*(?:'|ft\b)").firstMatch(s);
    if (pies != null) {
      final v = double.tryParse(pies.group(1)!);
      return (v != null && v > 0) ? v * 0.3048 : null;
    }

    final m = RegExp(r'[\d.]+').firstMatch(s);
    final v = m == null ? null : double.tryParse(m.group(0)!);
    return (v != null && v > 0) ? v : null;
  }

  /// `building:levels` + `roof:levels` sumados. `null` si no hay ninguno.
  static double? levels(Map<String, dynamic> tags) {
    var suma = 0.0;
    var hay = false;
    for (final k in const ['building:levels', 'roof:levels']) {
      final raw = tags[k];
      if (raw == null) continue;
      final v = double.tryParse(raw.toString().split(';').first.trim());
      if (v != null && v > 0) {
        suma += v;
        hay = true;
      }
    }
    return hay ? suma : null;
  }

  static double _mediana(List<double> xs) {
    xs.sort();
    final n = xs.length;
    return n.isOdd ? xs[n ~/ 2] : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2;
  }

  /// Tipos claramente bajos: su valor es más fiable que la mediana del barrio.
  static const _plantasTipoPequeno = <String, double>{
    'house': 2, 'detached': 2, 'semidetached_house': 2, 'terrace': 2,
    'bungalow': 1, 'cabin': 1, 'hut': 1, 'shed': 1, 'static_caravan': 1,
    'garage': 1, 'garages': 1, 'carport': 1, 'roof': 1, 'container': 1,
    'kiosk': 1, 'industrial': 1, 'warehouse': 1, 'hangar': 1,
    'farm_auxiliary': 1, 'barn': 1, 'retail': 2, 'supermarket': 1,
    'service': 1, 'transformer_tower': 1,
  };

  /// Tipos altos/medios: solo se usan si no hay mediana local.
  static const _plantasTipoGenerico = <String, double>{
    'apartments': 5, 'residential': 4, 'dormitory': 5, 'hotel': 6,
    'commercial': 4, 'office': 5, 'school': 3, 'university': 4,
    'college': 4, 'hospital': 5, 'church': 4, 'cathedral': 5, 'temple': 3,
    'mosque': 3, 'public': 4, 'civic': 4, 'government': 5, 'tower': 12,
  };
}
