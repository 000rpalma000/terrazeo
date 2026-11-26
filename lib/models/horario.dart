/// Horario de apertura de OpenStreetMap (`opening_hours`), solo en su forma
/// habitual: días de la semana y tramos de horas.
///
/// ```
/// Mo-Fr 08:00-23:00; Sa,Su 10:00-01:00
/// Mo-Th 12:00-23:00, Fr-Sa 12:00-01:00
/// Mo-Su 13:00-16:00,20:30-02:30; PH off
/// 24/7
/// ```
///
/// Cualquier otra cosa (meses, fechas, semanas, amanecer, comentarios,
/// texto libre…) hace que [Horario.parse] devuelva `null`: entonces el
/// horario se trata como "no disponible" y el local se sigue mostrando.
///
/// Los festivos (`PH`) se ignoran: la app no sabe qué días lo son.
class Horario {
  Horario._(this._tramos);

  /// Tramos por día de la semana (0 = lunes), en minutos desde las 00:00 de
  /// ese día; el final puede pasar de 1440 (abre hasta la madrugada).
  final List<List<(int, int)>> _tramos;

  static const _dias = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  static final _token = RegExp(
      r'\s*(24/7|off|closed|PH|SH|Mo|Tu|We|Th|Fr|Sa|Su|'
      r'\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}\+?|\d{1,2}:\d{2}\+|[-,;])\s*');

  /// `null` si el texto no sigue la forma habitual.
  static Horario? parse(String? texto) {
    final s = texto?.trim() ?? '';
    if (s.isEmpty) return null;

    // 1. Trocear en símbolos; si queda algo sin reconocer, no se entiende.
    final toks = <String>[];
    var pos = 0;
    while (pos < s.length) {
      final m = _token.matchAsPrefix(s, pos);
      if (m == null || m.end == pos) return null;
      toks.add(m.group(1)!);
      pos = m.end;
    }

    // 2. Agrupar en reglas: [días] (horas… | off). Una regla nueva empieza
    //    con ";" o con un día que llega después de horas u "off".
    final reglas = <({Set<int>? dias, List<(int, int)>? horas})>[];
    Set<int>? dias;
    var soloFestivos = false;
    List<(int, int)>? horas;
    var tieneHoras = false;
    var vistoDia = false;

    bool cerrar() {
      if (!vistoDia && !tieneHoras) return true; // regla vacía
      if (!tieneHoras) return false; // "Mo-Sa" sin horas: no se sabe
      if (!soloFestivos) reglas.add((dias: dias, horas: horas));
      dias = null;
      soloFestivos = false;
      horas = null;
      tieneHoras = false;
      vistoDia = false;
      return true;
    }

    for (var k = 0; k < toks.length; k++) {
      final t = toks[k];
      if (t == ';') {
        if (!cerrar()) return null;
      } else if (t == ',' || t == '-') {
        // Separadores: los rangos de días se leen junto al día.
        if (t == '-') return null;
      } else if (t == '24/7') {
        if (vistoDia || tieneHoras) return null;
        reglas.add((dias: null, horas: [(0, 1440)]));
        tieneHoras = false;
      } else if (t == 'PH' || t == 'SH' || _dias.contains(t)) {
        if (tieneHoras && !cerrar()) return null;
        vistoDia = true;
        if (t == 'PH' || t == 'SH') {
          dias ??= <int>{};
          if (dias!.isEmpty) soloFestivos = true;
          continue;
        }
        var a = _dias.indexOf(t), b = a;
        if (k + 2 < toks.length && toks[k + 1] == '-') {
          b = _dias.indexOf(toks[k + 2]);
          if (b < 0) return null;
          k += 2;
        }
        dias ??= <int>{};
        soloFestivos = false;
        for (var d = a;; d = (d + 1) % 7) {
          dias!.add(d);
          if (d == b) break;
        }
      } else if (t == 'off' || t == 'closed') {
        horas = const [];
        tieneHoras = true;
      } else {
        final tramo = _tramo(t);
        if (tramo == null) return null;
        (horas ??= []).add(tramo);
        tieneHoras = true;
      }
    }
    if (!cerrar() || reglas.isEmpty) return null;

    // 3. Cada regla sustituye a las anteriores en sus días.
    final porDia = List<List<(int, int)>>.generate(7, (_) => []);
    for (final r in reglas) {
      for (var d = 0; d < 7; d++) {
        if (r.dias == null || r.dias!.contains(d)) porDia[d] = r.horas ?? [];
      }
    }
    return Horario._(porDia);
  }

  /// "10:00-23:30" → (600, 1410). Si acaba antes de empezar, sigue al día
  /// siguiente. "18:00+" (sin hora de cierre) se toma hasta medianoche.
  static (int, int)? _tramo(String t) {
    if (t.endsWith('+') && !t.contains('-')) {
      final a = _min(t.substring(0, t.length - 1));
      return a == null ? null : (a, 1440);
    }
    final p = t.replaceAll('+', '').split('-');
    final a = _min(p[0].trim()), b = _min(p[1].trim());
    if (a == null || b == null) return null;
    return (a, b <= a ? b + 1440 : b);
  }

  static int? _min(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null || h > 48 || m > 59) return null;
    return h * 60 + m;
  }

  /// Si está abierto en [t] (hora local), mirando también lo que sigue
  /// abierto desde el día anterior pasada la medianoche.
  bool abiertoEn(DateTime t) {
    final d = t.weekday - 1;
    final m = t.hour * 60 + t.minute;
    for (final (a, b) in _tramos[d]) {
      if (m >= a && m < b) return true;
    }
    for (final (a, b) in _tramos[(d + 6) % 7]) {
      if (b > 1440 && m + 1440 >= a && m + 1440 < b) return true;
    }
    return false;
  }
}
