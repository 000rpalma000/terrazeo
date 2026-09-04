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
      String.fromEnvironment('MAP_STYLE', defaultValue: 'basic-v2');

  /// Identificador de la app para la cabecera User-Agent de las teselas.
  static const userAgent = 'com.terrazeo.app';

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

  /// Texto de atribución que debe mostrarse sobre el mapa.
  static String get atribucion {
    if (_maptilerKey.isNotEmpty) return '© MapTiler © OpenStreetMap';
    if (_stadiaKey.isNotEmpty) return '© Stadia Maps © OpenStreetMap';
    return '© OpenStreetMap';
  }
}
