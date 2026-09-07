import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _kIntroVisto = 'intro_visto';

/// `true` si el usuario ya ha visto la introducción alguna vez.
Future<bool> introYaVisto() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getBool(_kIntroVisto) ?? false;
}

/// Muestra la introducción (qué es la app y para qué sirve). Al cerrarla se
/// marca como vista, salvo que [marcarVisto] sea `false` (p. ej. cuando se
/// abre a mano desde "Acerca de").
Future<void> mostrarIntro(BuildContext context, {bool marcarVisto = true}) async {
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.introTitle, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Punto(icon: Icons.touch_app_outlined, texto: l10n.introBody1),
            const SizedBox(height: 14),
            _Punto(icon: Icons.local_cafe_outlined, texto: l10n.introBody2),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.introButton),
              ),
            ),
          ],
        ),
      );
    },
  );
  if (marcarVisto) {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kIntroVisto, true);
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
