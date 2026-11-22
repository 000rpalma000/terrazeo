import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Por qué no se pudo obtener la ubicación real del dispositivo.
enum MotivoSinUbicacion {
  /// Los servicios de localización del sistema están apagados.
  servicioApagado,

  /// El usuario no ha dado permiso (o lo ha denegado para siempre).
  sinPermiso,

  /// Hay permiso pero el GPS no respondió a tiempo y no hay posición previa.
  sinSenal,
}

/// Resultado de pedir la ubicación. Si [esReal] es `false`, [punto] es el
/// respaldo (centro de Barcelona) y [motivo] dice por qué.
typedef Ubicacion = ({LatLng punto, bool esReal, MotivoSinUbicacion? motivo});

/// Ubicación del dispositivo con gestión de permisos.
class LocationService {
  const LocationService({this.limite = const Duration(seconds: 10)});

  /// Tiempo máximo de espera al GPS antes de usar la última posición conocida.
  final Duration limite;

  /// Centro de Barcelona, respaldo si no hay permiso/GPS.
  static final LatLng fallback = LatLng(41.3874, 2.1686);

  /// Una posición previa de hace más de esto ya no se da por buena.
  static const _maxEdadUltimaConocida = Duration(minutes: 30);

  Future<Ubicacion> ubicacionActual() async {
    Ubicacion respaldo(MotivoSinUbicacion m) =>
        (punto: fallback, esReal: false, motivo: m);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return respaldo(MotivoSinUbicacion.servicioApagado);
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return respaldo(MotivoSinUbicacion.sinPermiso);
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: limite,
          ),
        );
        return (
          punto: LatLng(pos.latitude, pos.longitude),
          esReal: true,
          motivo: null,
        );
      } on TimeoutException {
        // Sin señal a tiempo (interiores, simulador sin ubicación…): vale la
        // última posición conocida si es reciente.
        final ultima = await _ultimaConocidaReciente();
        if (ultima != null) return (punto: ultima, esReal: true, motivo: null);
        return respaldo(MotivoSinUbicacion.sinSenal);
      }
    } catch (_) {
      final ultima = await _ultimaConocidaReciente();
      if (ultima != null) return (punto: ultima, esReal: true, motivo: null);
      return respaldo(MotivoSinUbicacion.sinSenal);
    }
  }

  Future<LatLng?> _ultimaConocidaReciente() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      if (DateTime.now().difference(p.timestamp) > _maxEdadUltimaConocida) {
        return null;
      }
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Abre los ajustes adecuados para arreglar [motivo].
  Future<void> abrirAjustes(MotivoSinUbicacion motivo) async {
    try {
      if (motivo == MotivoSinUbicacion.servicioApagado) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }
}
