import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Una ciudad con datos propios, de `ciutats.json` (lo genera la acción
/// mensual a partir de tool/datos/ciudades.json; ver generar_ciutats.py).
class Ciutat {
  const Ciutat({
    required this.id,
    required this.noms,
    required this.pais,
    required this.paisNoms,
    required this.caixa,
    required this.vendaRecomanats,
    this.contorn = const [],
  });

  final String id;
  final Map<String, String> noms;
  final String pais;
  final Map<String, String> paisNoms;

  /// [sur, oeste, norte, este].
  final List<double> caixa;

  /// Si en esta ciudad se ofrece "Aparecer como recomendado".
  final bool vendaRecomanats;

  /// Contorno real (polígonos simplificados), solo en las zonas hechas con
  /// límites oficiales, como la Regió Metropolitana de Barcelona: su caja
  /// incluye también comarcas de alrededor sin datos. Vacío: basta la caja.
  final List<List<LatLng>> contorn;

  bool conte(LatLng p) {
    final enCaixa = p.latitude >= caixa[0] &&
        p.latitude <= caixa[2] &&
        p.longitude >= caixa[1] &&
        p.longitude <= caixa[3];
    if (!enCaixa || contorn.isEmpty) return enCaixa;
    return contorn.any((anillo) => Geo.dentroDePoligono(p, anillo));
  }

  String nom(String idioma) => _en(noms, idioma) ?? id;
  String paisNom(String idioma) => _en(paisNoms, idioma) ?? pais.toUpperCase();

  static String? _en(Map<String, String> m, String idioma) =>
      m[idioma] ?? m['en'] ?? m['es'];

  /// [[lat0, lon0, lat1, lon1, …], …]; lo que no se entienda se ignora (y
  /// entonces vale la caja).
  static List<List<LatLng>> _contorn(Object? v) {
    if (v is! List) return const [];
    final out = <List<LatLng>>[];
    for (final pol in v) {
      if (pol is! List || pol.length < 6 || pol.length.isOdd) continue;
      final xs = pol.whereType<num>().toList();
      if (xs.length != pol.length) continue;
      out.add([
        for (var i = 0; i < xs.length; i += 2)
          LatLng(xs[i].toDouble(), xs[i + 1].toDouble()),
      ]);
    }
    return out;
  }

  static List<Ciutat> parse(String cuerpo) {
    final d = jsonDecode(cuerpo);
    if (d is! Map || d['ciutats'] is! List) return const [];
    final out = <Ciutat>[];
    for (final e in d['ciutats'] as List) {
      try {
        final m = e as Map;
        final caixa = (m['caixa'] as List).map((x) => (x as num).toDouble()).toList();
        if (caixa.length != 4) continue;
        out.add(Ciutat(
          id: m['id'] as String,
          noms: (m['nom'] as Map).cast<String, String>(),
          pais: m['pais'] as String,
          paisNoms: ((m['pais_nom'] as Map?) ?? const {}).cast<String, String>(),
          caixa: caixa,
          vendaRecomanats: m['venda_recomanats'] == true,
          contorn: _contorn(m['contorn']),
        ));
      } catch (_) {}
    }
    return out;
  }
}
