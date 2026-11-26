import '../models/ciutat.dart';
import '../models/recomanat.dart';
import 'json_remoto.dart';

/// Locales recomendados (`recomanats.json` en R2, lo mantiene el Worker de
/// Stripe de `cloudflare/recomanats/`). Vale 1 hora; sin red, la última
/// copia. Si nunca se ha podido descargar, no hay recomendados.
class RecomanatsService {
  final _json = JsonRemoto(
      const String.fromEnvironment('RECOMANATS_URL',
          defaultValue: 'https://data.lat41lab.com/recomanats.json'),
      'recomanats.json',
      const Duration(hours: 1));

  Future<Map<String, Recomanat>> cargar() async {
    final txt = await _json.cargar();
    if (txt == null) return {};
    try {
      return Recomanat.parse(txt, DateTime.now());
    } catch (_) {
      return {};
    }
  }

  void dispose() => _json.dispose();
}

/// Ciudades con datos propios (`ciutats.json`, lo genera la acción mensual).
/// Vale 1 día.
class CiutatsService {
  final _json = JsonRemoto(
      const String.fromEnvironment('CIUTATS_URL',
          defaultValue: 'https://data.lat41lab.com/ciutats.json'),
      'ciutats.json',
      const Duration(days: 1));

  Future<List<Ciutat>> cargar() async {
    final txt = await _json.cargar();
    if (txt == null) return const [];
    try {
      return Ciutat.parse(txt);
    } catch (_) {
      return const [];
    }
  }

  void dispose() => _json.dispose();
}
