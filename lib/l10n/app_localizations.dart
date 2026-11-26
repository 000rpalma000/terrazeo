import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Terrazeo'**
  String get appTitle;

  /// No description provided for @terracesNearby.
  ///
  /// In es, this message translates to:
  /// **'Terrazas cerca'**
  String get terracesNearby;

  /// No description provided for @noBars.
  ///
  /// In es, this message translates to:
  /// **'No se han encontrado bares cerca.'**
  String get noBars;

  /// No description provided for @thisSpot.
  ///
  /// In es, this message translates to:
  /// **'Este punto'**
  String get thisSpot;

  /// No description provided for @zoomInForTerraces.
  ///
  /// In es, this message translates to:
  /// **'Acércate en el mapa para ver terrazas.'**
  String get zoomInForTerraces;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @refresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refresh;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Automático (sistema)'**
  String get languageSystem;

  /// No description provided for @movedToOpenSpace.
  ///
  /// In es, this message translates to:
  /// **'Calculado en el espacio abierto más cercano al local.'**
  String get movedToOpenSpace;

  /// No description provided for @terraceNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Terraza no confirmada en el mapa.'**
  String get terraceNotConfirmed;

  /// No description provided for @networkError.
  ///
  /// In es, this message translates to:
  /// **'No se han podido descargar los datos. Revisa la conexión e inténtalo de nuevo.'**
  String get networkError;

  /// No description provided for @buildingsUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se han podido cargar los edificios de esta zona. Vuelve a intentarlo en un rato.'**
  String get buildingsUnavailable;

  /// No description provided for @noAemet.
  ///
  /// In es, this message translates to:
  /// **'Sin datos de AEMET ahora mismo.'**
  String get noAemet;

  /// No description provided for @now.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get now;

  /// No description provided for @comfortVeryNice.
  ///
  /// In es, this message translates to:
  /// **'Muy agradable'**
  String get comfortVeryNice;

  /// No description provided for @comfortNice.
  ///
  /// In es, this message translates to:
  /// **'Agradable'**
  String get comfortNice;

  /// No description provided for @comfortSoSo.
  ///
  /// In es, this message translates to:
  /// **'Regular'**
  String get comfortSoSo;

  /// No description provided for @comfortBad.
  ///
  /// In es, this message translates to:
  /// **'Incómodo'**
  String get comfortBad;

  /// No description provided for @headlineNice.
  ///
  /// In es, this message translates to:
  /// **'Se está bien aquí ahora'**
  String get headlineNice;

  /// No description provided for @headlineBreeze.
  ///
  /// In es, this message translates to:
  /// **'Se está bien, con algo de brisa'**
  String get headlineBreeze;

  /// No description provided for @headlineStrongSun.
  ///
  /// In es, this message translates to:
  /// **'Aquí pega mucho el sol'**
  String get headlineStrongSun;

  /// No description provided for @headlineHotShade.
  ///
  /// In es, this message translates to:
  /// **'Hace calor incluso a la sombra'**
  String get headlineHotShade;

  /// No description provided for @headlineCoolBetterSun.
  ///
  /// In es, this message translates to:
  /// **'Fresco: mejor una terraza al sol'**
  String get headlineCoolBetterSun;

  /// No description provided for @headlineWindy.
  ///
  /// In es, this message translates to:
  /// **'Ahora mismo hace demasiado viento'**
  String get headlineWindy;

  /// No description provided for @headlineCold.
  ///
  /// In es, this message translates to:
  /// **'Hace fresco para estar en la terraza'**
  String get headlineCold;

  /// No description provided for @headlineNight.
  ///
  /// In es, this message translates to:
  /// **'De noche'**
  String get headlineNight;

  /// No description provided for @flagStrongSun.
  ///
  /// In es, this message translates to:
  /// **'sol fuerte'**
  String get flagStrongSun;

  /// No description provided for @flagShade.
  ///
  /// In es, this message translates to:
  /// **'a la sombra'**
  String get flagShade;

  /// No description provided for @flagWindy.
  ///
  /// In es, this message translates to:
  /// **'ventoso'**
  String get flagWindy;

  /// No description provided for @flagBreeze.
  ///
  /// In es, this message translates to:
  /// **'brisa'**
  String get flagBreeze;

  /// No description provided for @flagSheltered.
  ///
  /// In es, this message translates to:
  /// **'resguardado'**
  String get flagSheltered;

  /// No description provided for @flagCool.
  ///
  /// In es, this message translates to:
  /// **'fresco'**
  String get flagCool;

  /// No description provided for @flagHot.
  ///
  /// In es, this message translates to:
  /// **'calor'**
  String get flagHot;

  /// No description provided for @feelsLike.
  ///
  /// In es, this message translates to:
  /// **'sensación {deg} °C'**
  String feelsLike(int deg);

  /// No description provided for @statusPleno.
  ///
  /// In es, this message translates to:
  /// **'Al sol'**
  String get statusPleno;

  /// No description provided for @statusSolConNubes.
  ///
  /// In es, this message translates to:
  /// **'Sol con nubes'**
  String get statusSolConNubes;

  /// No description provided for @statusNublado.
  ///
  /// In es, this message translates to:
  /// **'Nublado'**
  String get statusNublado;

  /// No description provided for @statusSombra.
  ///
  /// In es, this message translates to:
  /// **'En sombra'**
  String get statusSombra;

  /// No description provided for @statusNoche.
  ///
  /// In es, this message translates to:
  /// **'De noche'**
  String get statusNoche;

  /// No description provided for @sunUntilSunset.
  ///
  /// In es, this message translates to:
  /// **'sol {h} h {m} min'**
  String sunUntilSunset(int h, int m);

  /// No description provided for @windCalm.
  ///
  /// In es, this message translates to:
  /// **'En calma'**
  String get windCalm;

  /// No description provided for @windLight.
  ///
  /// In es, this message translates to:
  /// **'Brisa ligera'**
  String get windLight;

  /// No description provided for @windBreezy.
  ///
  /// In es, this message translates to:
  /// **'Algo de viento'**
  String get windBreezy;

  /// No description provided for @windWindy.
  ///
  /// In es, this message translates to:
  /// **'Viento'**
  String get windWindy;

  /// No description provided for @windVeryWindy.
  ///
  /// In es, this message translates to:
  /// **'Mucho viento'**
  String get windVeryWindy;

  /// No description provided for @windSpeedFrom.
  ///
  /// In es, this message translates to:
  /// **'{kmh} km/h del {cardinal}'**
  String windSpeedFrom(int kmh, String cardinal);

  /// No description provided for @windSpeed.
  ///
  /// In es, this message translates to:
  /// **'{kmh} km/h'**
  String windSpeed(int kmh);

  /// No description provided for @gusts.
  ///
  /// In es, this message translates to:
  /// **'Rachas de hasta {kmh} km/h'**
  String gusts(int kmh);

  /// No description provided for @windShelteredByBuildings.
  ///
  /// In es, this message translates to:
  /// **'Resguardado por edificios · {kmh} km/h en campo abierto'**
  String windShelteredByBuildings(int kmh);

  /// No description provided for @temperature.
  ///
  /// In es, this message translates to:
  /// **'{deg} °C'**
  String temperature(int deg);

  /// No description provided for @sourceForecast.
  ///
  /// In es, this message translates to:
  /// **'Predicción AEMET'**
  String get sourceForecast;

  /// No description provided for @sourceObservation.
  ///
  /// In es, this message translates to:
  /// **'Observación AEMET'**
  String get sourceObservation;

  /// No description provided for @distanceM.
  ///
  /// In es, this message translates to:
  /// **'{m} m'**
  String distanceM(int m);

  /// No description provided for @distanceKm.
  ///
  /// In es, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @dataSources.
  ///
  /// In es, this message translates to:
  /// **'Fuentes de datos'**
  String get dataSources;

  /// No description provided for @openSourceLicenses.
  ///
  /// In es, this message translates to:
  /// **'Licencias de código abierto'**
  String get openSourceLicenses;

  /// No description provided for @aboutIntro.
  ///
  /// In es, this message translates to:
  /// **'Busca terrazas y mira si ahora mismo se está a gusto: sol o sombra, viento y temperatura.'**
  String get aboutIntro;

  /// No description provided for @creditMap.
  ///
  /// In es, this message translates to:
  /// **'Edificios, calles y locales: © colaboradores de OpenStreetMap (ODbL), preparados por Lat41 Lab con extractos de Geofabrik.'**
  String get creditMap;

  /// No description provided for @creditTiles.
  ///
  /// In es, this message translates to:
  /// **'Mapa base: © MapTiler · © colaboradores de OpenStreetMap.'**
  String get creditTiles;

  /// No description provided for @osmAttribution.
  ///
  /// In es, this message translates to:
  /// **'© colaboradores de OpenStreetMap'**
  String get osmAttribution;

  /// No description provided for @creditWeather.
  ///
  /// In es, this message translates to:
  /// **'Datos meteorológicos: elaboración propia a partir de datos de AEMET.'**
  String get creditWeather;

  /// No description provided for @creditSun.
  ///
  /// In es, this message translates to:
  /// **'Posición del sol: algoritmo de Jean Meeus.'**
  String get creditSun;

  /// No description provided for @adTitle.
  ///
  /// In es, this message translates to:
  /// **'Publicidad (prueba)'**
  String get adTitle;

  /// No description provided for @adBody.
  ///
  /// In es, this message translates to:
  /// **'Aquí iría un anuncio real. Esto es solo para probar cada cuánto aparece.'**
  String get adBody;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @headlineSunnyCold.
  ///
  /// In es, this message translates to:
  /// **'Aquí da un sol muy agradable'**
  String get headlineSunnyCold;

  /// No description provided for @headlineChillyShade.
  ///
  /// In es, this message translates to:
  /// **'Hace fresco y sin sol aquí'**
  String get headlineChillyShade;

  /// No description provided for @notNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get notNow;

  /// No description provided for @introTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Se está bien ahí fuera?'**
  String get introTitle;

  /// No description provided for @introBody1.
  ///
  /// In es, this message translates to:
  /// **'Toca un punto del mapa y mira qué tal se está ahí ahora mismo: sol o sombra, viento y temperatura. Tu bar preferido, tu plaza o un sitio cualquiera.'**
  String get introBody1;

  /// No description provided for @introBody2.
  ///
  /// In es, this message translates to:
  /// **'Activa la capa de locales (datos de OpenStreetMap) para ver también qué tal se está en la terraza de cada bar.'**
  String get introBody2;

  /// No description provided for @introButton.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get introButton;

  /// No description provided for @showIntro.
  ///
  /// In es, this message translates to:
  /// **'Ver la introducción'**
  String get showIntro;

  /// No description provided for @localesLayer.
  ///
  /// In es, this message translates to:
  /// **'Capa de locales'**
  String get localesLayer;

  /// No description provided for @tapMapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca el mapa para ver qué tal se está en ese punto.'**
  String get tapMapHint;

  /// No description provided for @shareApp.
  ///
  /// In es, this message translates to:
  /// **'Compartir esta app'**
  String get shareApp;

  /// No description provided for @locationOff.
  ///
  /// In es, this message translates to:
  /// **'La localización del móvil está apagada. Te muestro el centro de Barcelona.'**
  String get locationOff;

  /// No description provided for @locationDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso de ubicación. Te muestro el centro de Barcelona.'**
  String get locationDenied;

  /// No description provided for @locationNoSignal.
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener tu ubicación. Te muestro el centro de Barcelona.'**
  String get locationNoSignal;

  /// No description provided for @openSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get openSettings;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @computingShade.
  ///
  /// In es, this message translates to:
  /// **'Calculando sombra…'**
  String get computingShade;

  /// No description provided for @computingShadeDetail.
  ///
  /// In es, this message translates to:
  /// **'Aún estoy descargando los edificios de esta zona. La sombra se actualizará en unos segundos.'**
  String get computingShadeDetail;

  /// No description provided for @onlyConfirmedTerraces.
  ///
  /// In es, this message translates to:
  /// **'Solo terrazas confirmadas'**
  String get onlyConfirmedTerraces;

  /// No description provided for @terraceUnconfirmedShort.
  ///
  /// In es, this message translates to:
  /// **'terraza sin confirmar'**
  String get terraceUnconfirmedShort;

  /// No description provided for @hoursUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Horario no disponible.'**
  String get hoursUnavailable;

  /// No description provided for @hoursTerraceCaveat.
  ///
  /// In es, this message translates to:
  /// **'Abierto a esta hora según OpenStreetMap. La terraza puede cerrar antes que el local.'**
  String get hoursTerraceCaveat;

  /// No description provided for @reportError.
  ///
  /// In es, this message translates to:
  /// **'Avisar de un error'**
  String get reportError;

  /// No description provided for @reportOsm.
  ///
  /// In es, this message translates to:
  /// **'Corregir en OpenStreetMap'**
  String get reportOsm;

  /// No description provided for @reportOsmDetail.
  ///
  /// In es, this message translates to:
  /// **'Abre una nota en openstreetmap.org en este punto. Las notas son públicas: cualquiera puede leerlas.'**
  String get reportOsmDetail;

  /// No description provided for @reportEmail.
  ///
  /// In es, this message translates to:
  /// **'Escribir a Lat41 Lab'**
  String get reportEmail;

  /// No description provided for @reportEmailSubject.
  ///
  /// In es, this message translates to:
  /// **'Error en Terrazeo: {name}'**
  String reportEmailSubject(String name);

  /// No description provided for @reportEmailBody.
  ///
  /// In es, this message translates to:
  /// **'Local: {name}\n{url}\n\n¿Qué está mal?\n'**
  String reportEmailBody(String name, String url);

  /// No description provided for @couldNotOpen.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir.'**
  String get couldNotOpen;

  /// No description provided for @recommended.
  ///
  /// In es, this message translates to:
  /// **'Destacado'**
  String get recommended;

  /// No description provided for @onlyRecommended.
  ///
  /// In es, this message translates to:
  /// **'Solo destacados'**
  String get onlyRecommended;

  /// No description provided for @noRecommendedHere.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay ningún local destacado en esta zona. Quita el filtro para ver todas las terrazas.'**
  String get noRecommendedHere;

  /// No description provided for @recommendedDisclosure.
  ///
  /// In es, this message translates to:
  /// **'Patrocinado · paga por aparecer destacado. No cambia el cálculo de sol, sombra ni viento.'**
  String get recommendedDisclosure;

  /// No description provided for @ownerTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Es tu local?'**
  String get ownerTitle;

  /// No description provided for @ownerRecommend.
  ///
  /// In es, this message translates to:
  /// **'Aparece como Destacado'**
  String get ownerRecommend;

  /// No description provided for @ownerRecommendDetail.
  ///
  /// In es, this message translates to:
  /// **'5 € al mes, IVA incluido. Se paga en la web de Stripe y te puedes dar de baja cuando quieras.'**
  String get ownerRecommendDetail;

  /// No description provided for @ownerClaim.
  ///
  /// In es, this message translates to:
  /// **'Reclámalo gratis'**
  String get ownerClaim;

  /// No description provided for @ownerClaimDetail.
  ///
  /// In es, this message translates to:
  /// **'Escríbenos para confirmar que es tuyo y corregir sus datos.'**
  String get ownerClaimDetail;

  /// No description provided for @ownerClaimSubject.
  ///
  /// In es, this message translates to:
  /// **'Reclamo mi local en Terrazeo: {name}'**
  String ownerClaimSubject(String name);

  /// No description provided for @ownerClaimBody.
  ///
  /// In es, this message translates to:
  /// **'Local: {name}\n{url}\n\nNombre y teléfono de contacto:\n'**
  String ownerClaimBody(String name, String url);

  /// No description provided for @haveVenue.
  ///
  /// In es, this message translates to:
  /// **'¿Tienes un local? Aparece en Terrazeo'**
  String get haveVenue;

  /// No description provided for @availableCities.
  ///
  /// In es, this message translates to:
  /// **'Ciudades disponibles'**
  String get availableCities;

  /// No description provided for @availableCitiesIntro.
  ///
  /// In es, this message translates to:
  /// **'En estas ciudades tenemos datos propios de calles y edificios, y las sombras salen al momento. En el resto, la app funciona igual pero puede tardar más.'**
  String get availableCitiesIntro;

  /// No description provided for @outsideCoverage.
  ///
  /// In es, this message translates to:
  /// **'Aquí todavía no tenemos datos propios: los edificios pueden tardar en cargarse o no aparecer. Funciona mejor en las ciudades disponibles.'**
  String get outsideCoverage;

  /// No description provided for @seeCities.
  ///
  /// In es, this message translates to:
  /// **'Ver ciudades'**
  String get seeCities;

  /// No description provided for @statusSolParcial.
  ///
  /// In es, this message translates to:
  /// **'Sol parcial'**
  String get statusSolParcial;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ca',
    'de',
    'en',
    'es',
    'fr',
    'it',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
