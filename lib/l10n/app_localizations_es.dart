// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Terrazeo';

  @override
  String get terracesNearby => 'Terrazas cerca';

  @override
  String get noBars => 'No se han encontrado bares cerca.';

  @override
  String get thisSpot => 'Este punto';

  @override
  String get zoomInForTerraces => 'Acércate en el mapa para ver terrazas.';

  @override
  String get back => 'Volver';

  @override
  String get refresh => 'Actualizar';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Automático (sistema)';

  @override
  String get movedToOpenSpace =>
      'Calculado en el espacio abierto más cercano al local.';

  @override
  String get terraceNotConfirmed => 'Terraza no confirmada en el mapa.';

  @override
  String get networkError =>
      'No se han podido descargar los datos. Revisa la conexión e inténtalo de nuevo.';

  @override
  String get noAemet => 'Sin datos de AEMET ahora mismo.';

  @override
  String get now => 'Ahora';

  @override
  String get comfortVeryNice => 'Muy agradable';

  @override
  String get comfortNice => 'Agradable';

  @override
  String get comfortSoSo => 'Regular';

  @override
  String get comfortBad => 'Incómodo';

  @override
  String get headlineNice => 'Se está bien aquí ahora';

  @override
  String get headlineBreeze => 'Se está bien, con algo de brisa';

  @override
  String get headlineStrongSun => 'Aquí pega mucho el sol';

  @override
  String get headlineHotShade => 'Hace calor incluso a la sombra';

  @override
  String get headlineCoolBetterSun => 'Fresco: mejor una terraza al sol';

  @override
  String get headlineWindy => 'Ahora mismo hace demasiado viento';

  @override
  String get headlineCold => 'Hace fresco para estar en la terraza';

  @override
  String get headlineNight => 'De noche';

  @override
  String get flagStrongSun => 'sol fuerte';

  @override
  String get flagShade => 'a la sombra';

  @override
  String get flagWindy => 'ventoso';

  @override
  String get flagBreeze => 'brisa';

  @override
  String get flagSheltered => 'resguardado';

  @override
  String get flagCool => 'fresco';

  @override
  String get flagHot => 'calor';

  @override
  String feelsLike(int deg) {
    return 'sensación $deg °C';
  }

  @override
  String get statusPleno => 'Al sol';

  @override
  String get statusSolConNubes => 'Sol con nubes';

  @override
  String get statusNublado => 'Nublado';

  @override
  String get statusSombra => 'En sombra';

  @override
  String get statusNoche => 'De noche';

  @override
  String sunUntilSunset(int h, int m) {
    return 'sol $h h $m min';
  }

  @override
  String get windCalm => 'En calma';

  @override
  String get windLight => 'Brisa ligera';

  @override
  String get windBreezy => 'Algo de viento';

  @override
  String get windWindy => 'Viento';

  @override
  String get windVeryWindy => 'Mucho viento';

  @override
  String windSpeedFrom(int kmh, String cardinal) {
    return '$kmh km/h del $cardinal';
  }

  @override
  String windSpeed(int kmh) {
    return '$kmh km/h';
  }

  @override
  String gusts(int kmh) {
    return 'Rachas de hasta $kmh km/h';
  }

  @override
  String windShelteredByBuildings(int kmh) {
    return 'Resguardado por edificios · $kmh km/h en campo abierto';
  }

  @override
  String temperature(int deg) {
    return '$deg °C';
  }

  @override
  String get sourceForecast => 'Predicción AEMET';

  @override
  String get sourceObservation => 'Observación AEMET';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get about => 'Acerca de';

  @override
  String get dataSources => 'Fuentes de datos';

  @override
  String get openSourceLicenses => 'Licencias de código abierto';

  @override
  String get aboutIntro =>
      'Busca terrazas y mira si ahora mismo se está a gusto: sol o sombra, viento y temperatura.';

  @override
  String get creditMap =>
      'Mapa y edificios: © colaboradores de OpenStreetMap (ODbL).';

  @override
  String get creditTiles => 'Teselas del mapa: OpenStreetMap.';

  @override
  String get creditWeather =>
      'Datos meteorológicos: elaboración propia a partir de datos de AEMET.';

  @override
  String get creditSun => 'Posición del sol: algoritmo de Jean Meeus.';

  @override
  String get adTitle => 'Publicidad (prueba)';

  @override
  String get adBody =>
      'Aquí iría un anuncio real. Esto es solo para probar cada cuánto aparece.';

  @override
  String get removeAdsButton => 'Quitar anuncios · 1,99 €';

  @override
  String get close => 'Cerrar';

  @override
  String get adsSectionTitle => 'Anuncios';

  @override
  String get adsAlreadyRemoved => 'Ya has quitado los anuncios. ¡Gracias!';

  @override
  String get headlineSunnyCold => 'Aquí da un sol muy agradable';

  @override
  String get headlineChillyShade => 'Hace fresco y sin sol aquí';

  @override
  String get removeAdsPromptTitle => '¿Sin anuncios?';

  @override
  String get removeAdsPromptBody => 'Quítalos para siempre con un único pago.';

  @override
  String get notNow => 'Ahora no';

  @override
  String get adsRemovedMockDone => 'Anuncios quitados (simulado).';

  @override
  String get introTitle => '¿Se está bien ahí fuera?';

  @override
  String get introBody1 =>
      'Toca un punto del mapa y mira qué tal se está ahí ahora mismo: sol o sombra, viento y temperatura. Tu bar preferido, tu plaza o un sitio cualquiera.';

  @override
  String get introButton => 'Entendido';

  @override
  String get showIntro => 'Ver la introducción';
}
