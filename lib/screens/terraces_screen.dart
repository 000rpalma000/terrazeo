import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';
import '../l10n/app_localizations.dart';
import '../models/bar.dart';
import '../models/comfort.dart';
import '../models/geo.dart';
import '../models/point_report.dart';
import '../models/shadow_map.dart';
import '../models/sun_status.dart';
import '../models/weather_conditions.dart';
import '../services/aemet_service.dart';
import 'about_screen.dart';
import '../services/locale_controller.dart';
import '../services/location_service.dart';
import '../services/osm_area_service.dart';
import '../services/ads_service.dart';
import '../services/search_gate.dart';
import '../services/shadow_service.dart';
import '../services/sun_service.dart';
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
  final _aemet = AemetService();

  LatLng _centro = LocationService.fallback;

  // Datos acumulados de todas las áreas descargadas.
  final Map<String, Bar> _baresPorId = {};
  final List<BuildingFootprint> _edificios = [];
  final List<List<LatLng>> _lineas = [];
  final Set<String> _edifKeys = {};
  final Set<String> _lineaKeys = {};
  final List<({LatLng c, double r})> _areasDescargadas = [];
  bool _descargando = false;

  WeatherConditions? _ahora;
  List<WeatherConditions> _prevision = const [];

  DateTime? _horaSel; // null = ahora
  List<PointReport> _terrazas = const [];
  PointReport? _seleccion; // detalle abierto (bar o punto libre)

  bool _cargando = true; // carga inicial (overlay)
  bool _cargandoZona = false; // descarga incremental al mover el mapa
  bool _error = false;
  bool _demasiadoLejos = false; // zoom muy alejado

  Timer? _debounce;

  static const _radioMaxM = 900.0;
  static const _diagMaxVisibleM = 2200.0;

  @override
  void initState() {
    super.initState();
    AdsService.instancia.inicializar();
    _arrancar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _osm.dispose();
    _aemet.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _arrancar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final u = await _location.ubicacionActual();
      _centro = u.punto;
      _map.move(_centro, 16);

      final res = await Future.wait([
        _aemet.condicionesActuales().catchError((_) => null),
        _aemet.previsionHoraria().catchError((_) => <WeatherConditions>[]),
      ]);
      _ahora = res[0] as WeatherConditions?;
      _prevision = res[1] as List<WeatherConditions>;

      await _asegurarCobertura(_centro, 420);
      _recalcularVisible();

      // Monetización: cada N búsquedas (abrir/actualizar) toca anuncio.
      if (await SearchGate().registrarBusqueda()) {
        await AdsService.instancia.mostrarSiListo();
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- Descarga por áreas + fusión -----------------------------------

  void _onMapaMovido() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _refrescarPorVista);
  }

  Future<void> _refrescarPorVista() async {
    if (!mounted || _descargando) return;
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

    final radio = ((diag / 2) + 200).clamp(380.0, _radioMaxM).toDouble();
    if (!_cubierto(bounds, 50)) {
      await _asegurarCobertura(centro, radio);
    }
    _recalcularVisible();
  }

  bool _cubierto(LatLngBounds b, double margenM) {
    final esquinas = [
      b.northWest,
      b.northEast,
      b.southWest,
      b.southEast,
      b.center,
    ];
    return esquinas.every((p) => _areasDescargadas
        .any((a) => Geo.distancia(a.c, p) <= a.r - margenM));
  }

  Future<void> _asegurarCobertura(LatLng centro, double radio) async {
    if (_descargando) return;
    _descargando = true;
    // Snap para que áreas casi iguales compartan caché.
    final rSnap = ((radio / 100).round() * 100).clamp(380, 900);
    setState(() => _cargandoZona = true);
    try {
      final z = await _osm.cargarZona(
        centro,
        radioBaresM: rSnap,
        radioContextoM: rSnap + 120,
      );
      _fusionar(z);
      _areasDescargadas.add((c: centro, r: rSnap.toDouble()));
      _podar(centro);
      _error = false;
    } catch (_) {
      _error = true;
    } finally {
      _descargando = false;
      if (mounted) setState(() => _cargandoZona = false);
    }
  }

  void _fusionar(ZonaOsm z) {
    for (final b in z.bares) {
      _baresPorId[b.osmId] = b;
    }
    for (final e in z.edificios) {
      final p = e.ring.first;
      final k = '${(p.latitude * 1e5).round()}_${(p.longitude * 1e5).round()}';
      if (_edifKeys.add(k)) _edificios.add(e);
    }
    for (final l in z.lineasPublicas) {
      final a = l.first, b = l.last;
      final k = '${(a.latitude * 1e5).round()}_${(a.longitude * 1e5).round()}'
          '_${(b.latitude * 1e5).round()}_${(b.longitude * 1e5).round()}'
          '_${l.length}';
      if (_lineaKeys.add(k)) _lineas.add(l);
    }
  }

  /// Evita que la memoria crezca sin fin tras pasear por media ciudad.
  /// Ordena por distancia del primer vértice al punto (aprox., barato).
  void _podar(LatLng cerca) {
    if (_edificios.length > 5000) {
      _edificios.sort((a, b) => Geo.distancia(cerca, a.ring.first)
          .compareTo(Geo.distancia(cerca, b.ring.first)));
      _edificios.removeRange(3500, _edificios.length);
      _edifKeys.clear();
      for (final e in _edificios) {
        final p = e.ring.first;
        _edifKeys
            .add('${(p.latitude * 1e5).round()}_${(p.longitude * 1e5).round()}');
      }
    }
    if (_lineas.length > 6000) {
      _lineas.sort((a, b) => Geo.distancia(cerca, a.first)
          .compareTo(Geo.distancia(cerca, b.first)));
      _lineas.removeRange(4000, _lineas.length);
      _lineaKeys.clear();
      for (final l in _lineas) {
        final a = l.first, b = l.last;
        _lineaKeys.add(
            '${(a.latitude * 1e5).round()}_${(a.longitude * 1e5).round()}'
            '_${(b.latitude * 1e5).round()}_${(b.longitude * 1e5).round()}'
            '_${l.length}');
      }
    }
    if (_baresPorId.length > 2500) {
      final orden = _baresPorId.values.toList()
        ..sort((a, b) => Geo.distancia(cerca, a.punto)
            .compareTo(Geo.distancia(cerca, b.punto)));
      _baresPorId
        ..clear()
        ..addEntries(orden.take(1800).map((b) => MapEntry(b.osmId, b)));
    }
  }

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

    var visibles =
        _baresPorId.values.where((b) => bounds.contains(b.punto)).toList();
    if (visibles.length > _maxTerrazas) {
      visibles.sort((a, b) => Geo.distancia(centroV, a.punto)
          .compareTo(Geo.distancia(centroV, b.punto)));
      visibles = visibles.sublist(0, _maxTerrazas);
    }

    final reports = [
      for (final b in visibles)
        _evaluar(b.punto,
            bar: b,
            hora: hora,
            shadow: shadow,
            edificios: edifCerca,
            lineas: lineasCerca,
            pos: pos,
            ocaso: ocaso),
    ];
    reports.sort((a, b) {
      var c = a.comfort.level.index.compareTo(b.comfort.level.index);
      if (c != 0) return c;
      c = (a.bar?.prioridadTipo ?? 2).compareTo(b.bar?.prioridadTipo ?? 2);
      if (c != 0) return c;
      return Geo.distancia(centroV, a.punto)
          .compareTo(Geo.distancia(centroV, b.punto));
    });

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
    final comfort = evaluarConfort(
      sunStatus: status,
      windKmh: w?.windSpeedKmh,
      tempC: w?.temperatureC,
      instante: hora,
      latitud: punto.latitude,
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
      windSpeedKmh: w?.windSpeedKmh,
      windGustKmh: w?.windGustKmh,
      windDirectionDeg: w?.windDirectionDeg,
      windDirectionCardinal: w?.windDirectionCardinal,
      temperatureC: w?.temperatureC,
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
    if (_edificios.isEmpty && _lineas.isEmpty) return;
    final hora = _horaSel ?? DateTime.now();
    final edifCerca =
        _edificios.where((e) => Geo.distancia(p, e.ring.first) < 400).toList();
    final lineasCerca =
        _lineas.where((l) => Geo.distancia(p, l.first) < 400).toList();
    final shadow = _shadow.construir(edifCerca, p, hora);
    setState(() => _seleccion = _evaluar(p,
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
                    color: _colorConfort(r.comfort.level),
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
                    backgroundColor: _colorConfort(r.comfort.level),
                  ),
                  title: Text(r.bar!.nombre,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_labelStatus(l10n, r.sunStatus)}'
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
                    _labelConfort(l10n, r.comfort.level),
                    style: TextStyle(
                      color: _colorConfort(r.comfort.level),
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
