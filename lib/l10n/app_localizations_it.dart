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
      'Mappa ed edifici: © contributori di OpenStreetMap (ODbL).';

  @override
  String get creditTiles => 'Riquadri della mappa: OpenStreetMap.';

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
  String get removeAdsButton => 'Rimuovi pubblicità · 1,99 €';

  @override
  String get close => 'Chiudi';

  @override
  String get adsSectionTitle => 'Pubblicità';

  @override
  String get adsAlreadyRemoved => 'Hai già rimosso la pubblicità. Grazie!';

  @override
  String get headlineSunnyCold => 'Un sole molto piacevole qui';

  @override
  String get headlineChillyShade => 'Fresco e all’ombra qui';

  @override
  String get removeAdsPromptTitle => 'Senza pubblicità?';

  @override
  String get removeAdsPromptBody =>
      'Rimuovila per sempre con un pagamento unico.';

  @override
  String get notNow => 'Non ora';

  @override
  String get adsRemovedMockDone => 'Pubblicità rimossa (simulato).';

  @override
  String get introTitle => 'Si sta bene là fuori?';

  @override
  String get introBody1 =>
      'Tocca un punto sulla mappa e scopri quanto si sta bene lì in questo momento: sole o ombra, vento e temperatura. Il tuo bar preferito, la tua piazza o un posto qualsiasi.';

  @override
  String get introButton => 'Ho capito';

  @override
  String get showIntro => 'Rivedi l\'introduzione';

  @override
  String get shareApp => 'Condividi questa app';
}
