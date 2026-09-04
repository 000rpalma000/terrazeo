import 'package:latlong2/latlong.dart';

/// Un local de comida/bebida obtenido de OpenStreetMap.
class Bar {
  final String osmId;
  final String nombre;
  final LatLng punto;

  /// `amenity`: bar, pub, cafe, restaurant, biergarten, fast_food…
  final String tipo;

  /// `outdoor_seating=yes` o `amenity=biergarten`: tiene terraza declarada.
  final bool terrazaDeclarada;

  const Bar({
    required this.osmId,
    required this.nombre,
    required this.punto,
    required this.tipo,
    required this.terrazaDeclarada,
  });

  factory Bar.fromOverpass(Map<String, dynamic> el) {
    final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final center = el['center'] as Map?;
    final lat = (el['lat'] ?? center?['lat']) as num;
    final lon = (el['lon'] ?? center?['lon']) as num;
    final amenity = (tags['amenity'] ?? '').toString();
    final outdoor = (tags['outdoor_seating'] ?? '').toString().toLowerCase();

    return Bar(
      osmId: '${el['type']}/${el['id']}',
      nombre: tags['name']?.toString() ?? _nombrePorTipo(amenity),
      punto: LatLng(lat.toDouble(), lon.toDouble()),
      tipo: amenity.isEmpty ? 'bar' : amenity,
      terrazaDeclarada: outdoor == 'yes' ||
          outdoor == 'terrace' ||
          amenity == 'biergarten',
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
