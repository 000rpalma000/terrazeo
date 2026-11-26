import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/locales_config.dart';
import '../models/ciutat.dart';
import '../services/recomanats_service.dart';
import '../widgets/ciutats_lista.dart';

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

  final _ciutatsSrv = CiutatsService();
  List<Ciutat> _ciutats = const [];

  @override
  void initState() {
    super.initState();
    _ciutatsSrv.cargar().then((c) {
      if (mounted) setState(() => _ciutats = c);
    });
  }

  @override
  void dispose() {
    _ciutatsSrv.dispose();
    super.dispose();
  }

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
          const SizedBox(height: 16),
          // Para los dueños de locales: abre la web (nada de pagos en la app).
          FilledButton.tonalIcon(
            icon: const Icon(Icons.storefront_outlined),
            label: Text(l10n.haveVenue),
            onPressed: () => launchUrl(
                LocalesConfig.paginaLocales(
                    Localizations.localeOf(context).languageCode),
                mode: LaunchMode.externalApplication),
          ),
          if (_ciutats.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(l10n.availableCities, style: t.titleMedium),
            const SizedBox(height: 6),
            Text(l10n.availableCitiesIntro, style: t.bodySmall),
            const SizedBox(height: 8),
            CiutatsLista(_ciutats),
          ],
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
