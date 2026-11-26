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
  String get buildingsUnavailable =>
      'No s\'han pogut carregar els edificis d\'aquesta zona. Torna-ho a provar d\'aquí a una estona.';

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
      'Edificis, carrers i locals: © col·laboradors d’OpenStreetMap (ODbL), preparats per Lat41 Lab amb extractes de Geofabrik.';

  @override
  String get creditTiles =>
      'Mapa base: © MapTiler · © col·laboradors d’OpenStreetMap.';

  @override
  String get osmAttribution => '© col·laboradors d’OpenStreetMap';

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
  String get close => 'Tanca';

  @override
  String get headlineSunnyCold => 'Aquí fa un sol molt agradable';

  @override
  String get headlineChillyShade => 'Fa fresca i sense sol aquí';

  @override
  String get notNow => 'Ara no';

  @override
  String get introTitle => 'S\'hi està bé, a fora?';

  @override
  String get introBody1 =>
      'Toca un punt del mapa i mira què tal s\'hi està ara mateix: sol o ombra, vent i temperatura. El teu bar preferit, la teva plaça o un lloc qualsevol.';

  @override
  String get introBody2 =>
      'Activa la capa de locals (dades d\'OpenStreetMap) per veure també què tal s\'està a la terrassa de cada bar.';

  @override
  String get introButton => 'Entesos';

  @override
  String get showIntro => 'Mostra la introducció';

  @override
  String get localesLayer => 'Capa de locals';

  @override
  String get tapMapHint => 'Toca el mapa per veure què tal s\'hi està.';

  @override
  String get shareApp => 'Comparteix aquesta app';

  @override
  String get locationOff =>
      'La localització del mòbil està apagada. Et mostro el centre de Barcelona.';

  @override
  String get locationDenied =>
      'Sense permís d\'ubicació. Et mostro el centre de Barcelona.';

  @override
  String get locationNoSignal =>
      'No s\'ha pogut obtenir la teva ubicació. Et mostro el centre de Barcelona.';

  @override
  String get openSettings => 'Ajustos';

  @override
  String get retry => 'Torna-ho a provar';

  @override
  String get computingShade => 'Calculant l\'ombra…';

  @override
  String get computingShadeDetail =>
      'Encara estic baixant els edificis d\'aquesta zona. L\'ombra s\'actualitzarà d\'aquí a uns segons.';

  @override
  String get onlyConfirmedTerraces => 'Només terrasses confirmades';

  @override
  String get terraceUnconfirmedShort => 'terrassa sense confirmar';

  @override
  String get hoursUnavailable => 'Horari no disponible.';

  @override
  String get hoursTerraceCaveat =>
      'Obert a aquesta hora segons OpenStreetMap. La terrassa pot tancar abans que el local.';

  @override
  String get reportError => 'Avisar d\'un error';

  @override
  String get reportOsm => 'Corregir a OpenStreetMap';

  @override
  String get reportOsmDetail =>
      'Obre una nota a openstreetmap.org en aquest punt. Les notes són públiques: qualsevol les pot llegir.';

  @override
  String get reportEmail => 'Escriure a Lat41 Lab';

  @override
  String reportEmailSubject(String name) {
    return 'Error a Terrazeo: $name';
  }

  @override
  String reportEmailBody(String name, String url) {
    return 'Local: $name\n$url\n\nQuè hi ha malament?\n';
  }

  @override
  String get couldNotOpen => 'No s\'ha pogut obrir.';

  @override
  String get recommended => 'Recomanat';

  @override
  String get onlyRecommended => 'Només recomanats';

  @override
  String get noRecommendedHere =>
      'Encara no hi ha cap local recomanat en aquesta zona. Treu el filtre per veure totes les terrasses.';

  @override
  String get recommendedDisclosure =>
      'Local recomanat: paga per aparèixer destacat. Això no canvia el càlcul de sol, ombra ni vent.';

  @override
  String get ownerTitle => 'És el teu local?';

  @override
  String get ownerRecommend => 'Apareix com a Recomanat';

  @override
  String get ownerRecommendDetail =>
      '5 € al mes, IVA inclòs. Es paga a la web de Stripe i et pots donar de baixa quan vulguis.';

  @override
  String get ownerClaim => 'Reclama\'l gratis';

  @override
  String get ownerClaimDetail =>
      'Escriu-nos per confirmar que és teu i corregir-ne les dades.';

  @override
  String ownerClaimSubject(String name) {
    return 'Reclamo el meu local a Terrazeo: $name';
  }

  @override
  String ownerClaimBody(String name, String url) {
    return 'Local: $name\n$url\n\nNom i telèfon de contacte:\n';
  }

  @override
  String get haveVenue => 'Tens un local? Apareix a Terrazeo';

  @override
  String get availableCities => 'Ciutats disponibles';

  @override
  String get availableCitiesIntro =>
      'En aquestes ciutats tenim dades pròpies de carrers i edificis, i les ombres surten al moment. A la resta, l\'app funciona igual però pot trigar més.';

  @override
  String get outsideCoverage =>
      'Aquí encara no tenim dades pròpies: els edificis poden trigar a carregar-se o no sortir. Funciona millor a les ciutats disponibles.';

  @override
  String get seeCities => 'Veure ciutats';
}
