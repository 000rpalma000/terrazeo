import 'package:flutter/material.dart';

import '../models/ciutat.dart';

/// Ciudades con datos propios, agrupadas por país, en el idioma de la app.
class CiutatsLista extends StatelessWidget {
  const CiutatsLista(this.ciutats, {super.key});

  final List<Ciutat> ciutats;

  @override
  Widget build(BuildContext context) {
    final idioma = Localizations.localeOf(context).languageCode;
    final t = Theme.of(context).textTheme;
    final porPais = <String, List<String>>{};
    for (final c in ciutats) {
      porPais.putIfAbsent(c.paisNom(idioma), () => []).add(c.nom(idioma));
    }
    final paises = porPais.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in paises)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$p: ', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              TextSpan(text: (porPais[p]!..sort()).join(', '), style: t.bodyMedium),
            ])),
          ),
      ],
    );
  }
}
