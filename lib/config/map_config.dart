/// Origen de las teselas del mapa.
///
/// La política de uso de OpenStreetMap NO permite usar sus teselas estándar en
/// apps publicadas. Para producción hay que dar de alta una clave gratuita en
/// un proveedor (MapTiler o Stadia Maps) y compilar con:
///
///   flutter build ... --dart-define=MAPTILER_KEY=xxxxxxxx
///   (o) --dart-define=STADIA_KEY=xxxxxxxx
///
/// Sin clave se usan las teselas de OSM: válido solo para desarrollo.
class MapConfig {
  static const _maptilerKey = String.fromEnvironment('MAPTILER_KEY');
  static const _stadiaKey = String.fromEnvironment('STADIA_KEY');

  /// Identificador de la app para la cabecera User-Agent de las teselas.
  static const userAgent = 'com.terrazeo.app';

  static bool get hayClave =>
      _maptilerKey.isNotEmpty || _stadiaKey.isNotEmpty;

  static String get urlTemplate {
    if (_maptilerKey.isNotEmpty) {
      return 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png'
          '?key=$_maptilerKey';
    }
    if (_stadiaKey.isNotEmpty) {
      return 'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}.png'
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
