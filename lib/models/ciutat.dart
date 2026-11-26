import 'dart:convert';

import 'package:latlong2/latlong.dart';

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
  });

  final String id;
  final Map<String, String> noms;
  final String pais;
  final Map<String, String> paisNoms;

  /// [sur, oeste, norte, este].
  final List<double> caixa;

  /// Si en esta ciudad se ofrece "Aparecer como recomendado".
  final bool vendaRecomanats;

  bool conte(LatLng p) =>
      p.latitude >= caixa[0] &&
      p.latitude <= caixa[2] &&
      p.longitude >= caixa[1] &&
      p.longitude <= caixa[3];

  String nom(String idioma) => _en(noms, idioma) ?? id;
  String paisNom(String idioma) => _en(paisNoms, idioma) ?? pais.toUpperCase();

  static String? _en(Map<String, String> m, String idioma) =>
      m[idioma] ?? m['en'] ?? m['es'];

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
        ));
      } catch (_) {}
    }
    return out;
  }
}
