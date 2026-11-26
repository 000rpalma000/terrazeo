import 'dart:convert';

/// Un local recomendado (de pago) de `recomanats.json`. Formato en
/// `cloudflare/recomanats/README.md`.
///
/// Ser recomendado **solo** cambia cómo se enseña el local (icono, etiqueta,
/// orden a igual confort y el filtro "Solo recomendados"); nunca los
/// cálculos de sol, sombra o viento.
class Recomanat {
  const Recomanat({
    required this.osmId,
    required this.fin,
    this.nombre = '',
    this.foto,
    this.textos = const {},
  });

  /// `node/123`, como [Bar.osmId].
  final String osmId;

  /// Fin del periodo pagado: deja de ser recomendado a partir de entonces.
  final DateTime fin;
  final String nombre;
  final String? foto;

  /// Texto propio del local por idioma (`ca`, `es`, `en`).
  final Map<String, String> textos;

  bool activoEn(DateTime t) => t.isBefore(fin);

  /// El texto en [idioma], o en otro de los disponibles si no lo hay.
  String? texto(String idioma) {
    for (final l in [idioma, 'es', 'ca', 'en']) {
      final t = textos[l]?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  /// Los recomendados vigentes en [ahora], por `osmId`. Lo que no se
  /// entienda se ignora (mejor sin recomendados que sin app).
  static Map<String, Recomanat> parse(String cuerpo, DateTime ahora) {
    final out = <String, Recomanat>{};
    final d = jsonDecode(cuerpo);
    if (d is! Map || d['locales'] is! List) return out;
    for (final e in d['locales'] as List) {
      if (e is! Map) continue;
      final osm = e['osm'], fin = DateTime.tryParse('${e['fin']}');
      if (osm is! String || fin == null) continue;
      final foto = e['foto'];
      final r = Recomanat(
        osmId: osm,
        fin: fin,
        nombre: (e['nombre'] ?? '').toString(),
        foto: foto is String && foto.startsWith('https://') ? foto : null,
        textos: {
          if (e['texto'] is Map)
            for (final t in (e['texto'] as Map).entries)
              if (t.value is String) '${t.key}': t.value as String,
        },
      );
      if (r.activoEn(ahora)) out[osm] = r;
    }
    return out;
  }
}
