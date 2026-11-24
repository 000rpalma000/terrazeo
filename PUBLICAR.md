# Cómo publicar en App Store y Google Play

Sirve para las dos apps:

| | Terrazeo | A la sombra |
|---|---|---|
| Repo | `terrazeo` | `a-la-sombra` |
| ID (iOS y Android) | `com.lat41lab.terrazeo` | `com.alasombra.app` |
| Versión | `pubspec.yaml` → `version:` | ídem |
| Privacidad | https://lat41lab.com/privacy.html | https://lat41lab.com/privacy.html |

**Coste:** Apple 99 $/año (cuenta individual); Google 25 $ una sola vez. Con
una cuenta de cada publicas todas las apps que quieras.

---

## 0. Antes de nada

- **Correo de contacto propio para las apps** (p. ej. un Gmail nuevo). Aparece
  en las fichas de las tiendas y en la web, así que mejor no usar el personal.
- **¿Necesito web?** Sí, pero mínima. Las dos tiendas piden la URL de la
  **política de privacidad** y Apple pide además una **URL de soporte**. Las
  dos ya existen en GitHub Pages (tabla de arriba). Para soporte vale una
  página sencilla con descripción + correo (`docs/index.html`). Un dominio
  propio (~10 €/año) es opcional; tiene sentido cuando quieras captar bares.
- **Versión:** cada subida necesita un número de build mayor. En
  `pubspec.yaml`, `version: 2.0.0+1` → la siguiente `2.0.0+2` o `2.0.1+2`.
- Al acabar cada versión publicada: `git tag v2.0.0 && git push --tags`.

## 1. Apple (App Store)

### Alta
1. <https://developer.apple.com/programs/enroll/> con tu Apple ID (necesita la
   verificación en dos pasos). Elige **Individual**. Pagas 99 $ y Apple
   verifica tu identidad (de unas horas a un par de días).
2. **Estado de comerciante (UE, Ley de Servicios Digitales):** App Store
   Connect te preguntará si eres comerciante (*trader*). Si eres comerciante,
   Apple muestra **públicamente tu dirección y teléfono** en la ficha. Mientras
   las apps sean gratis, sin anuncios ni cobros, puedes declarar que **no**
   eres comerciante. Cuando empieces a cobrar a bares, tendrás que cambiarlo.

### Crear la app
1. <https://appstoreconnect.apple.com> → Apps → **+** → Nueva app.
   - Plataforma iOS, nombre **Terrazeo** (tiene que estar libre en toda la
     tienda; si no lo está, p. ej. "Terrazeo – terrazas al sol").
   - Bundle ID: `com.lat41lab.terrazeo` (se crea solo al compilar con firma
     automática; si no aparece, créalo en developer.apple.com → Identifiers).
   - SKU: cualquier texto, p. ej. `terrazeo`.
2. **Información de la app:** categoría (Viajes o Estilo de vida), URL de
   privacidad, edad (cuestionario: todo "no" → 4+).
3. **Privacidad de la app:** la app envía coordenadas a servicios de terceros
   (mapa, tiempo, OpenStreetMap) para responder al momento, y ni tú ni ellos
   las guardan asociadas a la persona. Lo habitual es declarar **"Datos no
   recopilados"**. Si dudas, declara *Ubicación aproximada · Funcionalidad de
   la app · No vinculada a la identidad · Sin seguimiento*.
4. **Capturas:** obligatorias las de iPhone de 6,9" (1320×2868), de 3 a 10.
   Se sacan del simulador "iPhone 17 Pro Max" con ⌘S. La app es solo para
   iPhone (`TARGETED_DEVICE_FAMILY = 1`), así que no hacen falta capturas de
   iPad. (En iPad se puede instalar igualmente en modo iPhone.)
5. Texto de la ficha: subtítulo (30 caracteres), descripción, palabras clave,
   URL de soporte.

### Subir la build
```sh
flutter build ipa --release --dart-define-from-file=dart_defines.json
open build/ios/archive/Runner.xcarchive   # Xcode → Distribute App → App Store Connect
```
(o sube `build/ios/ipa/*.ipa` con la app **Transporter**).

- Aparece en **TestFlight** en unos minutos: pruébala en tu iPhone.
- Luego, en la versión de la ficha, elige la build → **Enviar a revisión**
  (normalmente 1-2 días). Si la rechazan, el motivo llega por correo y se
  corrige y se reenvía.

## 2. Google (Play Store)

### Alta
1. <https://play.google.com/console/signup> → cuenta **personal**, 25 $.
   Verificación de identidad con DNI/pasaporte y un teléfono Android real.
2. **Importante, cuentas personales nuevas:** antes de publicar en producción
   hay que hacer una **prueba cerrada con al menos 12 personas durante 14
   días seguidos**. Ve buscando 12 amigos con Android (solo tienen que
   apuntarse con su Gmail e instalarla). Cuenta ese tiempo en el plan.

### Clave de firma (una sola vez por app; ¡guárdala bien!)
```sh
cd android
keytool -genkey -v -keystore ~/claves/terrazeo-upload.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
```
Crea `android/key.properties` (ya está en `.gitignore`, **no se sube**):
```
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/<tú>/claves/terrazeo-upload.jks
```
Con ese archivo, `build.gradle.kts` firma solo con tu clave. Activa **Play App
Signing** (viene por defecto): Google guarda la clave final y, si pierdes la
de subida, se puede reponer.

### Crear la app y subir
1. Play Console → Crear app → nombre, idioma (español), app, gratis.
2. Completa "Configurar tu app": política de privacidad, **anuncios: no**,
   acceso a la app (todo accesible), clasificación de contenido
   (cuestionario), público objetivo (mayores de 13 o 18), **Seguridad de los
   datos** (ubicación usada para la funcionalidad, no compartida, no
   recopilada; cifrada en tránsito), app de noticias: no.
3. Ficha: icono 512×512, gráfico destacado 1024×500, mínimo 2 capturas de
   móvil, descripción breve (80) y completa.
4. Compila:
   ```sh
   flutter build appbundle --release --dart-define-from-file=dart_defines.json
   ```
   y sube `build/app/outputs/bundle/release/app-release.aab` a **Pruebas →
   Prueba cerrada**, añade a los 12 testers y espera los 14 días.
5. Después: **Solicitar acceso a producción** → revisión (unos días) →
   publicada.

## 3. Lista de comprobación antes de cada envío

- [ ] `dart_defines.json` con la clave de MapTiler de **producción** (con el
      plan gratuito de MapTiler hay un límite mensual de teselas: vigílalo
      en su panel).
- [ ] `python3 tool/generar_bares.py` para tener los locales al día (solo
      Terrazeo).
- [ ] Subir el número de build en `pubspec.yaml`.
- [ ] `flutter test` y prueba rápida en un móvil real.
- [ ] Capturas actualizadas si ha cambiado la interfaz.
- [ ] Al publicar: `git tag vX.Y.Z` y `git push --tags`.
