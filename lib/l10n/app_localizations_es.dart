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
  String get buildingsUnavailable =>
      'No se han podido cargar los edificios de esta zona. Vuelve a intentarlo en un rato.';

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
      'Edificios, calles y locales: © colaboradores de OpenStreetMap (ODbL), preparados por Lat41 Lab con extractos de Geofabrik.';

  @override
  String get creditTiles =>
      'Mapa base: © MapTiler · © colaboradores de OpenStreetMap.';

  @override
  String get osmAttribution => '© colaboradores de OpenStreetMap';

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
  String get close => 'Cerrar';

  @override
  String get headlineSunnyCold => 'Aquí da un sol muy agradable';

  @override
  String get headlineChillyShade => 'Hace fresco y sin sol aquí';

  @override
  String get notNow => 'Ahora no';

  @override
  String get introTitle => '¿Se está bien ahí fuera?';

  @override
  String get introBody1 =>
      'Toca un punto del mapa y mira qué tal se está ahí ahora mismo: sol o sombra, viento y temperatura. Tu bar preferido, tu plaza o un sitio cualquiera.';

  @override
  String get introBody2 =>
      'Activa la capa de locales (datos de OpenStreetMap) para ver también qué tal se está en la terraza de cada bar.';

  @override
  String get introButton => 'Entendido';

  @override
  String get showIntro => 'Ver la introducción';

  @override
  String get localesLayer => 'Capa de locales';

  @override
  String get tapMapHint =>
      'Toca el mapa para ver qué tal se está en ese punto.';

  @override
  String get shareApp => 'Compartir esta app';

  @override
  String get locationOff =>
      'La localización del móvil está apagada. Te muestro el centro de Barcelona.';

  @override
  String get locationDenied =>
      'Sin permiso de ubicación. Te muestro el centro de Barcelona.';

  @override
  String get locationNoSignal =>
      'No se pudo obtener tu ubicación. Te muestro el centro de Barcelona.';

  @override
  String get openSettings => 'Ajustes';

  @override
  String get retry => 'Reintentar';

  @override
  String get computingShade => 'Calculando sombra…';

  @override
  String get computingShadeDetail =>
      'Aún estoy descargando los edificios de esta zona. La sombra se actualizará en unos segundos.';

  @override
  String get onlyConfirmedTerraces => 'Solo terrazas confirmadas';

  @override
  String get terraceUnconfirmedShort => 'terraza sin confirmar';

  @override
  String get hoursUnavailable => 'Horario no disponible.';

  @override
  String get hoursTerraceCaveat =>
      'Abierto a esta hora según OpenStreetMap. La terraza puede cerrar antes que el local.';

  @override
  String get reportError => 'Avisar de un error';

  @override
  String get reportOsm => 'Corregir en OpenStreetMap';

  @override
  String get reportOsmDetail =>
      'Abre una nota en openstreetmap.org en este punto. Las notas son públicas: cualquiera puede leerlas.';

  @override
  String get reportEmail => 'Escribir a Lat41 Lab';

  @override
  String reportEmailSubject(String name) {
    return 'Error en Terrazeo: $name';
  }

  @override
  String reportEmailBody(String name, String url) {
    return 'Local: $name\n$url\n\n¿Qué está mal?\n';
  }

  @override
  String get couldNotOpen => 'No se ha podido abrir.';

  @override
  String get recommended => 'Destacado';

  @override
  String get onlyRecommended => 'Solo destacados';

  @override
  String get noRecommendedHere =>
      'Todavía no hay ningún local destacado en esta zona. Quita el filtro para ver todas las terrazas.';

  @override
  String get recommendedDisclosure =>
      'Patrocinado · paga por aparecer destacado. No cambia el cálculo de sol, sombra ni viento.';

  @override
  String get ownerTitle => '¿Es tu local?';

  @override
  String get ownerRecommend => 'Aparece como Destacado';

  @override
  String get ownerRecommendDetail =>
      '5 € al mes, IVA incluido. Se paga en la web de Stripe y te puedes dar de baja cuando quieras.';

  @override
  String get ownerClaim => 'Reclámalo gratis';

  @override
  String get ownerClaimDetail =>
      'Escríbenos para confirmar que es tuyo y corregir sus datos.';

  @override
  String ownerClaimSubject(String name) {
    return 'Reclamo mi local en Terrazeo: $name';
  }

  @override
  String ownerClaimBody(String name, String url) {
    return 'Local: $name\n$url\n\nNombre y teléfono de contacto:\n';
  }

  @override
  String get haveVenue => '¿Tienes un local? Aparece en Terrazeo';

  @override
  String get availableCities => 'Ciudades disponibles';

  @override
  String get availableCitiesIntro =>
      'En estas ciudades tenemos datos propios de calles y edificios, y las sombras salen al momento. En el resto, la app funciona igual pero puede tardar más.';

  @override
  String get outsideCoverage =>
      'Aquí todavía no tenemos datos propios: los edificios pueden tardar en cargarse o no aparecer. Funciona mejor en las ciudades disponibles.';

  @override
  String get seeCities => 'Ver ciudades';

  @override
  String get statusSolParcial => 'Sol parcial';
}
