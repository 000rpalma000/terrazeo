import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Un JSON pequeño de data.lat41lab.com guardado en disco: se usa la copia si
/// es más nueva que [vigencia]; si no, se descarga; y sin red, la última
/// copia aunque sea vieja. `null` si nunca se ha podido descargar (o 404).
class JsonRemoto {
  JsonRemoto(this.url, this.archivo, this.vigencia, {http.Client? client})
      : _client = client ?? http.Client();

  final String url;
  final String archivo;
  final Duration vigencia;
  final http.Client _client;

  Future<String?> cargar() async {
    File? f;
    try {
      f = File('${(await getApplicationSupportDirectory()).path}/$archivo');
    } catch (_) {}
    String? guardado;
    if (f != null && await f.exists()) {
      try {
        guardado = await f.readAsString();
        if (DateTime.now().difference(await f.lastModified()) < vigencia) {
          return guardado;
        }
      } catch (_) {}
    }
    try {
      final r = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final txt = utf8.decode(r.bodyBytes);
        try {
          await f?.writeAsString(txt);
        } catch (_) {}
        return txt;
      }
      if (r.statusCode == 404) return null;
    } catch (e) {
      debugPrint('[$archivo] no disponible: $e');
    }
    return guardado;
  }

  void dispose() => _client.close();
}
