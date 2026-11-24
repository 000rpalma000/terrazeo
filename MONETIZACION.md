# Monetización (apagada hoy)

Terrazeo se publica **sin anuncios y sin cobros**. Todo lo necesario para
activarlos más adelante está en este repo.

## 1. Anuncios (AdMob)

El código completo con anuncios está guardado en la rama
**`con-anuncios-admob`**: intersticial cada 3 toques en el mapa, oferta de
"quitar anuncios" y sección en Acerca de. Usa los IDs de prueba de Google.

Para recuperarlo:

```sh
git checkout con-anuncios-admob -- lib/services/ads_service.dart lib/services/search_gate.dart
# y volver a añadir en pubspec.yaml:  google_mobile_ads: ^9.1.0
```

Después, revisar el diff de la rama para restaurar:
- `lib/screens/terraces_screen.dart`: `AdsService.instancia.inicializar()` en
  `initState`, y `_contarToque()` / `_ofrecerQuitarAnuncios()`.
- `lib/screens/about_screen.dart`: sección de anuncios.
- `ios/Runner/Info.plist`: `GADApplicationIdentifier`.
- `android/app/src/main/AndroidManifest.xml`: meta-data
  `com.google.android.gms.ads.APPLICATION_ID`.

Antes de publicar con anuncios:
1. Cuenta en <https://admob.google.com>, registrar la app y crear un bloque
   intersticial. Poner los IDs reales en lugar de los de prueba.
2. Hacer real la compra "quitar anuncios" (paquete `in_app_purchase` y un
   producto en App Store Connect / Google Play Console). Hoy es un simulacro.
3. **Privacidad:** actualizar `PRIVACY.md` y `docs/privacy.html` (AdMob recoge
   el identificador de publicidad), la etiqueta de privacidad de App Store, la
   sección "Seguridad de los datos" de Google Play y marcar "contiene
   anuncios". En la UE hace falta el aviso de consentimiento (Google UMP), y en
   iOS el aviso de seguimiento (ATT) si se usan anuncios personalizados.
4. Darse de alta como autónomo (o empresa) si los ingresos pasan a ser una
   actividad económica.

## 2. Locales destacados (suscripción para bares)

Está programado pero **fuera de `main`**: el código completo está en la rama
**`con-destacados`** (`lib/services/destacados_service.dart`,
`assets/data/destacados.json`, la cadena `sponsored` de los 6 idiomas y los
cambios en `lib/screens/terraces_screen.dart`). Para recuperarlo, fusiona o
copia esos cambios desde esa rama.

Un local destacado:
- sale el primero de la lista y en el mapa lleva una estrella más grande;
- siempre lleva la etiqueta **"Patrocinado"** (la normativa europea de consumo
  obliga a decir cuándo un puesto en un ranking está pagado).

**Cómo se activa:** la lista de destacados es un JSON:

```json
{"destacados": [{"osmId": "node/123456", "hasta": "2027-06-30"}]}
```

- `osmId` es el identificador del local en OpenStreetMap (sale en
  `assets/data/bares.json` o en openstreetmap.org, pestaña "Consultar").
- `hasta` es el último día pagado: después deja de destacarse solo.

Hay dos sitios donde ponerla:
1. `assets/data/destacados.json`, que va dentro de la app. Cada cambio exige
   sacar una versión nueva.
2. **Remota (recomendado):** un JSON público, por ejemplo en GitHub Pages
   (`docs/destacados.json` → `https://000rpalma000.github.io/terrazeo/destacados.json`),
   indicado al compilar:
   `--dart-define=DESTACADOS_URL=https://…/destacados.json`.
   Así puedes añadir o quitar bares sin publicar otra versión.

**Antes de cobrar al primer bar:**
- Alta de autónomo y facturas con IVA.
- Cobro: lo más sencillo es un enlace de suscripción de Stripe o un recibo
  mensual. **No** se cobra dentro de la app: es un servicio a empresas, así que
  no pasa por la compra integrada de Apple ni de Google.
- Unas condiciones del servicio sencillas (qué incluye, precio, cómo se da de
  baja) y una página web para captar bares (ver `PUBLICAR.md`).
- Más adelante, si hay muchos clientes: un panel donde el bar gestione su
  suscripción. El servicio ya acepta la URL remota, así que solo cambiaría quién
  genera el JSON.
