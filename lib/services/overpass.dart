import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Ningún servidor de Overpass ha podido responder (todos ocupados, caídos o
/// sin respuesta a tiempo). La app debe enseñar lo que tenga y avisar.
class OverpassNoDisponible implements Exception {
  OverpassNoDisponible(this.errores);
  final List<String> errores;

  /// Al menos un servidor dijo explícitamente que estaba saturado.
  bool get saturado => errores.any((e) => e.contains('ocupado'));

  @override
  String toString() => 'Overpass no disponible: ${errores.join(' | ')}';
}

/// Cliente de los servidores públicos de Overpass, educado con ellos:
///
///  * Pregunta a un servidor cada vez. Si tarda más de [relevo], lanza la
///    misma consulta en el siguiente (sin cortar la primera): gana la primera
///    respuesta buena.
///  * Si un servidor dice que está lleno (429, 502, 503, 504 o "at
///    capacity"), se reintenta en otro tras esperar [esperas] (2, 4 y 8 s),
///    y nunca antes de lo que pida su cabecera `Retry-After`.
///  * Cada petición espera como mucho [limitePorServidor] y el conjunto como
///    mucho [limiteTotal]. Después lanza [OverpassNoDisponible].
class Overpass {
  Overpass(
    this._client, {
    required this.userAgent,
    this.servidores = porDefecto,
    this.limitePorServidor = const Duration(seconds: 25),
    this.limiteTotal = const Duration(seconds: 45),
    this.relevo = const Duration(seconds: 6),
    this.esperas = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
  });

  static const porDefecto = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  final http.Client _client;
  final String userAgent;
  final List<String> servidores;
  final Duration limitePorServidor;
  final Duration limiteTotal;
  final Duration relevo;
  final List<Duration> esperas;

  /// Cuándo se puede volver a preguntar a cada servidor (por `Retry-After`).
  /// Se recuerda entre consultas.
  final Map<String, DateTime> _noAntesDe = {};

  /// Lanza [query] y devuelve el cuerpo de la primera respuesta 200.
  /// [cliente] sustituye al de por defecto (para poder cortarla cerrándolo).
  Future<String> consultar(String query,
      {http.Client? cliente, Duration? limite, Duration? total}) {
    final cli = cliente ?? _client;
    final porServidor = limite ?? limitePorServidor;
    final limiteConjunto = total ?? limiteTotal;
    final maxIntentos = 1 + esperas.length;
    final completer = Completer<String>();
    final errores = <String>[];
    var intentos = 0, enCurso = 0, fallos = 0;
    Timer? siguiente;
    late final Timer reloj;

    void acabarSiNoQueda() {
      if (completer.isCompleted) return;
      if (intentos >= maxIntentos && enCurso == 0) {
        siguiente?.cancel();
        reloj.cancel();
        completer.completeError(OverpassNoDisponible(errores));
      }
    }

    void lanzar() {
      if (completer.isCompleted || intentos >= maxIntentos) return;
      // El siguiente servidor de la rueda que no haya pedido esperar más.
      final ahora = DateTime.now();
      String? srv;
      for (var k = 0; k < servidores.length; k++) {
        final s = servidores[(intentos + k) % servidores.length];
        final na = _noAntesDe[s];
        if (na == null || !na.isAfter(ahora)) {
          srv = s;
          break;
        }
      }
      if (srv == null) {
        // Todos han pedido esperar: se espera al primero que quede libre.
        final libre = _noAntesDe.values.reduce((a, b) => a.isBefore(b) ? a : b);
        siguiente?.cancel();
        siguiente = Timer(libre.difference(ahora), lanzar);
        return;
      }
      intentos++;
      enCurso++;
      final servidor = srv;
      final host = Uri.parse(servidor).host;
      // Si este tarda, se prueba otro sin cortarlo.
      siguiente?.cancel();
      siguiente = Timer(relevo, lanzar);

      void fallo(String motivo, {Duration? retryAfter}) {
        enCurso--;
        errores.add('$host: $motivo');
        if (completer.isCompleted) return;
        if (retryAfter != null) {
          _noAntesDe[servidor] = DateTime.now().add(retryAfter);
        }
        if (intentos < maxIntentos) {
          // Espera creciente tras cada fallo: 2, 4, 8 s.
          final espera = esperas[math.min(fallos, esperas.length - 1)];
          fallos++;
          siguiente?.cancel();
          siguiente = Timer(espera, lanzar);
        }
        acabarSiNoQueda();
      }

      cli
          .post(
            Uri.parse(servidor),
            headers: {
              'User-Agent': userAgent,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'data': query},
          )
          .timeout(porServidor)
          .then((resp) {
        if (completer.isCompleted) return;
        final cuerpo = utf8.decode(resp.bodyBytes, allowMalformed: true);
        if (resp.statusCode == 200 && !cuerpo.contains('"remark": "runtime error')) {
          enCurso--;
          siguiente?.cancel();
          reloj.cancel();
          completer.complete(cuerpo);
          return;
        }
        final ocupado = const {429, 502, 503, 504}.contains(resp.statusCode) ||
            cuerpo.contains('at capacity') ||
            cuerpo.contains('runtime error');
        fallo(
          ocupado ? 'ocupado (${resp.statusCode})' : 'HTTP ${resp.statusCode}',
          retryAfter: _retryAfter(resp.headers['retry-after']),
        );
      }).catchError((Object e) {
        fallo(e is TimeoutException
            ? 'sin respuesta en ${porServidor.inSeconds} s'
            : 'error de red ($e)');
      });
    }

    reloj = Timer(limiteConjunto, () {
      if (completer.isCompleted) return;
      siguiente?.cancel();
      errores.add('sin respuesta en ${limiteConjunto.inSeconds} s en total');
      completer.completeError(OverpassNoDisponible(errores));
    });
    lanzar();
    return completer.future;
  }

  /// `Retry-After` en segundos (o fecha HTTP), acotado a 2 minutos.
  static Duration? _retryAfter(String? v) {
    if (v == null) return null;
    final s = int.tryParse(v.trim());
    Duration? d;
    if (s != null) {
      d = Duration(seconds: s);
    } else {
      try {
        d = HttpFecha.parse(v).difference(DateTime.now());
      } catch (_) {
        return null;
      }
    }
    if (d.isNegative) return null;
    return d > const Duration(minutes: 2) ? const Duration(minutes: 2) : d;
  }
}

/// Fechas HTTP ("Wed, 21 Oct 2026 07:28:00 GMT") sin depender de dart:io.
class HttpFecha {
  static const _meses = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  static DateTime parse(String v) {
    final p = v.replaceAll(',', '').split(RegExp(r'\s+'));
    // [Wed, 21, Oct, 2026, 07:28:00, GMT]
    final dia = int.parse(p[1]);
    final mes = _meses.indexOf(p[2].toLowerCase()) + 1;
    final anyo = int.parse(p[3]);
    final h = p[4].split(':').map(int.parse).toList();
    if (mes == 0) throw FormatException('mes', v);
    return DateTime.utc(anyo, mes, dia, h[0], h[1], h[2]);
  }
}
