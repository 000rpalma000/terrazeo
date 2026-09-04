import 'package:flutter_test/flutter_test.dart';
import 'package:terrazeo/models/building_height.dart';

void main() {
  test('usa height si está', () {
    final e = BuildingHeightEstimator();
    expect(e.estimar({'building': 'yes', 'height': '18'}), 18);
    expect(e.estimar({'building': 'yes', 'height': '18 m'}), 18);
  });

  test('convierte pies a metros', () {
    final e = BuildingHeightEstimator();
    expect(e.estimar({'building': 'house', 'height': "30'"}),
        closeTo(9.144, 0.001));
  });

  test('building:levels + roof:levels', () {
    final e = BuildingHeightEstimator(metrosPorPlanta: 3);
    expect(e.estimar({'building': 'yes', 'building:levels': '5'}), 15);
    expect(
      e.estimar({'building': 'yes', 'building:levels': '5', 'roof:levels': '1'}),
      18,
    );
  });

  test('tipo pequeño manda sobre la mediana local', () {
    final e = BuildingHeightEstimator(metrosPorPlanta: 3)
      ..calibrar([
        {'building:levels': '8'},
        {'building:levels': '8'},
        {'building:levels': '8'},
      ]);
    // garaje sin plantas: no debe heredar las 8 del barrio
    expect(e.estimar({'building': 'garage'}), 3);
    // edificio genérico sin plantas: sí hereda la mediana local (8)
    expect(e.estimar({'building': 'yes'}), 24);
  });

  test('sin ninguna pista cae al genérico y luego a la constante', () {
    final e = BuildingHeightEstimator(metrosPorPlanta: 3, alturaGlobalM: 9);
    expect(e.estimar({'building': 'apartments'}), 15); // 5 plantas genéricas
    expect(e.estimar({'building': 'yes'}), 9); // constante global
  });

  test('mediana local se calcula con plantas y con height', () {
    final e = BuildingHeightEstimator(metrosPorPlanta: 4)
      ..calibrar([
        {'building:levels': '4'},
        {'height': '20'}, // 20/4 = 5 plantas
        {'building': 'yes'}, // sin dato, no cuenta
      ]);
    expect(e.medianaPlantasLocal, 4.5);
  });
}
