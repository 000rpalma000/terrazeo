import 'package:flutter_test/flutter_test.dart';
import 'package:terrazeo/models/horario.dart';

// 2026-11-23 es lunes.
DateTime _t(int diaSemana, int h, [int m = 0]) =>
    DateTime(2026, 11, 22 + diaSemana, h, m);
const lu = 1, ma = 2, mi = 3, ju = 4, vi = 5, sa = 6, dom = 7;

void main() {
  test('días y tramos sencillos', () {
    final h = Horario.parse('Mo-Fr 08:00-20:00; Sa 10:00-14:00')!;
    expect(h.abiertoEn(_t(lu, 8)), isTrue);
    expect(h.abiertoEn(_t(vi, 19, 59)), isTrue);
    expect(h.abiertoEn(_t(vi, 20)), isFalse);
    expect(h.abiertoEn(_t(sa, 12)), isTrue);
    expect(h.abiertoEn(_t(sa, 15)), isFalse);
    expect(h.abiertoEn(_t(dom, 12)), isFalse); // día sin regla: cerrado
  });

  test('pasada la medianoche cuenta para el día siguiente', () {
    final h = Horario.parse('Su-Th 20:00-2:30; Fr-Sa 20:00-03:00')!;
    expect(h.abiertoEn(_t(vi, 23)), isTrue);
    expect(h.abiertoEn(_t(sa, 2, 45)), isTrue); // viernes hasta las 3
    expect(h.abiertoEn(_t(lu, 2, 45)), isFalse); // domingo hasta las 2:30
    expect(h.abiertoEn(_t(lu, 12)), isFalse);
    expect(Horario.parse('Mo-Su 18:00-24:00')!.abiertoEn(_t(ma, 23, 59)), isTrue);
  });

  test('varios tramos y comas entre reglas', () {
    final h = Horario.parse(
        'Mo-Fr 13:00-16:00, 20:00-00:00; Sa, Su 12:00-00:00')!;
    expect(h.abiertoEn(_t(mi, 17)), isFalse);
    expect(h.abiertoEn(_t(mi, 21)), isTrue);
    expect(h.abiertoEn(_t(dom, 17)), isTrue);
    final c = Horario.parse('Mo-Th, Su 12:00-00:00, Fr-Sa 12:00-01:00')!;
    expect(c.abiertoEn(_t(sa, 0, 30)), isTrue); // viernes hasta la 1
    expect(c.abiertoEn(_t(vi, 0, 30)), isFalse); // jueves hasta las 0
    expect(Horario.parse('Tu-We,Su 13:00-15:45; Th-Sa13:00-15:45,20:00-22:30')!
        .abiertoEn(_t(ju, 21)), isTrue);
  });

  test('reglas posteriores mandan; off y festivos', () {
    final h = Horario.parse('Mo-Su 09:00-22:00; We off; PH off')!;
    expect(h.abiertoEn(_t(ma, 10)), isTrue);
    expect(h.abiertoEn(_t(mi, 10)), isFalse);
    expect(Horario.parse('Mo-Su, PH 08:00-21:00')!.abiertoEn(_t(dom, 9)), isTrue);
    expect(Horario.parse('24/7')!.abiertoEn(_t(mi, 4)), isTrue);
    expect(Horario.parse('10:00-20:00')!.abiertoEn(_t(dom, 11)), isTrue);
    expect(Horario.parse('Fr-Mo 10:00-12:00')!.abiertoEn(_t(dom, 11)), isTrue);
  });

  test('lo que no sigue la forma habitual: no disponible', () {
    for (final s in [
      null,
      '',
      'Cerrado permanentemente',
      'Mo-Sa',
      'Jan-Dec: Mo-Su 13:00-16:00',
      'Mo-Th 12:00-23:00; Dec 25 closed',
      'Mo-Fr 08:00-12:00 "con cita"',
      'sunrise-sunset',
    ]) {
      expect(Horario.parse(s), isNull, reason: '$s');
    }
  });
}
