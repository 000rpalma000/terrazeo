// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Terrazeo';

  @override
  String get terracesNearby => 'Terrazze vicine';

  @override
  String get noBars => 'Nessun bar trovato nelle vicinanze.';

  @override
  String get thisSpot => 'Questo punto';

  @override
  String get zoomInForTerraces =>
      'Ingrandisci la mappa per vedere le terrazze.';

  @override
  String get back => 'Indietro';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get language => 'Lingua';

  @override
  String get languageSystem => 'Automatico (sistema)';

  @override
  String get movedToOpenSpace =>
      'Calcolato nello spazio aperto più vicino al locale.';

  @override
  String get terraceNotConfirmed => 'Terrazza non confermata sulla mappa.';

  @override
  String get networkError =>
      'Impossibile scaricare i dati. Controlla la connessione e riprova.';

  @override
  String get buildingsUnavailable =>
      'Non è stato possibile caricare gli edifici di questa zona. Riprova tra un po\'.';

  @override
  String get noAemet => 'Nessun dato AEMET al momento.';

  @override
  String get now => 'Adesso';

  @override
  String get comfortVeryNice => 'Molto piacevole';

  @override
  String get comfortNice => 'Piacevole';

  @override
  String get comfortSoSo => 'Così così';

  @override
  String get comfortBad => 'Scomodo';

  @override
  String get headlineNice => 'Qui adesso si sta bene';

  @override
  String get headlineBreeze => 'Si sta bene, con un po\' di brezza';

  @override
  String get headlineStrongSun => 'Qui il sole picchia forte';

  @override
  String get headlineHotShade => 'Fa caldo anche all\'ombra';

  @override
  String get headlineCoolBetterSun => 'Fresco: meglio una terrazza al sole';

  @override
  String get headlineWindy => 'Troppo vento in questo momento';

  @override
  String get headlineCold => 'Troppo fresco per stare fuori';

  @override
  String get headlineNight => 'Notte';

  @override
  String get flagStrongSun => 'sole forte';

  @override
  String get flagShade => 'all\'ombra';

  @override
  String get flagWindy => 'ventoso';

  @override
  String get flagBreeze => 'brezza';

  @override
  String get flagSheltered => 'riparato';

  @override
  String get flagCool => 'fresco';

  @override
  String get flagHot => 'caldo';

  @override
  String feelsLike(int deg) {
    return 'percepiti $deg °C';
  }

  @override
  String get statusPleno => 'Al sole';

  @override
  String get statusSolConNubes => 'Sole con nuvole';

  @override
  String get statusNublado => 'Nuvoloso';

  @override
  String get statusSombra => 'All\'ombra';

  @override
  String get statusNoche => 'Notte';

  @override
  String sunUntilSunset(int h, int m) {
    return 'sole $h h $m min';
  }

  @override
  String get windCalm => 'Calmo';

  @override
  String get windLight => 'Brezza leggera';

  @override
  String get windBreezy => 'Un po\' di vento';

  @override
  String get windWindy => 'Vento';

  @override
  String get windVeryWindy => 'Molto vento';

  @override
  String windSpeedFrom(int kmh, String cardinal) {
    return '$kmh km/h da $cardinal';
  }

  @override
  String windSpeed(int kmh) {
    return '$kmh km/h';
  }

  @override
  String gusts(int kmh) {
    return 'Raffiche fino a $kmh km/h';
  }

  @override
  String windShelteredByBuildings(int kmh) {
    return 'Riparato dagli edifici · $kmh km/h in campo aperto';
  }

  @override
  String temperature(int deg) {
    return '$deg °C';
  }

  @override
  String get sourceForecast => 'Previsione AEMET';

  @override
  String get sourceObservation => 'Osservazione AEMET';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get about => 'Informazioni';

  @override
  String get dataSources => 'Fonti dei dati';

  @override
  String get openSourceLicenses => 'Licenze open source';

  @override
  String get aboutIntro =>
      'Trova terrazze e scopri se adesso si sta bene: sole o ombra, vento e temperatura.';

  @override
  String get creditMap =>
      'Edifici, strade e locali: © contributori di OpenStreetMap (ODbL), preparati da Lat41 Lab da estratti Geofabrik.';

  @override
  String get creditTiles =>
      'Mappa di base: © MapTiler · © contributori di OpenStreetMap.';

  @override
  String get osmAttribution => '© contributori di OpenStreetMap';

  @override
  String get creditWeather => 'Dati meteo: elaborati a partire dai dati AEMET.';

  @override
  String get creditSun => 'Posizione del sole: algoritmo di Jean Meeus.';

  @override
  String get adTitle => 'Pubblicità (test)';

  @override
  String get adBody =>
      'Qui apparirebbe una pubblicità reale. Serve solo per provare la frequenza.';

  @override
  String get close => 'Chiudi';

  @override
  String get headlineSunnyCold => 'Un sole molto piacevole qui';

  @override
  String get headlineChillyShade => 'Fresco e all’ombra qui';

  @override
  String get notNow => 'Non ora';

  @override
  String get introTitle => 'Si sta bene là fuori?';

  @override
  String get introBody1 =>
      'Tocca un punto sulla mappa e scopri quanto si sta bene lì in questo momento: sole o ombra, vento e temperatura. Il tuo bar preferito, la tua piazza o un posto qualsiasi.';

  @override
  String get introBody2 =>
      'Attiva il livello dei locali (dati di OpenStreetMap) per vedere anche quanto si sta bene nel dehors di ogni bar.';

  @override
  String get introButton => 'Ho capito';

  @override
  String get showIntro => 'Rivedi l\'introduzione';

  @override
  String get localesLayer => 'Livello dei locali';

  @override
  String get tapMapHint =>
      'Tocca la mappa per vedere come si sta in quel punto.';

  @override
  String get shareApp => 'Condividi questa app';

  @override
  String get locationOff =>
      'La localizzazione è disattivata. Mostro il centro di Barcellona.';

  @override
  String get locationDenied =>
      'Nessun permesso di posizione. Mostro il centro di Barcellona.';

  @override
  String get locationNoSignal =>
      'Impossibile ottenere la tua posizione. Mostro il centro di Barcellona.';

  @override
  String get openSettings => 'Impostazioni';

  @override
  String get retry => 'Riprova';

  @override
  String get computingShade => 'Calcolo l\'ombra…';

  @override
  String get computingShadeDetail =>
      'Sto ancora scaricando gli edifici della zona. L\'ombra si aggiornerà tra pochi secondi.';

  @override
  String get onlyConfirmedTerraces => 'Solo terrazze confermate';

  @override
  String get terraceUnconfirmedShort => 'terrazza non confermata';

  @override
  String get hoursUnavailable => 'Orari non disponibili.';

  @override
  String get hoursTerraceCaveat =>
      'Aperto a quest\'ora secondo OpenStreetMap. La terrazza può chiudere prima del locale.';

  @override
  String get reportError => 'Segnala un errore';

  @override
  String get reportOsm => 'Correggi su OpenStreetMap';

  @override
  String get reportOsmDetail =>
      'Apre una nota su openstreetmap.org in questo punto. Le note sono pubbliche: chiunque può leggerle.';

  @override
  String get reportEmail => 'Scrivi a Lat41 Lab';

  @override
  String reportEmailSubject(String name) {
    return 'Errore in Terrazeo: $name';
  }

  @override
  String reportEmailBody(String name, String url) {
    return 'Locale: $name\n$url\n\nCosa c\'è che non va?\n';
  }

  @override
  String get couldNotOpen => 'Impossibile aprirlo.';

  @override
  String get recommended => 'Consigliato';

  @override
  String get onlyRecommended => 'Solo consigliati';

  @override
  String get noRecommendedHere =>
      'Non ci sono ancora locali consigliati in questa zona. Disattiva il filtro per vedere tutte le terrazze.';

  @override
  String get recommendedDisclosure =>
      'Locale consigliato: paga per essere in evidenza. Questo non cambia il calcolo di sole, ombra e vento.';

  @override
  String get ownerTitle => 'È il tuo locale?';

  @override
  String get ownerRecommend => 'Appari come Consigliato';

  @override
  String get ownerRecommendDetail =>
      '5 € al mese, IVA inclusa. Si paga sul sito di Stripe e puoi disdire quando vuoi.';

  @override
  String get ownerClaim => 'Rivendicalo gratis';

  @override
  String get ownerClaimDetail =>
      'Scrivici per confermare che è tuo e correggerne i dati.';

  @override
  String ownerClaimSubject(String name) {
    return 'Rivendico il mio locale su Terrazeo: $name';
  }

  @override
  String ownerClaimBody(String name, String url) {
    return 'Locale: $name\n$url\n\nNome e telefono di contatto:\n';
  }

  @override
  String get haveVenue => 'Hai un locale? Appari su Terrazeo';

  @override
  String get availableCities => 'Città disponibili';

  @override
  String get availableCitiesIntro =>
      'In queste città abbiamo dati propri su strade ed edifici e le ombre compaiono subito. Altrove l\'app funziona lo stesso ma può essere più lenta.';

  @override
  String get outsideCoverage =>
      'Qui non abbiamo ancora dati propri: gli edifici possono tardare a caricarsi o non comparire. Funziona meglio nelle città disponibili.';

  @override
  String get seeCities => 'Vedi città';
}
