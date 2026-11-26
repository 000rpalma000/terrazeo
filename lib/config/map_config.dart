import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Origen y estilo de las teselas del mapa.
///
/// La política de uso de OpenStreetMap NO permite usar sus teselas estándar en
/// apps publicadas. Para producción se usa MapTiler (clave gratuita) pasada al
/// compilar con:
///
///   flutter build ... --dart-define-from-file=dart_defines.json
///
/// Sin clave se cae a las teselas de OSM: válido solo para desarrollo.
class MapConfig {
  static const _maptilerKey = String.fromEnvironment('MAPTILER_KEY');
  static const _stadiaKey = String.fromEnvironment('STADIA_KEY');

  /// Estilo de MapTiler. Opciones: streets-v2 · basic-v2 · bright-v2 ·
  /// openstreetmap · dataviz-light · dataviz · outdoor-v2 · topo-v2 ·
  /// satellite · hybrid. Se puede sobreescribir con
  /// --dart-define=MAP_STYLE=basic-v2
  static const _estilo =
      String.fromEnvironment('MAP_STYLE', defaultValue: 'dataviz');

  /// Identificador de la app para la cabecera User-Agent de las teselas.
  static const userAgent = 'com.lat41lab.terrazeo';

  static bool get hayClave =>
      _maptilerKey.isNotEmpty || _stadiaKey.isNotEmpty;

  /// `{r}` lo sustituye flutter_map por `@2x` en pantallas de alta densidad.
  static String get urlTemplate {
    if (_maptilerKey.isNotEmpty) {
      return 'https://api.maptiler.com/maps/$_estilo/{z}/{x}/{y}{r}.png'
          '?key=$_maptilerKey';
    }
    if (_stadiaKey.isNotEmpty) {
      return 'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}{r}.png'
          '?api_key=$_stadiaKey';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Los cuadros del mapa se guardan en el teléfono (caché de flutter_map,
  /// en la carpeta de caché del sistema) y valen **30 días**: MapTiler los
  /// marca como válidos solo 8 horas y, pasado ese tiempo, se volverían a
  /// pedir (cada cuadro es una petición del plan). Como mucho 200 MB; al
  /// arrancar se borran los más antiguos si se pasa. La clave no forma
  /// parte del nombre del archivo, para no perder la caché si cambia.
  static final cacheTeselas = BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 200 * 1000 * 1000,
    overrideFreshAge: const Duration(days: 30),
    tileKeyGenerator: (url) => BuiltInMapCachingProvider.uuidTileKeyGenerator(
        url.replaceFirst(RegExp(r'[?&](api_)?key=[^&]*'), '')),
  );

  static TileProvider proveedorTeselas() =>
      NetworkTileProvider(cachingProvider: cacheTeselas);

  /// Logotipo de MapTiler sobre el mapa (lo exige su plan gratuito).
  static Widget? logoProveedor() => _maptilerKey.isEmpty
      ? null
      : Align(
          alignment: Alignment.bottomLeft,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 0, 6),
              child: SvgPicture.asset('assets/map/maptiler_logo.svg',
                  height: 22, semanticsLabel: 'MapTiler'),
            ),
          ),
        );

  /// Proveedor de las teselas del mapa base, para la atribución (vacío si
  /// son las de OpenStreetMap, que ya se citan aparte).
  static String get atribucionTeselas {
    if (_maptilerKey.isNotEmpty) return '© MapTiler';
    if (_stadiaKey.isNotEmpty) return '© Stadia Maps';
    return '';
  }
}

