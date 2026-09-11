// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Terrazeo';

  @override
  String get terracesNearby => 'Terrassen in der Nähe';

  @override
  String get noBars => 'Keine Bars in der Nähe gefunden.';

  @override
  String get thisSpot => 'Dieser Ort';

  @override
  String get zoomInForTerraces => 'Zoome in die Karte, um Terrassen zu sehen.';

  @override
  String get back => 'Zurück';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Automatisch (System)';

  @override
  String get movedToOpenSpace =>
      'Berechnet am nächstgelegenen offenen Platz zum Lokal.';

  @override
  String get terraceNotConfirmed => 'Terrasse auf der Karte nicht bestätigt.';

  @override
  String get networkError =>
      'Daten konnten nicht geladen werden. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get noAemet => 'Zurzeit keine AEMET-Daten.';

  @override
  String get now => 'Jetzt';

  @override
  String get comfortVeryNice => 'Sehr angenehm';

  @override
  String get comfortNice => 'Angenehm';

  @override
  String get comfortSoSo => 'Geht so';

  @override
  String get comfortBad => 'Ungemütlich';

  @override
  String get headlineNice => 'Hier ist es gerade angenehm';

  @override
  String get headlineBreeze => 'Angenehm, mit etwas Brise';

  @override
  String get headlineStrongSun => 'Hier brennt die Sonne';

  @override
  String get headlineHotShade => 'Heiß, sogar im Schatten';

  @override
  String get headlineCoolBetterSun => 'Kühl: besser eine Terrasse in der Sonne';

  @override
  String get headlineWindy => 'Gerade ist es zu windig';

  @override
  String get headlineCold => 'Zu frisch für die Terrasse';

  @override
  String get headlineNight => 'Nachts';

  @override
  String get flagStrongSun => 'pralle Sonne';

  @override
  String get flagShade => 'im Schatten';

  @override
  String get flagWindy => 'windig';

  @override
  String get flagBreeze => 'Brise';

  @override
  String get flagSheltered => 'geschützt';

  @override
  String get flagCool => 'frisch';

  @override
  String get flagHot => 'heiß';

  @override
  String feelsLike(int deg) {
    return 'gefühlt $deg °C';
  }

  @override
  String get statusPleno => 'In der Sonne';

  @override
  String get statusSolConNubes => 'Sonne mit Wolken';

  @override
  String get statusNublado => 'Bewölkt';

  @override
  String get statusSombra => 'Im Schatten';

  @override
  String get statusNoche => 'Nachts';

  @override
  String sunUntilSunset(int h, int m) {
    return 'Sonne $h Std. $m Min.';
  }

  @override
  String get windCalm => 'Windstill';

  @override
  String get windLight => 'Leichte Brise';

  @override
  String get windBreezy => 'Etwas Wind';

  @override
  String get windWindy => 'Wind';

  @override
  String get windVeryWindy => 'Viel Wind';

  @override
  String windSpeedFrom(int kmh, String cardinal) {
    return '$kmh km/h aus $cardinal';
  }

  @override
  String windSpeed(int kmh) {
    return '$kmh km/h';
  }

  @override
  String gusts(int kmh) {
    return 'Böen bis $kmh km/h';
  }

  @override
  String windShelteredByBuildings(int kmh) {
    return 'Von Gebäuden geschützt · $kmh km/h im Freien';
  }

  @override
  String temperature(int deg) {
    return '$deg °C';
  }

  @override
  String get sourceForecast => 'AEMET-Vorhersage';

  @override
  String get sourceObservation => 'AEMET-Messung';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get about => 'Über die App';

  @override
  String get dataSources => 'Datenquellen';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get aboutIntro =>
      'Finde Terrassen und sieh, ob es gerade angenehm ist: Sonne oder Schatten, Wind und Temperatur.';

  @override
  String get creditMap =>
      'Karte und Gebäude: © OpenStreetMap-Mitwirkende (ODbL).';

  @override
  String get creditTiles => 'Kartenkacheln: OpenStreetMap.';

  @override
  String get creditWeather =>
      'Wetterdaten: eigene Aufbereitung auf Basis von AEMET-Daten.';

  @override
  String get creditSun => 'Sonnenstand: Algorithmus von Jean Meeus.';

  @override
  String get adTitle => 'Werbung (Test)';

  @override
  String get adBody =>
      'Hier käme eine echte Anzeige. Das dient nur zum Testen, wie oft sie erscheint.';

  @override
  String get removeAdsButton => 'Werbung entfernen · 1,99 €';

  @override
  String get close => 'Schließen';

  @override
  String get adsSectionTitle => 'Werbung';

  @override
  String get adsAlreadyRemoved =>
      'Du hast die Werbung bereits entfernt. Danke!';

  @override
  String get headlineSunnyCold => 'Hier scheint die Sonne richtig angenehm';

  @override
  String get headlineChillyShade => 'Hier ist es frisch und schattig';

  @override
  String get removeAdsPromptTitle => 'Ohne Werbung?';

  @override
  String get removeAdsPromptBody =>
      'Entferne sie dauerhaft mit einer einmaligen Zahlung.';

  @override
  String get notNow => 'Jetzt nicht';

  @override
  String get adsRemovedMockDone => 'Werbung entfernt (simuliert).';

  @override
  String get introTitle => 'Ist es draußen schön?';

  @override
  String get introBody1 =>
      'Tippe auf einen Punkt der Karte und sieh, wie angenehm es dort gerade ist: Sonne oder Schatten, Wind und Temperatur. Deine Lieblingsbar, dein Platz oder irgendwo.';

  @override
  String get introBody2 =>
      'Aktiviere die Lokal-Ebene (Daten von OpenStreetMap), um auch zu sehen, wie angenehm die Terrasse jeder Bar ist.';

  @override
  String get introButton => 'Verstanden';

  @override
  String get showIntro => 'Einführung anzeigen';

  @override
  String get localesLayer => 'Lokal-Ebene';

  @override
  String get tapMapHint =>
      'Tippe auf die Karte, um zu sehen, wie es an dieser Stelle ist.';

  @override
  String get shareApp => 'App teilen';
}
