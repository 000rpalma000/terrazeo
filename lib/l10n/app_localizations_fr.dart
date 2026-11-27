// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Terrazeo';

  @override
  String get terracesNearby => 'Terrasses à proximité';

  @override
  String get noBars => 'Aucun bar trouvé à proximité.';

  @override
  String get thisSpot => 'Ce point';

  @override
  String get zoomInForTerraces =>
      'Zoomez sur la carte pour voir les terrasses.';

  @override
  String get back => 'Retour';

  @override
  String get refresh => 'Actualiser';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Automatique (système)';

  @override
  String get movedToOpenSpace =>
      'Calculé sur l\'espace ouvert le plus proche du lieu.';

  @override
  String get terraceNotConfirmed => 'Terrasse non confirmée sur la carte.';

  @override
  String get networkError =>
      'Impossible de télécharger les données. Vérifiez votre connexion et réessayez.';

  @override
  String get buildingsUnavailable =>
      'Impossible de charger les bâtiments de cette zone. Réessayez dans un moment.';

  @override
  String get noAemet => 'Pas de données AEMET pour le moment.';

  @override
  String get now => 'Maintenant';

  @override
  String get comfortVeryNice => 'Très agréable';

  @override
  String get comfortNice => 'Agréable';

  @override
  String get comfortSoSo => 'Moyen';

  @override
  String get comfortBad => 'Inconfortable';

  @override
  String get headlineNice => 'On est bien ici en ce moment';

  @override
  String get headlineBreeze => 'Agréable, avec un peu de brise';

  @override
  String get headlineStrongSun => 'Le soleil tape fort ici';

  @override
  String get headlineHotShade => 'Il fait chaud même à l\'ombre';

  @override
  String get headlineCoolBetterSun =>
      'Frais : mieux vaut une terrasse au soleil';

  @override
  String get headlineWindy => 'Trop de vent en ce moment';

  @override
  String get headlineCold => 'Trop frais pour s\'asseoir dehors';

  @override
  String get headlineNight => 'Nuit';

  @override
  String get flagStrongSun => 'plein soleil';

  @override
  String get flagShade => 'à l\'ombre';

  @override
  String get flagWindy => 'venteux';

  @override
  String get flagBreeze => 'brise';

  @override
  String get flagSheltered => 'abrité';

  @override
  String get flagCool => 'frais';

  @override
  String get flagHot => 'chaud';

  @override
  String feelsLike(int deg) {
    return 'ressenti $deg °C';
  }

  @override
  String get statusPleno => 'Au soleil';

  @override
  String get statusSolConNubes => 'Soleil avec nuages';

  @override
  String get statusNublado => 'Nuageux';

  @override
  String get statusSombra => 'À l\'ombre';

  @override
  String get statusNoche => 'Nuit';

  @override
  String sunUntilSunset(int h, int m) {
    return 'soleil $h h $m min';
  }

  @override
  String get windCalm => 'Calme';

  @override
  String get windLight => 'Brise légère';

  @override
  String get windBreezy => 'Un peu de vent';

  @override
  String get windWindy => 'Vent';

  @override
  String get windVeryWindy => 'Beaucoup de vent';

  @override
  String windSpeedFrom(int kmh, String cardinal) {
    return '$kmh km/h de $cardinal';
  }

  @override
  String windSpeed(int kmh) {
    return '$kmh km/h';
  }

  @override
  String gusts(int kmh) {
    return 'Rafales jusqu\'à $kmh km/h';
  }

  @override
  String windShelteredByBuildings(int kmh) {
    return 'Abrité par les bâtiments · $kmh km/h en terrain dégagé';
  }

  @override
  String temperature(int deg) {
    return '$deg °C';
  }

  @override
  String get sourceForecast => 'Prévision AEMET';

  @override
  String get sourceObservation => 'Observation AEMET';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get about => 'À propos';

  @override
  String get dataSources => 'Sources de données';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get aboutIntro =>
      'Trouvez des terrasses et voyez si l\'on y est bien maintenant : soleil ou ombre, vent et température.';

  @override
  String get creditMap =>
      'Bâtiments, rues et établissements : © contributeurs d’OpenStreetMap (ODbL), préparés par Lat41 Lab à partir d’extraits Geofabrik.';

  @override
  String get creditTiles =>
      'Fond de carte : © MapTiler · © contributeurs d’OpenStreetMap.';

  @override
  String get osmAttribution => '© contributeurs d’OpenStreetMap';

  @override
  String get creditWeather =>
      'Données météo : élaborées à partir des données de l\'AEMET.';

  @override
  String get creditSun => 'Position du soleil : algorithme de Jean Meeus.';

  @override
  String get adTitle => 'Publicité (test)';

  @override
  String get adBody =>
      'Une vraie publicité s\'afficherait ici. Ceci sert juste à tester la fréquence.';

  @override
  String get close => 'Fermer';

  @override
  String get headlineSunnyCold => 'Un soleil très agréable ici';

  @override
  String get headlineChillyShade => 'Frais et à l’ombre ici';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get introTitle => 'Fait-il bon dehors ?';

  @override
  String get introBody1 =>
      'Touchez un point sur la carte et voyez s\'il y fait bon en ce moment : soleil ou ombre, vent et température. Votre bar préféré, votre place, ou n\'importe où.';

  @override
  String get introBody2 =>
      'Activez la couche des établissements (données d\'OpenStreetMap) pour voir aussi le confort de la terrasse de chaque bar.';

  @override
  String get introButton => 'Compris';

  @override
  String get showIntro => 'Revoir l\'intro';

  @override
  String get localesLayer => 'Couche des établissements';

  @override
  String get tapMapHint =>
      'Touchez la carte pour voir le confort à cet endroit.';

  @override
  String get shareApp => 'Partager cette appli';

  @override
  String get locationOff =>
      'La localisation est désactivée. Affichage du centre de Barcelone.';

  @override
  String get locationDenied =>
      'Pas d\'autorisation de localisation. Affichage du centre de Barcelone.';

  @override
  String get locationNoSignal =>
      'Impossible d\'obtenir votre position. Affichage du centre de Barcelone.';

  @override
  String get openSettings => 'Réglages';

  @override
  String get retry => 'Réessayer';

  @override
  String get computingShade => 'Calcul de l\'ombre…';

  @override
  String get computingShadeDetail =>
      'Téléchargement des bâtiments du quartier en cours. L\'ombre se mettra à jour dans quelques secondes.';

  @override
  String get onlyConfirmedTerraces => 'Terrasses confirmées uniquement';

  @override
  String get terraceUnconfirmedShort => 'terrasse non confirmée';

  @override
  String get hoursUnavailable => 'Horaires non disponibles.';

  @override
  String get hoursTerraceCaveat =>
      'Ouvert à cette heure selon OpenStreetMap. La terrasse peut fermer avant l\'établissement.';

  @override
  String get reportError => 'Signaler une erreur';

  @override
  String get reportOsm => 'Corriger sur OpenStreetMap';

  @override
  String get reportOsmDetail =>
      'Ouvre une note sur openstreetmap.org à cet endroit. Les notes sont publiques : tout le monde peut les lire.';

  @override
  String get reportEmail => 'Écrire à Lat41 Lab';

  @override
  String reportEmailSubject(String name) {
    return 'Erreur dans Terrazeo : $name';
  }

  @override
  String reportEmailBody(String name, String url) {
    return 'Établissement : $name\n$url\n\nQu\'est-ce qui ne va pas ?\n';
  }

  @override
  String get couldNotOpen => 'Impossible de l\'ouvrir.';

  @override
  String get recommended => 'Mis en avant';

  @override
  String get onlyRecommended => 'Mis en avant uniquement';

  @override
  String get noRecommendedHere =>
      'Il n\'y a pas encore d\'établissement mis en avant dans cette zone. Désactivez le filtre pour voir toutes les terrasses.';

  @override
  String get recommendedDisclosure =>
      'Sponsorisé · paie pour être mis en avant. Cela ne change pas le calcul du soleil, de l\'ombre ou du vent.';

  @override
  String get ownerTitle => 'C\'est votre établissement ?';

  @override
  String get ownerRecommend => 'Être mis en avant';

  @override
  String get ownerClaim => 'Le revendiquer gratuitement';

  @override
  String get ownerClaimDetail =>
      'Écrivez-nous pour confirmer qu\'il est à vous et corriger ses informations.';

  @override
  String ownerClaimSubject(String name) {
    return 'Je revendique mon établissement sur Terrazeo : $name';
  }

  @override
  String ownerClaimBody(String name, String url) {
    return 'Établissement : $name\n$url\n\nNom et téléphone de contact :\n';
  }

  @override
  String get haveVenue =>
      'Vous avez un établissement ? Apparaissez sur Terrazeo';

  @override
  String get availableCities => 'Villes disponibles';

  @override
  String get availableCitiesIntro =>
      'Dans ces villes, nous avons nos propres données de rues et de bâtiments : les ombres s\'affichent tout de suite. Ailleurs, l\'app fonctionne aussi mais peut être plus lente.';

  @override
  String get outsideCoverage =>
      'Nous n\'avons pas encore nos propres données ici : les bâtiments peuvent tarder à s\'afficher ou manquer. L\'app fonctionne mieux dans les villes disponibles.';

  @override
  String get seeCities => 'Voir les villes';

  @override
  String get statusSolParcial => 'Soleil partiel';
}
