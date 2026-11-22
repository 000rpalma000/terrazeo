import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Locales destacados (de pago): salen primero en la lista y con un marcador
/// distinto en el mapa, siempre con la etiqueta "Patrocinado" (la normativa
/// europea de consumo obliga a indicar cuándo un orden está pagado).
///
/// Hoy está **apagado**: `assets/data/destacados.json` es una lista vacía y no
/// hay URL remota. Para activarlo más adelante ver docs/MONETIZACION.md.
///
/// Formato (local o remoto):
///   {"destacados": [{"osmId": "node/123", "hasta": "2027-06-30"}, ...]}
/// `hasta` (opcional) es el último día de la suscripción: pasado ese día el
/// local deja de destacarse solo, aunque no se actualice la lista.
class DestacadosService {
  const DestacadosService();

  /// URL de la lista remota (p. ej. un JSON en GitHub Pages o en tu backend).
  /// Vacía = solo se usa el archivo empaquetado. Se puede pasar al compilar:
  ///   --dart-define=DESTACADOS_URL=https://…/destacados.json
  static const _url = String.fromEnvironment('DESTACADOS_URL');

  Future<Set<String>> cargar() async {
    final ids = <String>{};
    try {
      ids.addAll(_parsear(
          await rootBundle.loadString('assets/data/destacados.json')));
    } catch (_) {}
    if (_url.isNotEmpty) {
      try {
        final r = await http
            .get(Uri.parse(_url))
            .timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) {
          ids.addAll(_parsear(utf8.decode(r.bodyBytes)));
        }
      } catch (_) {}
    }
    return ids;
  }

  static Set<String> _parsear(String txt) {
    final hoy = DateTime.now();
    final d = jsonDecode(txt) as Map<String, dynamic>;
    return {
      for (final e in (d['destacados'] as List? ?? const []))
        if (e is Map &&
            e['osmId'] is String &&
            (e['hasta'] == null ||
                !hoy.isAfter(
                    DateTime.parse(e['hasta'] as String)
                        .add(const Duration(days: 1)))))
          e['osmId'] as String,
    };
  }
}
