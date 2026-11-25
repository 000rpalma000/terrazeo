# places_barcelona

App Flutter para saber, en una plaza o parque de Barcelona, **si ahora mismo da el sol y cuánto viento hace** — y planificar un rato más tarde.

## Qué hace

- Busca plazas, parques y zonas peatonales cerca de tu ubicación (OpenStreetMap / Overpass).
- Para cada una estima si está **al sol o en sombra**, combinando:
  - la posición del sol (`solar_calculator`),
  - la altura de los edificios que la rodean (OSM), con un modelo geométrico sencillo,
  - la nubosidad prevista (AEMET).
- Muestra el **viento**: velocidad, rachas y dirección, de la observación real de AEMET (estación de El Prat) para "ahora", y de la predicción horaria para "más tarde".
- Selector de hora para ver el sol y el viento en las próximas ~36 h.

## Estructura

```
lib/
  models/       plaza.dart · weather_conditions.dart · sun_evaluation.dart
  services/     location_service.dart   ubicación (geolocator)
                osm_service.dart        Overpass: plazas + altura de edificios
                aemet_service.dart      AEMET OpenData: observación + predicción horaria
                sun_service.dart        posición del sol + sol/sombra
  widgets/      condition_chips.dart    insignias de sol y flecha de viento
  screens/      plaza_list_screen.dart · plaza_detail_screen.dart
```

## Configuración

La app **no lleva ninguna clave de AEMET**: el tiempo de AEMET llega por el
intermediario `https://api.lat41lab.com/tiempo` (Worker de Cloudflare en
[`cloudflare/tiempo/`](cloudflare/tiempo/README.md)), que guarda la clave como
secreto de Cloudflare. Si no responde, la app usa Open-Meteo.

Para la clave del mapa, `dart_defines.json` en la raíz (en `.gitignore`):

```
{"MAPTILER_KEY": "…"}
```

y `flutter run --dart-define-from-file=dart_defines.json`. Con
`--dart-define=TIEMPO_URL=http://127.0.0.1:8787/tiempo` se usa el Worker en
local (`npm run dev` en `cloudflare/tiempo/`).

## Notas

- El modelo de sombra por edificios es una aproximación (plaza = círculo, altura vs. `atan(altura/radio)`). El cálculo geométrico real de sombras se hará en la app de rutas.
- Estación de observación por defecto: `0076` (Barcelona Aeropuerto). Alternativa: `0201D` (Observatori Fabra).
- Municipio AEMET: `08019` (Barcelona).
