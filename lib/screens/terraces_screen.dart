import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/locales_config.dart';
import '../config/map_config.dart';
import '../l10n/app_localizations.dart';
import '../models/bar.dart';
import '../models/ciutat.dart';
import '../models/comfort.dart';
import '../models/geo.dart';
import '../models/indice_espacial.dart';
import '../models/point_report.dart';
import '../models/recomanat.dart';
import '../models/shadow_map.dart';
import '../models/sun_status.dart';
import '../models/terraza_puntos.dart';
import '../models/weather_conditions.dart';
import '../services/weather_service.dart';
import 'about_screen.dart';
import '../services/locale_controller.dart';
import '../services/location_service.dart';
import '../services/osm_area_service.dart';
import '../services/recomanats_service.dart';
import '../services/shadow_service.dart';
import '../services/sun_service.dart';
import '../services/wind_shelter_service.dart';
import '../widgets/ciutats_lista.dart';
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

  /// Se completa cuando el mapa se ha dibujado por primera vez. Antes de eso
  /// el [MapController] lanza si se usa (pasaba cuando la ubicación respondía
  /// al instante, p. ej. con el permiso denegado).
  final _mapaListo = Completer<void>();
  final _location = const LocationService();
  final _osm = OsmAreaService();
  final _recomanatsSrv = RecomanatsService();
  final _ciutatsSrv = CiutatsService();

  /// Ciudades con datos propios (para el aviso fuera de cobertura y para
  /// saber dónde se vende "Recomanat").
  List<Ciutat> _ciutats = const [];
  bool _avisoCoberturaMostrado = false;

  /// Locales recomendados vigentes, por osmId. Solo cambian cómo se enseña
  /// el local, nunca el cálculo de sol, sombra o viento.
  Map<String, Recomanat> _recomanats = const {};
  final _sun = const SunService();
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
  IndiceEdificios _indiceEdif = IndiceEdificios.vacio;
  IndiceSegmentos _indiceVias = IndiceSegmentos.vacio;

  /// Sombras de cada tesela para el tramo de 5 min [_tramoSombras]. Se
  /// calculan fuera del hilo de la interfaz y valen mientras no cambien el
  /// tramo ni la tesela (sus edificios).
  final Map<Tesela, ShadowMap> _sombras = {};
  DateTime? _tramoSombras;
  bool _calculandoSombras = false;
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

  /// Solo locales con `outdoor_seating` confirmado (por defecto se ven
  /// también los que no tienen la etiqueta, en un estilo más discreto).
  bool _soloConfirmadas = false;
  static const _kSoloConfirmadas = 'solo_confirmadas';

  /// Solo locales recomendados (apagado por defecto).
  bool _soloRecomanats = false;
  static const _kSoloRecomanats = 'solo_recomanats';

  bool _cargando = true; // carga inicial (overlay)
  bool _cargandoZona = false; // descarga incremental al mover el mapa
  bool _error = false;
  bool _demasiadoLejos = false; // zoom muy alejado

  Timer? _debounce;

  static const _diagMaxVisibleM = 2200.0;

  /// Teselas por petición a Overpass (las más cercanas al centro primero).
  static const _teselasPorPeticion = 4;

  /// La primera petición, más pequeña: lo más cercano llega antes.
  static const _teselasPrimerLote = 2;

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
      setState(() {
        _capaLocales = sp.getBool(_kCapaLocales) ?? true;
        _soloConfirmadas = sp.getBool(_kSoloConfirmadas) ?? false;
        _soloRecomanats = sp.getBool(_kSoloRecomanats) ?? false;
      });
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

  Future<void> _toggleSoloConfirmadas() async {
    setState(() => _soloConfirmadas = !_soloConfirmadas);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSoloConfirmadas, _soloConfirmadas);
    _recalcularVisible();
  }

  Future<void> _toggleSoloRecomanats() async {
    setState(() => _soloRecomanats = !_soloRecomanats);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSoloRecomanats, _soloRecomanats);
    _recalcularVisible();
  }

  Recomanat? _rec(Bar? b) {
    final r = b == null ? null : _recomanats[b.osmId];
    return r != null && r.activoEn(DateTime.now()) ? r : null;
  }

  Future<void> _cargarRecomanats() async {
    final r = await _recomanatsSrv.cargar();
    if (!mounted) return;
    _recomanats = r;
    _recalcularVisible();
  }

  Future<void> _cargarCiutats() async {
    final c = await _ciutatsSrv.cargar();
    if (!mounted) return;
    setState(() => _ciutats = c);
    _quizaAvisarCobertura(_centro);
  }

  /// Una vez por sesión: si el usuario está fuera de las ciudades con datos
  /// propios, se lo decimos con la lista (allí funciona mejor).
  void _quizaAvisarCobertura(LatLng p) {
    if (_avisoCoberturaMostrado || _ciutats.isEmpty) return;
    if (_ciutats.any((c) => c.conte(p))) return;
    _avisoCoberturaMostrado = true;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      content: Text(l10n.outsideCoverage),
      action: SnackBarAction(label: l10n.seeCities, onPressed: _mostrarCiutats),
    ));
  }

  void _mostrarCiutats() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.availableCities,
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(l10n.availableCitiesIntro,
                  style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 10),
              CiutatsLista(_ciutats),
            ],
          ),
        ),
      ),
    );
  }

  /// Si en el sitio del local se vende "Aparecer como recomendado".
  bool _seVendeEn(LatLng p) =>
      _ciutats.any((c) => c.vendaRecomanats && c.conte(p));

  /// Si el local se enseña a la hora [hora]: nunca los que dicen no tener
  /// terraza; los sin confirmar según el interruptor; y no los que su
  /// horario dice cerrados a esa hora (sin horario, o si no se entiende, sí
  /// se enseñan).
  bool _seMuestra(Bar b, DateTime hora) {
    if (b.terraza == Terraza.no) return false;
    if (_soloConfirmadas && b.terraza != Terraza.confirmada) return false;
    if (_soloRecomanats && _rec(b) == null) return false;
    return b.abiertoEn(hora) != false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _osm.dispose();
    _recomanatsSrv.dispose();
    _ciutatsSrv.dispose();
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
    await _mapaListo.future;
    if (!mounted) return;
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

    // El tiempo, los recomendados y los edificios llegan cada uno por su
    // lado y recalculan.
    unawaited(_cargarTiempo());
    unawaited(_cargarRecomanats());
    unawaited(_cargarCiutats());
    await _refrescarPorVista();
  }



  Future<void> _cargarTiempo() async {
    try {
      // Puede llegar dos veces: Open-Meteo enseguida y AEMET después.
      await for (final t in _tiempo.condicionesYPrevisionEnVivo(_centro)) {
        _ahora = t.ahora;
        _prevision = t.prevision;
        if (mounted) _recalcularVisible();
      }
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

    // Margen de ~110 m: las sombras de edificios justo fuera de la vista
    // también cuentan.
    const m = 0.001;
    final faltan = Tesela.cubriendo(bounds.south - m, bounds.west - m,
            bounds.north + m, bounds.east + m)
        .where((t) => !_teselas.containsKey(t))
        .toList()
      ..sort((a, b) => Geo.distancia(centro, a.centro)
          .compareTo(Geo.distancia(centro, b.centro)));
    if (faltan.isEmpty) {
      if (_error) setState(() => _error = false); // no falta nada
      unawaited(_asegurarCiudad(centro, bounds));
      _quizaAvisarCobertura(centro);
      return;
    }

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
      // Los edificios tienen prioridad: nunca a la vez que la ciudad.
      if (porBajar.isNotEmpty) _osm.cancelarRegion();
      if (porBajar.isEmpty) _error = false;
      // Si el usuario se mueve, se corta: primero lo nuevo.
      var k = 0;
      while (k < porBajar.length && !_pendiente) {
        final n = k == 0 ? _teselasPrimerLote : _teselasPorPeticion;
        final lote = porBajar.sublist(k, math.min(k + n, porBajar.length));
        k += lote.length;
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
    } else if (mounted) {
      // Con los edificios ya pedidos, Overpass queda libre para la ciudad.
      unawaited(_asegurarCiudad(centro, bounds));
      _quizaAvisarCobertura(centro);
    }
  }

  /// Rehace las listas de contexto a partir de las teselas en memoria y
  /// descarta las más lejanas si hay demasiadas (memoria acotada).
  /// Puntos de la terraza de cada local: dependen solo de los edificios, así
  /// que se calculan una vez y se guardan hasta que cambian los edificios.
  final _terrazasCache = <String, PuntosTerraza?>{};

  PuntosTerraza? _puntosTerraza(Bar b) => _terrazasCache.putIfAbsent(
      b.osmId, () => PuntosTerraza.de(b.punto, _indiceEdif));

  void _rehacerContexto(LatLng cerca) {
    _terrazasCache.clear();
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
    _indiceEdif = IndiceEdificios(
        [for (final z in _teselas.values) ...z.edificios]);
    _indiceVias = IndiceSegmentos(
        [for (final z in _teselas.values) ...z.lineasPublicas]);
    _sombras.removeWhere((t, _) => !_teselas.containsKey(t));
    for (final z in _teselas.values) {
      for (final b in z.bares) {
        _baresPorId[b.osmId] = b;
      }
    }
  }

  /// Descarga en segundo plano todos los locales de la ciudad (región de
  /// ~11 km) en la que está [p], una sola vez: queda guardada 30 días y a
  /// partir de ahí sus locales salen al instante, como los de Barcelona.
  ///
  /// No hace nada si los locales empaquetados ya cubren la [vista] con
  /// ~1 km de margen (Barcelona), si la cubren los datos propios (llegan
  /// con las cuadrículas), ni mientras se descargan edificios.
  Future<void> _asegurarCiudad(LatLng p, LatLngBounds vista) async {
    const margen = 0.01; // ~1 km
    final s = vista.south - margen, w = vista.west - margen;
    final n = vista.north + margen, e = vista.east + margen;
    if (_descargando || _empaquetados.cubreZona(s, w, n, e)) return;
    if (await _osm.datosPropiosCubren(s, w, n, e)) return;
    if (_descargando || !mounted) return;
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

  /// La tesela de [p] tiene edificios y sus sombras ya calculadas.
  bool _contextoListo(LatLng p) {
    final t = Tesela.de(p);
    return _teselas.containsKey(t) && _sombras.containsKey(t);
  }

  // --- Sombras por tesela -------------------------------------------

  /// Tramo de 5 minutos de [h]: mientras no cambie, las sombras valen.
  static DateTime _tramo(DateTime h) =>
      DateTime(h.year, h.month, h.day, h.hour, h.minute - h.minute % 5);

  /// Pone en marcha el cálculo de las sombras que falten para la vista y un
  /// anillo de teselas alrededor (sus sombras pueden entrar en la vista).
  void _asegurarSombras(LatLngBounds vista, DateTime hora) {
    final tramo = _tramo(hora);
    if (tramo != _tramoSombras) {
      _sombras.clear();
      _tramoSombras = tramo;
    }
    if (_calculandoSombras) return;
    final faltan = Tesela.cubriendo(
            vista.south - Tesela.tamLat,
            vista.west - Tesela.tamLon,
            vista.north + Tesela.tamLat,
            vista.east + Tesela.tamLon)
        .where((t) => _teselas.containsKey(t) && !_sombras.containsKey(t))
        .toList();
    if (faltan.isNotEmpty) unawaited(_calcularSombras(faltan, tramo));
  }

  Future<void> _calcularSombras(List<Tesela> ts, DateTime tramo) async {
    _calculandoSombras = true;
    try {
      // A mitad del tramo: el error máximo es de 2,5 min de sol.
      final mapas = await _sombrasEnIsolate(
          [for (final t in ts) _teselas[t]!.sombras],
          ts.first.centro,
          tramo.add(const Duration(seconds: 150)));
      _calculandoSombras = false;
      if (tramo == _tramoSombras) {
        for (var k = 0; k < ts.length; k++) {
          if (_teselas.containsKey(ts[k])) _sombras[ts[k]] = mapas[k];
        }
      }
      if (mounted) _recalcularVisible();
    } catch (e) {
      // Sin recalcular: evita repetir el error en bucle.
      debugPrint('[sombras] no se pudieron calcular: $e');
    } finally {
      _calculandoSombras = false;
    }
  }

  /// Estática a propósito: el cierre que viaja al isolate solo lleva los
  /// edificios (un método de instancia arrastraría toda la pantalla).
  static Future<List<ShadowMap>> _sombrasEnIsolate(
          List<List<BuildingFootprint>> porTesela,
          LatLng ref,
          DateTime instante) =>
      Isolate.run(() => [
            for (final eds in porTesela)
              const ShadowService().construir(eds, ref, instante),
          ]);

  /// ¿Cae [p] en la sombra de algún edificio? Mira su tesela y las 8 vecinas:
  /// una sombra no pasa de 400 m y una tesela mide ~550 m.
  bool _enSombra(LatLng p) {
    final t = Tesela.de(p);
    for (var di = -1; di <= 1; di++) {
      for (var dj = -1; dj <= 1; dj++) {
        if (_sombras[Tesela(t.i + di, t.j + dj)]?.enSombra(p) ?? false) {
          return true;
        }
      }
    }
    return false;
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

    // Las sombras que falten se calculan aparte y, al llegar, se recalcula.
    _asegurarSombras(bounds, hora);

    // El sol es casi el mismo en toda la vista: se calcula una sola vez.
    final pos = _sun.posicion(centroV, hora);
    final ocaso = _sun.ocaso(centroV, hora);

    // Con la capa de locales apagada no se evalúan las terrazas (ahorra el
    // grueso del cálculo); la app queda como "toca un punto".
    final reports = <PointReport>[];
    if (_capaLocales) {
      var visibles = _baresPorId.values
          .where((b) => bounds.contains(b.punto) && _seMuestra(b, hora))
          .toList();
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
            pos: pos,
            ocaso: ocaso));
      }
      reports.sort((a, b) {
        // Los aún no tienen la sombra calculada, al final.
        if (a.provisional != b.provisional) return a.provisional ? 1 : -1;
        var c = a.comfort.level.index.compareTo(b.comfort.level.index);
        if (c != 0) return c;
        // A igual confort, primero los recomendados (solo el orden: el
        // confort se calcula igual para todos) y luego las terrazas
        // confirmadas.
        final ra = _rec(a.bar) != null, rb = _rec(b.bar) != null;
        if (ra != rb) return ra ? -1 : 1;
        final ca = a.bar?.terrazaDeclarada ?? false;
        final cb = b.bar?.terrazaDeclarada ?? false;
        if (ca != cb) return ca ? -1 : 1;
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
    required SunPosition pos,
    required DateTime ocaso,
  }) {
    // Un local: varios puntos delante de su fachada (donde estarán las
    // mesas). Un punto libre del mapa: ese punto (o la vía pública más
    // cercana si cae dentro de un edificio).
    final terraza = bar == null ? null : _puntosTerraza(bar);
    final LatLng punto;
    final bool ajustado;
    if (terraza != null) {
      punto = terraza.centro;
      ajustado = true;
    } else {
      final ajustado0 =
          OsmAreaService.ajustarConIndices(punto0, _indiceEdif, _indiceVias);
      punto = ajustado0 ?? punto0;
      ajustado = ajustado0 != null && !identical(ajustado0, punto0);
    }

    // El sol se calcula una vez por recálculo (misma vista ≈ misma posición).
    final esDia = pos.elevationDeg > 0;
    final double? fraccionSombra;
    final bool tapado;
    if (terraza != null && esDia) {
      var n = 0;
      for (final q in terraza.puntos) {
        if (_enSombra(q)) n++;
      }
      fraccionSombra = n / terraza.puntos.length;
      tapado = false;
    } else {
      fraccionSombra = null;
      tapado = esDia && _enSombra(punto);
    }

    final w = _tiempoPara(hora);
    final cloud = w?.sky.cloudFraction;
    final status = combinarSunStatus(
      fraccionEnSombra: fraccionSombra,
      esDeDia: esDia,
      tapadoPorEdificio: tapado,
      cloudFraction: cloud,
    );

    // Viento local: el pronóstico regional, descontado el resguardo que dan
    // los edificios a barlovento.
    final vientoReg = w?.windSpeedKmh;
    final abrigo = vientoReg == null
        ? 0.0
        : _viento.abrigoConIndice(
            punto, _indiceEdif, w?.windDirectionDeg?.toDouble());
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
    setState(() => _seleccion = _evaluar(p,
        provisional: !_contextoListo(p),
        hora: hora,
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

  Widget _avisoSinEdificios(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l10n.buildingsUnavailable,
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
          ),
          TextButton(
            onPressed: _cargandoZona ? null : () => unawaited(_refrescarPorVista()),
            child: Text(l10n.retry),
          ),
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
        onMapReady: () {
          if (!_mapaListo.isCompleted) _mapaListo.complete();
        },
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
          tileProvider: MapConfig.proveedorTeselas(),
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
                    // Recomendado: más grande y con estrella. Terraza sin
                    // confirmar: icono hueco y algo más pequeño.
                    child: _rec(r.bar) != null
                        ? _iconoRecomanat(_colorReporte(r),
                            seleccionado: r.bar?.osmId == sel?.bar?.osmId)
                        : Icon(
                      r.bar!.terrazaDeclarada
                          ? Icons.local_cafe
                          : Icons.local_cafe_outlined,
                      size: r.bar?.osmId == sel?.bar?.osmId
                          ? 26
                          : r.bar!.terrazaDeclarada
                              ? 20
                              : 17,
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
        ?MapConfig.logoProveedor(),
        // Siempre visible, como pide OpenStreetMap (y el proveedor del mapa).
        Align(
          alignment: Alignment.bottomRight,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              color: const Color(0xB3FFFFFF),
              child: Text(
                [
                  if (MapConfig.atribucionTeselas.isNotEmpty)
                    MapConfig.atribucionTeselas,
                  AppLocalizations.of(context).osmAttribution,
                ].join(' · '),
                style: const TextStyle(fontSize: 10, color: Color(0xDD000000)),
              ),
            ),
          ),
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
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    label: Text(l10n.onlyConfirmedTerraces),
                    selected: _soloConfirmadas,
                    onSelected: (_) => _toggleSoloConfirmadas(),
                    visualDensity: VisualDensity.compact,
                    labelStyle: Theme.of(context).textTheme.labelSmall,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.star, size: 14, color: _colorRecomanat),
                    label: Text(l10n.onlyRecommended),
                    selected: _soloRecomanats,
                    onSelected: (_) => _toggleSoloRecomanats(),
                    visualDensity: VisualDensity.compact,
                    labelStyle: Theme.of(context).textTheme.labelSmall,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _leyendaConfort(l10n),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(height: 34, child: _chipsHora(l10n)),
        ),
        const SizedBox(height: 4),
        // Overpass no ha respondido: se ve lo que hay (caché y locales en
        // gris) y un aviso fijo, que no se pierde detrás de otra ventana.
        if (_error && !_demasiadoLejos && _terrazas.isNotEmpty)
          _avisoSinEdificios(l10n),
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
        else if (!_cargando && _soloRecomanats && _terrazas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.noRecommendedHere),
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
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(r.bar!.nombre,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (_rec(r.bar) != null) ...[
                        const SizedBox(width: 6),
                        _etiquetaRecomanat(l10n),
                      ],
                    ],
                  ),
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
                        '${_distancia(l10n, r.punto)}'
                        '${r.bar!.terrazaDeclarada ? '' : ' · ${l10n.terraceUnconfirmedShort}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          if (_rec(r.bar) case final rec?) _cabeceraRecomanat(l10n, rec),
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
          if (r.bar != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  r.bar!.horario == null
                      ? l10n.hoursUnavailable
                      : l10n.hoursTerraceCaveat,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (r.ajustado)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.movedToOpenSpace,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (r.bar != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _avisarError(r.bar!),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(l10n.reportError),
              ),
            ),
          if (r.bar != null) _pieDueno(l10n, r.bar!),
        ],
      ),
    );
  }

  // --- Recomendados -------------------------------------------------

  static const _colorRecomanat = Color(0xFFD81B60);

  Widget _iconoRecomanat(Color color, {required bool seleccionado}) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.local_cafe, size: seleccionado ? 28 : 24, color: color),
          const Positioned(
            right: -4,
            top: -4,
            child: Icon(Icons.star, size: 13, color: _colorRecomanat),
          ),
        ],
      );

  Widget _etiquetaRecomanat(AppLocalizations l10n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: _colorRecomanat,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 11, color: Colors.white),
            const SizedBox(width: 3),
            Text(l10n.recommended,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  /// Etiqueta, aviso de que es de pago, foto y texto propio del local.
  Widget _cabeceraRecomanat(AppLocalizations l10n, Recomanat rec) {
    final t = Theme.of(context).textTheme;
    final texto = rec.texto(Localizations.localeOf(context).languageCode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiquetaRecomanat(l10n),
          const SizedBox(height: 4),
          Text(l10n.recommendedDisclosure, style: t.bodySmall),
          if (rec.foto != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(rec.foto!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ],
          if (texto != null) ...[
            const SizedBox(height: 8),
            Text(texto, style: t.bodyMedium),
          ],
        ],
      ),
    );
  }

  /// "¿Es tu local?": aparecer como recomendado (se paga en la web, fuera de la app)
  /// o reclamarlo gratis por correo. La app solo abre el navegador o el
  /// correo: no hay pagos dentro de la app.
  Widget _pieDueno(AppLocalizations l10n, Bar bar) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(l10n.ownerTitle, style: t.titleSmall),
          if (_rec(bar) == null && _seVendeEn(bar.punto))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.star_outline, color: _colorRecomanat),
              title: Text(l10n.ownerRecommend),
              // Ni precio ni pago en la app: abre la página de la web.
              onTap: () => _abrir(LocalesConfig.paginaLocales(
                  Localizations.localeOf(context).languageCode)),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l10n.ownerClaim),
            subtitle: Text(l10n.ownerClaimDetail),
            onTap: () => _abrir(Uri.parse('mailto:${LocalesConfig.correo}'
                '?subject=${Uri.encodeComponent(l10n.ownerClaimSubject(bar.nombre))}'
                '&body=${Uri.encodeComponent(l10n.ownerClaimBody(bar.nombre, 'https://www.openstreetmap.org/${bar.osmId}'))}')),
          ),
        ],
      ),
    );
  }

  Future<void> _abrir(Uri destino) async {
    var ok = false;
    try {
      ok = await launchUrl(destino, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotOpen)));
    }
  }

  /// "Avisar de un error": nota pública en OpenStreetMap o correo a Lat41
  /// Lab. La app solo abre el navegador o el correo; no envía nada.
  Future<void> _avisarError(Bar bar) async {
    final l10n = AppLocalizations.of(context);
    final lat = bar.punto.latitude.toStringAsFixed(6);
    final lon = bar.punto.longitude.toStringAsFixed(6);
    final enOsm = 'https://www.openstreetmap.org/${bar.osmId}';
    final destino = await showModalBottomSheet<Uri>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l10n.reportOsm),
              subtitle: Text(l10n.reportOsmDetail),
              onTap: () => Navigator.pop(
                  ctx,
                  Uri.https('www.openstreetmap.org', '/note/new',
                          {'lat': lat, 'lon': lon})
                      .replace(fragment: 'map=19/$lat/$lon')),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.reportEmail),
              subtitle: const Text('hola@lat41lab.com'),
              onTap: () => Navigator.pop(
                  ctx,
                  Uri.parse('mailto:hola@lat41lab.com'
                      '?subject=${Uri.encodeComponent(l10n.reportEmailSubject(bar.nombre))}'
                      '&body=${Uri.encodeComponent(l10n.reportEmailBody(bar.nombre, enOsm))}')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (destino == null) return;
    var ok = false;
    try {
      ok = await launchUrl(destino, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.couldNotOpen)));
    }
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
        SunStatus.solParcial => l10n.statusSolParcial,
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
