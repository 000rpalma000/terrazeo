import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/map_config.dart';
import '../l10n/app_localizations.dart';
import '../models/bar.dart';
import '../models/comfort.dart';
import '../models/geo.dart';
import '../models/point_report.dart';
import '../models/shadow_map.dart';
import '../models/sun_status.dart';
import '../models/weather_conditions.dart';
import '../services/weather_service.dart';
import 'about_screen.dart';
import '../services/locale_controller.dart';
import '../services/location_service.dart';
import '../services/osm_area_service.dart';
import '../services/shadow_service.dart';
import '../services/sun_service.dart';
import '../services/wind_shelter_service.dart';
import '../widgets/intro_sheet.dart';
import '../widgets/report_widgets.dart';

class TerracesScreen extends StatefulWidget {
  const TerracesScreen({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<TerracesScreen> createState() => _TerracesScreenState();
}

class _TerracesScreenState extends State<TerracesScreen> {
  final _map = MapController();
  final _location = const LocationService();
  final _osm = OsmAreaService();
  final _sun = const SunService();
  final _shadow = const ShadowService();
  final _viento = const WindShelterService();
  final _tiempo = WeatherService();

  LatLng _centro = LocationService.fallback;

  /// Ubicación actual del usuario (null hasta que se obtiene).
  LatLng? _miUbicacion;

  // Locales: los empaquetados en la app (al instante) + los que llegan de
  // Overpass con cada tesela. Contexto (edificios, calles) por teselas.
  BaresEmpaquetados _empaquetados = const BaresEmpaquetados([], [], '');
  final Map<String, Bar> _baresPorId = {};
  final Map<Tesela, ZonaOsm> _teselas = {};

  /// Locales "de base" que nunca se descartan de memoria: los empaquetados
  /// (Barcelona) + los de cada ciudad descargada entera.
  final Map<String, Bar> _baresBase = {};
  final Set<Region> _regionesListas = {};
  final Set<Region> _regionesEnCurso = {};
  List<BuildingFootprint> _edificios = const [];
  List<List<LatLng>> _lineas = const [];
  bool _descargando = false;

  /// Locales con suscripción (vacío mientras no se active; ver
  /// docs/MONETIZACION.md).

  /// El mapa se movió durante una descarga: al acabar, se carga la vista nueva.
  bool _pendiente = false;

  WeatherConditions? _ahora;
  List<WeatherConditions> _prevision = const [];

  DateTime? _horaSel; // null = ahora
  List<PointReport> _terrazas = const [];
  PointReport? _seleccion; // detalle abierto (bar o punto libre)

  /// Capa de locales (terrazas) visible. Si está apagada, la app es solo
  /// "toca un punto y mira qué tal se está".
  bool _capaLocales = true;
  static const _kCapaLocales = 'capa_locales';

  bool _cargando = true; // carga inicial (overlay)
  bool _cargandoZona = false; // descarga incremental al mover el mapa
  bool _error = false;
  bool _demasiadoLejos = false; // zoom muy alejado

  Timer? _debounce;

  static const _diagMaxVisibleM = 2200.0;

  /// Teselas por petición a Overpass (las más cercanas al centro primero).
  static const _teselasPorPeticion = 6;

  /// Teselas en memoria como máximo (~11 km²); se descartan las más lejanas.
  static const _maxTeselas = 36;

  @override
  void initState() {
    super.initState();
    _cargarPrefs();
    _arrancar();
  }

  Future<void> _cargarPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _capaLocales = sp.getBool(_kCapaLocales) ?? true);
    }
    // La introducción sale en cada apertura.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mostrarIntro(context);
      });
    }
  }

  Future<void> _toggleCapaLocales() async {
    setState(() {
      _capaLocales = !_capaLocales;
      if (!_capaLocales && _seleccion?.bar != null) _seleccion = null;
    });
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kCapaLocales, _capaLocales);
    _recalcularVisible();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _osm.dispose();
    _tiempo.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _arrancar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    // Los locales empaquetados no necesitan red: se leen mientras se pide la
    // ubicación.
    final empaquetados = BaresEmpaquetados.cargar();

    final u = await _location.ubicacionActual();
    _centro = u.punto;
    // Solo se marca "estás aquí" si la posición es real, no el respaldo.
    _miUbicacion = u.esReal ? u.punto : null;
    _map.move(_centro, 16);
    if (u.motivo != null) _avisarSinUbicacion(u.motivo!);

    _empaquetados = await empaquetados;
    for (final b in _empaquetados.bares) {
      _baresBase[b.osmId] = b;
      _baresPorId[b.osmId] = b;
    }
    if (!mounted) return;
    setState(() => _cargando = false);
    _recalcularVisible(); // locales al instante (provisionales, sin sombra)

    // El tiempo y los edificios llegan cada uno por su lado y recalculan.
    unawaited(_cargarTiempo());
    await _refrescarPorVista();
  }

  Future<void> _cargarTiempo() async {
    try {
      final t = await _tiempo.condicionesYPrevision(_centro);
      _ahora = t.ahora;
      _prevision = t.prevision;
      if (mounted) _recalcularVisible();
    } catch (_) {
      // Sin tiempo el veredicto se basa solo en sol/sombra.
    }
  }

  // --- Descarga por teselas -----------------------------------------

  void _onMapaMovido() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refrescarPorVista);
  }

  Future<void> _refrescarPorVista() async {
    if (!mounted) return;
    if (_descargando) {
      _pendiente = true;
      return;
    }
    final LatLng centro;
    final LatLngBounds bounds;
    try {
      centro = _map.camera.center;
      bounds = _map.camera.visibleBounds;
    } catch (_) {
      return;
    }
    final diag = Geo.distancia(bounds.southWest, bounds.northEast);

    if (diag > _diagMaxVisibleM) {
      setState(() {
        _demasiadoLejos = true;
        _terrazas = const [];
      });
      return;
    }
    if (_demasiadoLejos) setState(() => _demasiadoLejos = false);

    // Lo que ya hay en memoria se pinta ya; luego llega lo que falte.
    _recalcularVisible();
    _asegurarCiudad(centro);

    // Margen de ~110 m: las sombras de edificios justo fuera de la vista
    // también cuentan.
    const m = 0.001;
    final faltan = Tesela.cubriendo(bounds.south - m, bounds.west - m,
            bounds.north + m, bounds.east + m)
        .where((t) => !_teselas.containsKey(t))
        .toList()
      ..sort((a, b) => Geo.distancia(centro, a.centro)
          .compareTo(Geo.distancia(centro, b.centro)));
    if (faltan.isEmpty) return;

    _descargando = true;
    setState(() => _cargandoZona = true);
    try {
      // Lo guardado en disco se pinta ya, sin esperar a la red.
      final guardadas = await _osm.leerGuardadas(faltan);
      if (guardadas.isNotEmpty) {
        _teselas.addAll(guardadas);
        _rehacerContexto(centro);
        if (mounted) _recalcularVisible();
      }
      final porBajar = [
        for (final t in faltan)
          if (!guardadas.containsKey(t)) t,
      ];
      // Si el usuario se mueve, se corta: primero lo nuevo.
      for (var k = 0;
          k < porBajar.length && !_pendiente;
          k += _teselasPorPeticion) {
        final lote = porBajar.sublist(
            k, math.min(k + _teselasPorPeticion, porBajar.length));
        _teselas.addAll(await _osm.descargarTeselas(lote));
        _rehacerContexto(centro);
        _error = false;
        if (mounted) _recalcularVisible();
      }
    } catch (e) {
      debugPrint('[osm] no se pudieron cargar las teselas: $e');
      _error = true;
    } finally {
      _descargando = false;
      if (mounted) setState(() => _cargandoZona = false);
    }
    if (_pendiente && mounted) {
      _pendiente = false;
      unawaited(_refrescarPorVista());
    }
  }

  /// Rehace las listas de contexto a partir de las teselas en memoria y
  /// descarta las más lejanas si hay demasiadas (memoria acotada).
  void _rehacerContexto(LatLng cerca) {
    if (_teselas.length > _maxTeselas) {
      final orden = _teselas.keys.toList()
        ..sort((a, b) => Geo.distancia(cerca, a.centro)
            .compareTo(Geo.distancia(cerca, b.centro)));
      for (final t in orden.skip(_maxTeselas * 2 ~/ 3)) {
        _teselas.remove(t);
      }
      // Locales: los empaquetados siempre; de Overpass, solo los de teselas
      // que siguen en memoria.
      _baresPorId
        ..clear()
        ..addAll(_baresBase);
    }
    _edificios = [for (final z in _teselas.values) ...z.edificios];
    _lineas = [for (final z in _teselas.values) ...z.lineasPublicas];
    for (final z in _teselas.values) {
      for (final b in z.bares) {
        _baresPorId[b.osmId] = b;
      }
    }
  }

  /// Descarga en segundo plano todos los locales de la ciudad (región de
  /// ~11 km) en la que está [p], una sola vez: queda guardada 30 días y a
  /// partir de ahí sus locales salen al instante, como los de Barcelona.
  void _asegurarCiudad(LatLng p) {
    final r = Region.de(p);
    if (_regionesListas.contains(r) ||
        _regionesEnCurso.contains(r) ||
        _empaquetados.cubreRegion(r)) {
      return;
    }
    _regionesEnCurso.add(r);
    _osm.cargarRegion(r).then((bares) {
      _regionesListas.add(r);
      for (final b in bares) {
        _baresBase[b.osmId] = b;
        _baresPorId[b.osmId] = b;
      }
      if (mounted) _recalcularVisible();
    }).catchError((Object e) {
      // Sin red o Overpass caído: se reintenta en el próximo movimiento.
      debugPrint('[osm] no se pudo bajar la ciudad ${r.clave}: $e');
    }).whenComplete(() => _regionesEnCurso.remove(r));
  }

  bool _contextoListo(LatLng p) => _teselas.containsKey(Tesela.de(p));

  // --- Recálculo local (sin red) ------------------------------------

  static const _maxTerrazas = 300;

  void _recalcularVisible() {
    if (_baresPorId.isEmpty) return;

    LatLng centroV;
    LatLngBounds bounds;
    try {
      centroV = _map.camera.center;
      bounds = _map.camera.visibleBounds;
    } catch (_) {
      centroV = _centro;
      bounds = LatLngBounds(
        LatLng(centroV.latitude - 0.004, centroV.longitude - 0.005),
        LatLng(centroV.latitude + 0.004, centroV.longitude + 0.005),
      );
    }
    final hora = _horaSel ?? DateTime.now();

    // Contexto local (barato: distancia del primer vértice).
    final edifCerca = _edificios
        .where((e) => Geo.distancia(centroV, e.ring.first) < 700)
        .toList();
    final lineasCerca = _lineas
        .where((l) => Geo.distancia(centroV, l.first) < 700)
        .toList();
    final shadow = _shadow.construir(edifCerca, centroV, hora);

    // El sol es casi el mismo en toda la vista: se calcula una sola vez.
    final pos = _sun.posicion(centroV, hora);
    final ocaso = _sun.ocaso(centroV, hora);

    // Con la capa de locales apagada no se evalúan las terrazas (ahorra el
    // grueso del cálculo); la app queda como "toca un punto".
    final reports = <PointReport>[];
    if (_capaLocales) {
      var visibles =
          _baresPorId.values.where((b) => bounds.contains(b.punto)).toList();
      if (visibles.length > _maxTerrazas) {
        visibles.sort((a, b) => Geo.distancia(centroV, a.punto)
            .compareTo(Geo.distancia(centroV, b.punto)));
        visibles = visibles.sublist(0, _maxTerrazas);
      }
      for (final b in visibles) {
        reports.add(_evaluar(b.punto,
            bar: b,
            provisional: !_contextoListo(b.punto),
            hora: hora,
            shadow: shadow,
            edificios: edifCerca,
            lineas: lineasCerca,
            pos: pos,
            ocaso: ocaso));
      }
      reports.sort((a, b) {
        // Los que aún no tienen la sombra calculada, al final.
        if (a.provisional != b.provisional) return a.provisional ? 1 : -1;
        var c = a.comfort.level.index.compareTo(b.comfort.level.index);
        if (c != 0) return c;
        c = (a.bar?.prioridadTipo ?? 2).compareTo(b.bar?.prioridadTipo ?? 2);
        if (c != 0) return c;
        return Geo.distancia(centroV, a.punto)
            .compareTo(Geo.distancia(centroV, b.punto));
      });
    }

    setState(() {
      _terrazas = reports;
      final sel = _seleccion;
      if (sel?.bar != null) {
        for (final r in reports) {
          if (r.bar?.osmId == sel!.bar!.osmId) {
            _seleccion = r;
            break;
          }
        }
      } else if (sel != null) {
        _seleccion = _evaluar(sel.punto,
            provisional: !_contextoListo(sel.punto),
            hora: hora,
            shadow: shadow,
            edificios: edifCerca,
            lineas: lineasCerca,
            pos: _sun.posicion(sel.punto, hora),
            ocaso: _sun.ocaso(sel.punto, hora));
      }
    });
  }

  PointReport _evaluar(
    LatLng punto0, {
    Bar? bar,
    bool provisional = false,
    required DateTime hora,
    required ShadowMap shadow,
    required List<BuildingFootprint> edificios,
    required List<List<LatLng>> lineas,
    required SunPosition pos,
    required DateTime ocaso,
  }) {
    final ajustado0 =
        OsmAreaService.ajustarAEspacioPublico(punto0, edificios, lineas);
    final punto = ajustado0 ?? punto0;
    final ajustado = ajustado0 != null && !identical(ajustado0, punto0);

    // El sol se calcula una vez por recálculo (misma vista ≈ misma posición).
    final esDia = pos.elevationDeg > 0;
    final tapado = esDia && shadow.enSombra(punto);

    final w = _tiempoPara(hora);
    final cloud = w?.sky.cloudFraction;
    final status = combinarSunStatus(
      esDeDia: esDia,
      tapadoPorEdificio: tapado,
      cloudFraction: cloud,
    );

    // Viento local: el pronóstico regional, descontado el resguardo que dan
    // los edificios a barlovento.
    final vientoReg = w?.windSpeedKmh;
    final abrigo = vientoReg == null
        ? 0.0
        : _viento.abrigo(punto, edificios, w?.windDirectionDeg?.toDouble());
    final vientoLoc = vientoReg == null
        ? null
        : WindShelterService.vientoLocal(vientoReg, abrigo);

    final comfort = evaluarConfort(
      sunStatus: status,
      windKmh: vientoLoc,
      tempC: w?.temperatureC,
      instante: hora,
      latitud: punto.latitude,
      abrigo: abrigo,
    );

    Duration? restante;
    if (esDia) {
      final d = ocaso.difference(hora);
      restante = d.isNegative ? Duration.zero : d;
    }

    return PointReport(
      bar: bar,
      comfort: comfort,
      punto: punto,
      ajustado: ajustado,
      instante: hora,
      esPrevision: _horaSel != null,
      sunStatus: status,
      sunElevationDeg: pos.elevationDeg,
      sunAzimuthDeg: pos.azimuthDeg,
      cloudFraction: cloud,
      solRestante: restante,
      windSpeedKmh: vientoLoc,
      windSpeedRegionalKmh: vientoReg,
      windShelterFactor: abrigo,
      windGustKmh: w?.windGustKmh,
      windDirectionDeg: w?.windDirectionDeg,
      windDirectionCardinal: w?.windDirectionCardinal,
      temperatureC: w?.temperatureC,
      provisional: provisional,
    );
  }

  WeatherConditions? _tiempoPara(DateTime t) {
    if (_horaSel == null && _ahora != null) return _ahora;
    if (_prevision.isEmpty) return _ahora;
    WeatherConditions mejor = _prevision.first;
    var mejorDelta = mejor.timestamp.difference(t).abs();
    for (final w in _prevision.skip(1)) {
      final d = w.timestamp.difference(t).abs();
      if (d < mejorDelta) {
        mejor = w;
        mejorDelta = d;
      }
    }
    return mejor;
  }

  void _elegirHora(DateTime? cuando) {
    setState(() => _horaSel = cuando);
    _recalcularVisible();
  }

  void _seleccionarBar(PointReport r) {
    setState(() => _seleccion = r);
    _map.move(r.punto, _map.camera.zoom.clamp(16, 18));
  }

  void _tapMapa(LatLng p) {
    final hora = _horaSel ?? DateTime.now();
    final edifCerca =
        _edificios.where((e) => Geo.distancia(p, e.ring.first) < 400).toList();
    final lineasCerca =
        _lineas.where((l) => Geo.distancia(p, l.first) < 400).toList();
    final shadow = _shadow.construir(edifCerca, p, hora);
    setState(() => _seleccion = _evaluar(p,
        provisional: !_contextoListo(p),
        hora: hora,
        shadow: shadow,
        edificios: edifCerca,
        lineas: lineasCerca,
        pos: _sun.posicion(p, hora),
        ocaso: _sun.ocaso(p, hora)));
  }

  Future<void> _elegirIdioma() async {
    final l10n = AppLocalizations.of(context);
    final actual = widget.localeController.locale?.languageCode ?? '';
    final elegido = await showDialog<OpcionIdioma>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final op in idiomasDisponibles)
            ListTile(
              title:
                  Text(op.locale == null ? l10n.languageSystem : op.nombre),
              trailing: (op.locale?.languageCode ?? '') == actual
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, op),
            ),
        ],
      ),
    );
    if (elegido != null) await widget.localeController.establecer(elegido.locale);
  }

  // --- UI --------------------------------------------------------------

  /// Gris mientras la sombra no está calculada (faltan los edificios).
  static Color _colorReporte(PointReport r) => r.provisional
      ? const Color(0xFF9E9E9E)
      : _colorConfort(r.comfort.level);

  static Color _colorConfort(ComfortLevel l) => switch (l) {
        ComfortLevel.muyAgradable => const Color(0xFF2E7D32),
        ComfortLevel.agradable => const Color(0xFF7CB342),
        ComfortLevel.justo => const Color(0xFFF2A413),
        ComfortLevel.incomodo => const Color(0xFFC62828),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.language,
            icon: const Icon(Icons.translate),
            onPressed: _elegirIdioma,
          ),
          IconButton(
            tooltip: l10n.localesLayer,
            isSelected: _capaLocales,
            icon: const Icon(Icons.local_cafe_outlined),
            selectedIcon: const Icon(Icons.local_cafe),
            onPressed: _toggleCapaLocales,
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _arrancar,
          ),
          IconButton(
            tooltip: l10n.about,
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _mapa(),
                // Siempre visible: si aún no hay ubicación real, reintenta.
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'miUbicacion',
                    onPressed: _centrarEnMiUbicacion,
                    child: Icon(_miUbicacion != null
                        ? Icons.my_location
                        : Icons.location_searching),
                  ),
                ),
                if (_cargando)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x22000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          _panel(l10n),
        ],
      ),
    );
  }

  void _avisarSinUbicacion(MotivoSinUbicacion motivo) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final texto = switch (motivo) {
      MotivoSinUbicacion.servicioApagado => l10n.locationOff,
      MotivoSinUbicacion.sinPermiso => l10n.locationDenied,
      MotivoSinUbicacion.sinSenal => l10n.locationNoSignal,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 6),
        action: motivo == MotivoSinUbicacion.sinSenal
            ? SnackBarAction(label: l10n.retry, onPressed: _reintentarUbicacion)
            : SnackBarAction(
                label: l10n.openSettings,
                onPressed: () => _location.abrirAjustes(motivo),
              ),
      ),
    );
  }

  Future<void> _reintentarUbicacion() async {
    final u = await _location.ubicacionActual();
    if (!mounted) return;
    if (!u.esReal) {
      _avisarSinUbicacion(u.motivo!);
      return;
    }
    setState(() => _miUbicacion = u.punto);
    _centrarEnMiUbicacion();
  }

  void _centrarEnMiUbicacion() {
    final u = _miUbicacion;
    if (u == null) {
      _reintentarUbicacion();
      return;
    }
    double z;
    try {
      z = _map.camera.zoom;
    } catch (_) {
      z = 16;
    }
    _map.move(u, z < 15 ? 16 : z);
  }

  Widget _mapa() {
    final sel = _seleccion;
    final haciaSol = (sel != null && sel.sunElevationDeg > 0)
        ? Geo.destino(sel.punto, sel.sunAzimuthDeg, 90)
        : null;

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _centro,
        initialZoom: 16,
        minZoom: 11,
        maxZoom: 19,
        onTap: (_, p) => _tapMapa(p),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) _onMapaMovido();
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.urlTemplate,
          userAgentPackageName: MapConfig.userAgent,
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        if (haciaSol != null)
          PolylineLayer(polylines: [
            Polyline(
              points: [sel!.punto, haciaSol],
              strokeWidth: 4,
              color: const Color(0xFFF2A413),
            ),
          ]),
        MarkerLayer(
          markers: [
            if (_miUbicacion != null)
              Marker(
                point: _miUbicacion!,
                width: 24,
                height: 24,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1A73E8),
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 3.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            if (_capaLocales)
              for (final r in _terrazas)
                Marker(
                  point: r.bar!.punto,
                  width: 26,
                  height: 26,
                  child: GestureDetector(
                    onTap: () => _seleccionarBar(r),
                    child: Icon(
                      Icons.local_cafe,
                      size: r.bar?.osmId == sel?.bar?.osmId ? 26 : 20,
                      color: _colorReporte(r),
                    ),
                  ),
                ),
            if (sel != null && sel.bar == null)
              Marker(
                point: sel.punto,
                width: 40,
                height: 40,
                child: Icon(Icons.place,
                    size: 40, color: Theme.of(context).colorScheme.primary),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution(MapConfig.atribucion)],
        ),
      ],
    );
  }

  Widget _panel(AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: _seleccion != null
              ? _detalle(l10n, _seleccion!)
              : _lista(l10n),
        ),
      ),
    );
  }

  Widget _lista(AppLocalizations l10n) {
    if (!_capaLocales) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(l10n.tapMapHint,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(height: 34, child: _chipsHora(l10n)),
          ),
          const SizedBox(height: 12),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.terracesNearby,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (_cargandoZona)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _leyendaConfort(l10n),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(height: 34, child: _chipsHora(l10n)),
        ),
        const SizedBox(height: 4),
        if (_demasiadoLejos)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.zoomInForTerraces),
          )
        else if (_error && _terrazas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.networkError,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          )
        else if (!_cargando && !_cargandoZona && _terrazas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.noBars),
          )
        else
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _terrazas.length,
              itemBuilder: (_, i) {
                final r = _terrazas[i];
                final vientoTxt = r.windSpeedKmh == null
                    ? null
                    : '${_labelWind(l10n, r.windStrength)} · '
                        '${l10n.windSpeed(r.windSpeedKmh!.round())}';
                return ListTile(
                  isThreeLine: true,
                  onTap: () => _seleccionarBar(r),
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: _colorReporte(r),
                  ),
                  title: Text(r.bar!.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.provisional ? l10n.computingShade : _labelStatus(l10n, r.sunStatus)}'
                        '${vientoTxt != null ? ' · $vientoTxt' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${r.temperatureC != null ? '${l10n.temperature(r.temperatureC!.round())} · ' : ''}'
                        '${_distancia(l10n, r.punto)}',
                      ),
                    ],
                  ),
                  trailing: Text(
                    r.provisional ? '…' : _labelConfort(l10n, r.comfort.level),
                    style: TextStyle(
                      color: _colorReporte(r),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _detalle(AppLocalizations l10n, PointReport r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.back,
                onPressed: () => setState(() => _seleccion = null),
              ),
              Expanded(
                child: Text(
                  r.bar?.nombre ?? l10n.thisSpot,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 30, child: _chipsHora(l10n)),
          const SizedBox(height: 10),
          if (r.provisional)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.computingShadeDetail,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          _tarjetaConfort(l10n, r),
          const SizedBox(height: 8),
          _tarjetaSolYViento(l10n, r),
          if (r.bar != null && !r.bar!.terrazaDeclarada)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.terraceNotConfirmed,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (r.ajustado)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.movedToOpenSpace,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaConfort(AppLocalizations l10n, PointReport r) {
    final color = _colorConfort(r.comfort.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headline(l10n, r.comfort.headline),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final f in r.comfort.flags)
                Chip(
                  label: Text(_flag(l10n, f),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSolYViento(AppLocalizations l10n, PointReport r) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SunBadge(status: r.sunStatus, size: 38),
                const SizedBox(width: 10),
                Text(_labelStatus(l10n, r.sunStatus),
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (r.solRestante != null &&
                    r.solRestante! > Duration.zero)
                  Text(
                    l10n.sunUntilSunset(
                        r.solRestante!.inHours, r.solRestante!.inMinutes % 60),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                WindArrow(directionDeg: r.windDirectionDeg, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.windSpeedKmh == null
                            ? l10n.noAemet
                            : _labelWind(l10n, r.windStrength),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (r.windSpeedKmh != null)
                        Text(
                          r.windDirectionCardinal != null
                              ? l10n.windSpeedFrom(r.windSpeedKmh!.round(),
                                  r.windDirectionCardinal!)
                              : l10n.windSpeed(r.windSpeedKmh!.round()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (r.windGustKmh != null)
                        Text(l10n.gusts(r.windGustKmh!.round()),
                            style: Theme.of(context).textTheme.bodySmall),
                      if (r.resguardadoPorEdificios &&
                          r.windSpeedRegionalKmh != null)
                        Text(
                          l10n.windShelteredByBuildings(
                              r.windSpeedRegionalKmh!.round()),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                if (r.temperatureC != null)
                  Text(l10n.temperature(r.temperatureC!.round()),
                      style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                r.esPrevision ? l10n.sourceForecast : l10n.sourceObservation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leyendaConfort(AppLocalizations l10n) => Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          for (final lvl in ComfortLevel.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _colorConfort(lvl),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(_labelConfort(l10n, lvl),
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
        ],
      );

  Widget _chipsHora(AppLocalizations l10n) {
    final ahora = DateTime.now();
    final futuras =
        _prevision.where((w) => w.timestamp.isAfter(ahora)).take(30).toList();
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        ChoiceChip(
          label: Text(l10n.now),
          selected: _horaSel == null,
          onSelected: (_) => _elegirHora(null),
        ),
        const SizedBox(width: 8),
        for (final w in futuras) ...[
          ChoiceChip(
            label: Text(_hhmm(w.timestamp, ahora)),
            selected: _horaSel == w.timestamp,
            onSelected: (_) => _elegirHora(w.timestamp),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  String _distancia(AppLocalizations l10n, LatLng p) {
    final m = Geo.distancia(_centro, p);
    return m < 1000
        ? l10n.distanceM(m.round())
        : l10n.distanceKm((m / 1000).toStringAsFixed(1));
  }

  String _labelStatus(AppLocalizations l10n, SunStatus s) => switch (s) {
        SunStatus.pleno => l10n.statusPleno,
        SunStatus.solConNubes => l10n.statusSolConNubes,
        SunStatus.nublado => l10n.statusNublado,
        SunStatus.sombraPorEdificios => l10n.statusSombra,
        SunStatus.noche => l10n.statusNoche,
      };

  String _labelWind(AppLocalizations l10n, WindStrength w) => switch (w) {
        WindStrength.calm => l10n.windCalm,
        WindStrength.light => l10n.windLight,
        WindStrength.breezy => l10n.windBreezy,
        WindStrength.windy => l10n.windWindy,
        WindStrength.veryWindy => l10n.windVeryWindy,
      };

  String _labelConfort(AppLocalizations l10n, ComfortLevel l) => switch (l) {
        ComfortLevel.muyAgradable => l10n.comfortVeryNice,
        ComfortLevel.agradable => l10n.comfortNice,
        ComfortLevel.justo => l10n.comfortSoSo,
        ComfortLevel.incomodo => l10n.comfortBad,
      };

  String _headline(AppLocalizations l10n, ComfortHeadline h) => switch (h) {
        ComfortHeadline.agradable => l10n.headlineNice,
        ComfortHeadline.brisaAgradable => l10n.headlineBreeze,
        ComfortHeadline.solFuerte => l10n.headlineStrongSun,
        ComfortHeadline.solAgradable => l10n.headlineSunnyCold,
        ComfortHeadline.frioViento => l10n.headlineChillyShade,
        ComfortHeadline.ventoso => l10n.headlineWindy,
        ComfortHeadline.noche => l10n.headlineNight,
      };

  String _flag(AppLocalizations l10n, ComfortFlag f) => switch (f) {
        ComfortFlag.solFuerte => l10n.flagStrongSun,
        ComfortFlag.sombra => l10n.flagShade,
        ComfortFlag.ventoso => l10n.flagWindy,
        ComfortFlag.brisa => l10n.flagBreeze,
        ComfortFlag.resguardado => l10n.flagSheltered,
      };

  static String _hhmm(DateTime t, DateTime ahora) {
    const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    final mismoDia = t.day == ahora.day && t.month == ahora.month;
    final pref = mismoDia ? '' : '${dias[t.weekday - 1]} ';
    return '$pref${t.hour}h';
  }
}
