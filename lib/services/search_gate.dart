import 'package:shared_preferences/shared_preferences.dart';

/// Cuenta las "búsquedas" del usuario y decide cuándo toca mostrar un
/// anuncio, con estado persistente (sobrevive a cerrar la app).
///
/// Modelo de monetización: cada [cadaN] búsquedas se muestra un anuncio.
/// Comprar "quitar anuncios" pone [anunciosEliminados] a `true` para siempre.
///
/// De momento la "compra" es un mock local (solo guarda la preferencia). El
/// cobro real (in_app_purchase + producto en App Store Connect / Play
/// Console) se conecta más adelante sin cambiar esta clase por fuera.
class SearchGate {
  static const cadaN = 3;
  static const _kContador = 'search_gate_contador';
  static const _kSinAnuncios = 'search_gate_sin_anuncios';

  /// Registra una búsqueda y devuelve `true` si toca mostrar un anuncio.
  Future<bool> registrarBusqueda() async {
    final sp = await SharedPreferences.getInstance();
    if (sp.getBool(_kSinAnuncios) ?? false) return false;

    final n = (sp.getInt(_kContador) ?? 0) + 1;
    await sp.setInt(_kContador, n);
    return n % cadaN == 0;
  }

  Future<bool> anunciosEliminados() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kSinAnuncios) ?? false;
  }

  /// TODO: sustituir por una compra real (in_app_purchase) cuando haya
  /// cuentas de App Store Connect / Play Console con el producto creado.
  Future<void> eliminarAnunciosMock() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSinAnuncios, true);
  }
}
