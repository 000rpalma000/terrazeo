import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sun_status.dart';

/// Icono redondo que resume el estado de sol/sombra.
class SunBadge extends StatelessWidget {
  const SunBadge({super.key, required this.status, this.size = 44});

  final SunStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      SunStatus.pleno => (const Color(0xFFF2A413), Icons.wb_sunny),
      SunStatus.solConNubes => (const Color(0xFFE8B84B), Icons.wb_cloudy),
      SunStatus.nublado => (const Color(0xFF9AA5B1), Icons.cloud),
      SunStatus.sombraPorEdificios => (const Color(0xFF5B6B7B), Icons.apartment),
      SunStatus.noche => (const Color(0xFF33415C), Icons.nightlight_round),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Rosa de los vientos: flecha que apunta hacia donde va el viento.
class WindArrow extends StatelessWidget {
  const WindArrow({super.key, required this.directionDeg, this.size = 56});

  /// Dirección meteorológica (grados desde donde sopla). `null` = sin dato.
  final int? directionDeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WindArrowPainter(
          angleRad:
              directionDeg == null ? null : (directionDeg! + 180) * math.pi / 180,
          color: Theme.of(context).colorScheme.primary,
          ringColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _WindArrowPainter extends CustomPainter {
  _WindArrowPainter({
    required this.angleRad,
    required this.color,
    required this.ringColor,
  });

  final double? angleRad;
  final Color color;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ringColor,
    );
    if (angleRad == null) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angleRad!);
    final arrow = Path()
      ..moveTo(0, -r + 6)
      ..lineTo(r * 0.32, r * 0.4)
      ..lineTo(0, r * 0.18)
      ..lineTo(-r * 0.32, r * 0.4)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WindArrowPainter old) =>
      old.angleRad != angleRad || old.color != color;
}
