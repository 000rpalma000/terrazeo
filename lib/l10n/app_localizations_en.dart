// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Terrazeo v2';

  @override
  String get terracesNearby => 'Terraces nearby';

  @override
  String get noBars => 'No bars found nearby.';

  @override
  String get thisSpot => 'This spot';

  @override
  String get zoomInForTerraces => 'Zoom in on the map to see terraces.';

  @override
  String get back => 'Back';

  @override
  String get refresh => 'Refresh';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Automatic (system)';

  @override
  String get movedToOpenSpace =>
      'Calculated at the open space closest to the venue.';

  @override
  String get terraceNotConfirmed => 'Terrace not confirmed on the map.';

  @override
  String get networkError =>
      'Couldn\'t download data. Check your connection and try again.';

  @override
  String get noAemet => 'No AEMET data right now.';

  @override
  String get now => 'Now';

  @override
  String get comfortVeryNice => 'Very nice';

  @override
  String get comfortNice => 'Nice';

  @override
  String get comfortSoSo => 'So-so';

  @override
  String get comfortBad => 'Uncomfortable';

  @override
  String get headlineNice => 'It\'s nice here right now';

  @override
  String get headlineBreeze => 'Nice, with a bit of a breeze';

  @override
  String get headlineStrongSun => 'The sun really beats down here';

  @override
  String get headlineHotShade => 'It\'s hot even in the shade';

  @override
  String get headlineCoolBetterSun => 'Cool: better a terrace in the sun';

  @override
  String get headlineWindy => 'Too windy right now';

  @override
  String get headlineCold => 'Too chilly to sit outside';

  @override
  String get headlineNight => 'Night';

  @override
  String get flagStrongSun => 'strong sun';

  @override
  String get flagShade => 'in shade';

  @override
  String get flagWindy => 'windy';

  @override
  String get flagBreeze => 'breeze';

  @override
  String get flagSheltered => 'sheltered';

  @override
  String get flagCool => 'cool';

  @override
  String get flagHot => 'hot';

  @override
  String feelsLike(int deg) {
    return 'feels like $deg °C';
  }

  @override
  String get statusPleno => 'In the sun';

  @override
  String get statusSolConNubes => 'Sun with clouds';

  @override
  String get statusNublado => 'Cloudy';

  @override
  String get statusSombra => 'In shade';

  @override
  String get statusNoche => 'Night';

  @override
  String sunUntilSunset(int h, int m) {
    return 'sun $h h $m min';
  }

  @override
  String get windCalm => 'Calm';

  @override
  String get windLight => 'Light breeze';

  @override
  String get windBreezy => 'Some wind';

  @override
  String get windWindy => 'Windy';

  @override
  String get windVeryWindy => 'Very windy';

  @override
  String windSpeedFrom(int kmh, String cardinal) {
    return '$kmh km/h from $cardinal';
  }

  @override
  String windSpeed(int kmh) {
    return '$kmh km/h';
  }

  @override
  String gusts(int kmh) {
    return 'Gusts up to $kmh km/h';
  }

  @override
  String windShelteredByBuildings(int kmh) {
    return 'Sheltered by buildings · $kmh km/h in the open';
  }

  @override
  String temperature(int deg) {
    return '$deg °C';
  }

  @override
  String get sourceForecast => 'AEMET forecast';

  @override
  String get sourceObservation => 'AEMET observation';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get about => 'About';

  @override
  String get dataSources => 'Data sources';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get aboutIntro =>
      'Find terraces and see whether it\'s nice right now: sun or shade, wind and temperature.';

  @override
  String get creditMap =>
      'Map and buildings: © OpenStreetMap contributors (ODbL).';

  @override
  String get creditTiles => 'Map tiles: OpenStreetMap.';

  @override
  String get creditWeather => 'Weather data: derived from AEMET data.';

  @override
  String get creditSun => 'Sun position: algorithm by Jean Meeus.';

  @override
  String get adTitle => 'Ad (test)';

  @override
  String get adBody =>
      'A real ad would go here. This is just to test how often it shows up.';

  @override
  String get removeAdsButton => 'Remove ads · €1.99';

  @override
  String get close => 'Close';

  @override
  String get adsSectionTitle => 'Ads';

  @override
  String get adsAlreadyRemoved => 'You already removed ads. Thank you!';

  @override
  String get headlineSunnyCold => 'Lovely sun here';

  @override
  String get headlineChillyShade => 'Chilly and shaded here';

  @override
  String get removeAdsPromptTitle => 'No ads?';

  @override
  String get removeAdsPromptBody =>
      'Remove them for good with a one-time payment.';

  @override
  String get notNow => 'Not now';

  @override
  String get adsRemovedMockDone => 'Ads removed (mock).';

  @override
  String get introTitle => 'Is it nice out there?';

  @override
  String get introBody1 =>
      'Tap a point on the map and see how pleasant it is there right now: sun or shade, wind and temperature. Your favourite bar, your square, or anywhere.';

  @override
  String get introBody2 =>
      'Turn on the venues layer (data from OpenStreetMap) to also see how pleasant each bar\'s terrace is.';

  @override
  String get introButton => 'Got it';

  @override
  String get showIntro => 'Show the intro';

  @override
  String get localesLayer => 'Venues layer';

  @override
  String get tapMapHint => 'Tap the map to check how it feels at that spot.';

  @override
  String get shareApp => 'Share this app';
}
