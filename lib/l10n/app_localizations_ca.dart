// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appTitle => 'Terrazeo';

  @override
  String get terracesNearby => 'Terrasses a prop';

  @override
  String get noBars => 'No s\'han trobat bars a prop.';

  @override
  String get thisSpot => 'Aquest punt';

  @override
  String get zoomInForTerraces => 'Apropa\'t al mapa per veure terrasses.';

  @override
  String get back => 'Enrere';

  @override
  String get refresh => 'Actualitza';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Automàtic (sistema)';

  @override
  String get movedToOpenSpace =>
      'Calculat a l\'espai obert més proper al local.';

  @override
  String get terraceNotConfirmed => 'Terrassa no confirmada al mapa.';

  @override
  String get networkError =>
      'No s\'han pogut baixar les dades. Comprova la connexió i torna-ho a provar.';

  @override
  String get noAemet => 'Sense dades de l\'AEMET ara mateix.';

  @override
  String get now => 'Ara';

  @override
  String get comfortVeryNice => 'Molt agradable';

  @override
  String get comfortNice => 'Agradable';

  @override
  String get comfortSoSo => 'Regular';

  @override
  String get comfortBad => 'Incòmode';

  @override
  String get headlineNice => 'Aquí ara s\'hi està bé';

  @override
  String get headlineBreeze => 'S\'hi està bé, amb una mica de brisa';

  @override
  String get headlineStrongSun => 'Aquí el sol pica molt';

  @override
  String get headlineHotShade => 'Fa calor fins i tot a l\'ombra';

  @override
  String get headlineCoolBetterSun => 'Fresc: millor una terrassa al sol';

  @override
  String get headlineWindy => 'Ara mateix fa massa vent';

  @override
  String get headlineCold => 'Fa fresca per seure a la terrassa';

  @override
  String get headlineNight => 'De nit';

  @override
  String get flagStrongSun => 'sol fort';

  @override
  String get flagShade => 'a l\'ombra';

  @override
  String get flagWindy => 'ventós';

  @override
  String get flagBreeze => 'brisa';

  @override
  String get flagSheltered => 'arrecerat';

  @override
  String get flagCool => 'fresc';

  @override
  String get flagHot => 'calor';

  @override
  String feelsLike(int deg) {
    return 'sensació $deg °C';
  }

  @override
  String get statusPleno => 'Al sol';

  @override
  String get statusSolConNubes => 'Sol amb núvols';

  @override
  String get statusNublado => 'Ennuvolat';

  @override
  String get statusSombra => 'A l\'ombra';

  @override
  String get statusNoche => 'De nit';

  @override
  String sunUntilSunset(int h, int m) {
    return 'sol $h h $m min';
  }

  @override
  String get windCalm => 'En calma';

  @override
  String get windLight => 'Brisa lleugera';

  @override
  String get windBreezy => 'Una mica de vent';

  @override
  String get windWindy => 'Vent';

  @override
  String get windVeryWindy => 'Molt de vent';

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
    return 'Ratxes de fins a $kmh km/h';
  }

  @override
  String windShelteredByBuildings(int kmh) {
    return 'Arrecerat pels edificis · $kmh km/h en camp obert';
  }

  @override
  String temperature(int deg) {
    return '$deg °C';
  }

  @override
  String get sourceForecast => 'Predicció AEMET';

  @override
  String get sourceObservation => 'Observació AEMET';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get about => 'Sobre l\'app';

  @override
  String get dataSources => 'Fonts de dades';

  @override
  String get openSourceLicenses => 'Llicències de codi obert';

  @override
  String get aboutIntro =>
      'Busca terrasses i mira si ara mateix s\'hi està bé: sol o ombra, vent i temperatura.';

  @override
  String get creditMap =>
      'Mapa i edificis: © col·laboradors d’OpenStreetMap (ODbL).';

  @override
  String get creditTiles => 'Tessel·les del mapa: OpenStreetMap.';

  @override
  String get creditWeather =>
      'Dades meteorològiques: elaboració pròpia a partir de dades de l\'AEMET.';

  @override
  String get creditSun => 'Posició del sol: algorisme de Jean Meeus.';

  @override
  String get adTitle => 'Publicitat (prova)';

  @override
  String get adBody =>
      'Aquí aniria un anunci real. Això és només per provar cada quant apareix.';

  @override
  String get removeAdsButton => 'Treu anuncis · 1,99 €';

  @override
  String get close => 'Tanca';

  @override
  String get adsSectionTitle => 'Anuncis';

  @override
  String get adsAlreadyRemoved => 'Ja has tret els anuncis. Gràcies!';

  @override
  String get headlineSunnyCold => 'Aquí fa un sol molt agradable';

  @override
  String get headlineChillyShade => 'Fa fresca i sense sol aquí';

  @override
  String get removeAdsPromptTitle => 'Sense anuncis?';

  @override
  String get removeAdsPromptBody => 'Treu-los per sempre amb un únic pagament.';

  @override
  String get notNow => 'Ara no';

  @override
  String get adsRemovedMockDone => 'Anuncis trets (simulat).';

  @override
  String get introTitle => 'S\'hi està bé, a fora?';

  @override
  String get introBody1 =>
      'Toca un punt del mapa i mira què tal s\'hi està ara mateix: sol o ombra, vent i temperatura. El teu bar preferit, la teva plaça o un lloc qualsevol.';

  @override
  String get introButton => 'Entesos';

  @override
  String get showIntro => 'Mostra la introducció';

  @override
  String get shareApp => 'Comparteix aquesta app';
}
