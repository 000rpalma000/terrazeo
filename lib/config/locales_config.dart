/// Enlaces para los dueños de locales ("Recomanat per Terrazeo"). El cobro
/// se hace en la web, fuera de la app: la app solo abre el navegador, tanto
/// en iPhone como en Android (normas de pago de App Store y Google Play).
class LocalesConfig {
  static const correo = 'hola@lat41lab.com';

  /// Página para los locales en la web, en el idioma de la app.
  static Uri paginaLocales(String idioma) =>
      Uri.https('lat41lab.com', '/locals', {'lang': idioma});
}
