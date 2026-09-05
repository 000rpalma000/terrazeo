import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Anuncios intersticiales (AdMob), ligados al ritmo que marca [SearchGate].
///
/// Usa los **IDs de prueba publicados por Google** — funcionan sin cuenta de
/// AdMob y muestran un anuncio de prueba real. Antes de publicar hay que:
///  1. Crear una cuenta gratis en https://admob.google.com
///  2. Registrar la app y crear un bloque de anuncio intersticial.
///  3. Sustituir las constantes de abajo (y el ID de la app en
///     AndroidManifest.xml / Info.plist) por los propios.
class AdsService {
  AdsService._();
  static final AdsService instancia = AdsService._();

  static const _idIntersticialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _idIntersticialIos = 'ca-app-pub-3940256099942544/4411468910';

  static String get _idIntersticial => defaultTargetPlatform == TargetPlatform.iOS
      ? _idIntersticialIos
      : _idIntersticialAndroid;

  bool _inicializado = false;
  InterstitialAd? _anuncio;
  bool _cargando = false;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    try {
      await MobileAds.instance.initialize();
      _precargar();
    } catch (e) {
      debugPrint('[ads] no se pudo inicializar AdMob: $e');
    }
  }

  void _precargar() {
    if (_cargando || _anuncio != null) return;
    _cargando = true;
    InterstitialAd.load(
      adUnitId: _idIntersticial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _anuncio = ad;
          _cargando = false;
        },
        onAdFailedToLoad: (error) {
          _cargando = false;
          debugPrint('[ads] no se pudo cargar el anuncio: $error');
        },
      ),
    );
  }

  /// Muestra el anuncio si ya está listo y espera a que el usuario lo cierre.
  /// Devuelve `true` si se llegó a mostrar (y ya se ha cerrado), `false` si no
  /// había ninguno disponible. Nunca bloquea el uso de la app.
  Future<bool> mostrarSiListo() async {
    final ad = _anuncio;
    if (ad == null) {
      _precargar();
      return false;
    }
    _anuncio = null;
    final cerrado = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _precargar();
        if (!cerrado.isCompleted) cerrado.complete();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _precargar();
        if (!cerrado.isCompleted) cerrado.complete();
      },
    );
    try {
      await ad.show();
      await cerrado.future;
      return true;
    } catch (e) {
      debugPrint('[ads] no se pudo mostrar el anuncio: $e');
      _precargar();
      return false;
    }
  }
}
