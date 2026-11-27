import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/terraces_screen.dart';
import 'services/locale_controller.dart';

Future<void> main() async {
  // En la versión publicada, los mensajes de diagnóstico no van al registro
  // del sistema (logcat / consola).
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController();
  await localeController.cargar();
  runApp(PlacesBarcelonaApp(localeController: localeController));
}

class PlacesBarcelonaApp extends StatelessWidget {
  const PlacesBarcelonaApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF2A413), // sol
      brightness: Brightness.light,
    );
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
        debugShowCheckedModeBanner: false,
        locale: localeController.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        home: TerracesScreen(localeController: localeController),
      ),
    );
  }
}
