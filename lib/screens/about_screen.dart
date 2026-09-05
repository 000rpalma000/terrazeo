import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/search_gate.dart';

/// Pantalla "Acerca de": descripción, fuentes de datos, licencias y anuncios.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.version = '1.0.0'});

  final String version;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _gate = SearchGate();
  bool? _sinAnuncios;

  @override
  void initState() {
    super.initState();
    _gate.anunciosEliminados().then((v) {
      if (mounted) setState(() => _sinAnuncios = v);
    });
  }

  Future<void> _quitarAnuncios() async {
    await _gate.eliminarAnunciosMock();
    if (mounted) setState(() => _sinAnuncios = true);
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
          const SizedBox(height: 28),
          Text(l10n.adsSectionTitle, style: t.titleMedium),
          const SizedBox(height: 8),
          if (_sinAnuncios == true)
            Text(l10n.adsAlreadyRemoved, style: t.bodyMedium)
          else if (_sinAnuncios == false)
            FilledButton.tonal(
              onPressed: _quitarAnuncios,
              child: Text(l10n.removeAdsButton),
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
