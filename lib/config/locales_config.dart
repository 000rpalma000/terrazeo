/// Enlaces para los dueños de locales ("Recomanat per Terrazeo", cobro con
/// Stripe fuera de la app: la app solo abre el navegador).
class LocalesConfig {
  /// Enlace de pago de Stripe (5 €/mes, IVA incluido).
  static const _pago = 'https://buy.stripe.com/cNi6oA83U0aG3Zx2vJ87K00';

  /// Portal de cliente de Stripe, para darse de baja (se enlaza desde la web).
  static const portal = 'https://billing.stripe.com/p/login/cNi6oA83U0aG3Zx2vJ87K00';

  static const correo = 'hola@lat41lab.com';

  /// Pago para el local [osmId] (`node/123`). Stripe solo admite letras,
  /// números, guiones y guiones bajos en `client_reference_id`, así que va
  /// como `node_123`; el Worker lo vuelve a convertir.
  static Uri pagoPara(String osmId) => Uri.parse(
      '$_pago?client_reference_id=${Uri.encodeQueryComponent(osmId.replaceAll('/', '_'))}');

  /// Botón "Aparecer como destacado" de la ficha: en iPhone abre la página
  /// para locales de la web (sin enlazar el pago desde la app, por las
  /// normas de Apple); en Android, directamente el pago de Stripe con el
  /// local ya indicado.
  static Uri destacarPara(String osmId, String idioma, {required bool ios}) =>
      ios ? paginaLocales(idioma) : pagoPara(osmId);

  /// Página para los locales en la web, en el idioma de la app.
  static Uri paginaLocales(String idioma) =>
      Uri.https('lat41lab.com', '/locals.html', {'lang': idioma});
}
