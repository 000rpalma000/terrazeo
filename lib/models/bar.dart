import 'package:latlong2/latlong.dart';

import 'horario.dart';

/// Qué dice OpenStreetMap de la terraza (`outdoor_seating`).
enum Terraza {
  /// `yes`, `terrace`, `sidewalk`, `street`, `pedestrian_zone`, `parklet`,
  /// `only`, o `amenity=biergarten`.
  confirmada,

  /// Sin etiqueta: puede tenerla o no.
  sinConfirmar,

  /// `outdoor_seating=no`: no se muestra.
  no;

  static const _si = {
    'yes', 'terrace', 'sidewalk', 'street', 'pedestrian_zone', 'parklet', 'only',
  };

  static Terraza deEtiqueta(String? outdoorSeating, String amenity) {
    final v = (outdoorSeating ?? '').trim().toLowerCase();
    if (_si.contains(v) || amenity == 'biergarten') return Terraza.confirmada;
    if (v == 'no') return Terraza.no;
    return Terraza.sinConfirmar;
  }
}

/// Un local de comida/bebida obtenido de OpenStreetMap.
class Bar {
  final String osmId;
  final String nombre;
  final LatLng punto;

  /// `amenity`: bar, pub, cafe, restaurant, biergarten, fast_food…
  final String tipo;

  final Terraza terraza;

  /// `opening_hours` entendido, o `null` si no tiene o no se entiende
  /// ("horario no disponible").
  final Horario? horario;

  bool get terrazaDeclarada => terraza == Terraza.confirmada;

  /// Si está abierto en [t]: `null` si no se sabe.
  bool? abiertoEn(DateTime t) => horario?.abiertoEn(t);

  const Bar({
    required this.osmId,
    required this.nombre,
    required this.punto,
    required this.tipo,
    required this.terraza,
    this.horario,
  });

  factory Bar.fromOverpass(Map<String, dynamic> el) {
    final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final center = el['center'] as Map?;
    final lat = (el['lat'] ?? center?['lat']) as num;
    final lon = (el['lon'] ?? center?['lon']) as num;
    final amenity = (tags['amenity'] ?? '').toString();
    return Bar(
      osmId: '${el['type']}/${el['id']}',
      nombre: tags['name']?.toString() ?? _nombrePorTipo(amenity),
      punto: LatLng(lat.toDouble(), lon.toDouble()),
      tipo: amenity.isEmpty ? 'bar' : amenity,
      terraza: Terraza.deEtiqueta(tags['outdoor_seating']?.toString(), amenity),
      horario: Horario.parse(tags['opening_hours']?.toString()),
    );
  }

  /// Fila del archivo empaquetado `assets/data/bares.json`
  /// (`[osmId, lat, lon, nombre, amenity, terraza, horario]`, ver
  /// tool/datos/FORMATO.md). `terraza`: 1 confirmada, -1 no, 0 sin confirmar.
  factory Bar.fromFila(List<dynamic> f) {
    final amenity = (f[4] as String?) ?? 'bar';
    final nombre = (f[3] as String?) ?? '';
    return Bar(
      osmId: f[0] as String,
      nombre: nombre.isEmpty ? _nombrePorTipo(amenity) : nombre,
      punto: LatLng((f[1] as num).toDouble(), (f[2] as num).toDouble()),
      tipo: amenity.isEmpty ? 'bar' : amenity,
      terraza: switch (f[5]) {
        1 => Terraza.confirmada,
        -1 => Terraza.no,
        _ => Terraza.sinConfirmar,
      },
      horario: f.length > 6 ? Horario.parse(f[6] as String?) : null,
    );
  }

  /// Prioridad para desempatar el orden: primero bares/pubs, luego cafés,
  /// después restaurantes y comida rápida.
  int get prioridadTipo => switch (tipo) {
        'bar' || 'pub' || 'biergarten' => 0,
        'cafe' => 1,
        'restaurant' => 2,
        _ => 3,
      };

  static String _nombrePorTipo(String amenity) {
    switch (amenity) {
      case 'cafe':
        return 'Cafetería';
      case 'restaurant':
        return 'Restaurante';
      case 'pub':
        return 'Pub';
      case 'fast_food':
        return 'Comida rápida';
      case 'biergarten':
        return 'Terraza cervecera';
      default:
        return 'Bar';
    }
  }
}
