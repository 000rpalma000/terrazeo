import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../widgets/intro_sheet.dart';

/// Pantalla "Acerca de": descripción, fuentes de datos, y licencias.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.version = '2.0.0'});

  final String version;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // TODO: cambiar por el enlace de la tienda cuando la app esté publicada.
  static const _urlCompartir = 'https://lat41lab.com/privacy.html';

  Future<void> _compartir() async {
    final l10n = AppLocalizations.of(context);
    await SharePlus.instance.share(
      ShareParams(text: '${l10n.appTitle} — ${l10n.aboutIntro}\n$_urlCompartir'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.appTitle, style: t.headlineSmall),
          const SizedBox(height: 4),
          Text('v${widget.version}', style: t.bodySmall),
          const SizedBox(height: 16),
          Text(l10n.aboutIntro, style: t.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.help_outline),
                label: Text(l10n.showIntro),
                onPressed: () => mostrarIntro(context, marcarVisto: false),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.shareApp),
                onPressed: _compartir,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(l10n.dataSources, style: t.titleMedium),
          const SizedBox(height: 8),
          _bullet(context, l10n.creditMap),
          _bullet(context, l10n.creditTiles),
          _bullet(context, l10n.creditWeather),
          _bullet(context, l10n.creditSun),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.openSourceLicenses),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: 'v${widget.version}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('·  '),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
}
