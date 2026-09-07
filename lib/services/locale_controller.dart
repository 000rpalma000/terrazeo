import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el idioma elegido por el usuario (o `null` = seguir el sistema) y lo
/// persiste entre sesiones.
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'locale';

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> cargar() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_prefsKey);
    if (code != null && code.isNotEmpty) _locale = Locale(code);
    notifyListeners();
  }

  Future<void> establecer(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    if (locale == null) {
      await sp.remove(_prefsKey);
    } else {
      await sp.setString(_prefsKey, locale.languageCode);
    }
  }
}

/// Idiomas ofrecidos, con su nombre en su propio idioma.
class OpcionIdioma {
  final Locale? locale; // null = automático
  final String nombre;
  const OpcionIdioma(this.locale, this.nombre);
}

const idiomasDisponibles = <OpcionIdioma>[
  OpcionIdioma(null, ''), // el nombre "Automático" se toma de la traducción
  OpcionIdioma(Locale('es'), 'Español'),
  OpcionIdioma(Locale('ca'), 'Català'),
  OpcionIdioma(Locale('en'), 'English'),
  OpcionIdioma(Locale('fr'), 'Français'),
  OpcionIdioma(Locale('it'), 'Italiano'),
  OpcionIdioma(Locale('de'), 'Deutsch'),
];
