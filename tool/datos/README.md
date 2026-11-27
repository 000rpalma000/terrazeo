# Datos propios de Lat41 Lab

Edificios, calles y locales de OpenStreetMap, cortados en cuadrículas y
servidos desde Cloudflare R2 en `https://data.lat41lab.com/osm/v1/`. En las
zonas cubiertas (Barcelona y las ciudades de [`ciudades.json`](ciudades.json):
capitales de la UE, Reino Unido, Noruega y Suiza, y las ciudades europeas de
más de ~500.000 habitantes) **Terrazeo y Alombra los usan en lugar de
Overpass**: llegan en unos 100 ms y no dependen de un servicio público
saturado. Fuera de esas zonas, o si `data.lat41lab.com` falla, las apps
siguen usando Overpass.

## Cómo se generan

1. Extracto de Cataluña de [Geofabrik](https://download.geofabrik.de/europe/spain/cataluna.html)
   (se actualiza a diario; ~275 MB).
2. `generar_teselas.py` lo lee con pyosmium, aplica los mismos filtros que
   las consultas a Overpass de las apps y escribe una cuadrícula por archivo
   más `manifest.json`. Unos 80 s y 800 MB de memoria.

```sh
pip install -r tool/datos/requirements.txt
curl -LO https://download.geofabrik.de/europe/spain/cataluna/cataluna-latest.osm.pbf
python3 tool/datos/generar_teselas.py cataluna-latest.osm.pbf /tmp/salida \
    --bares assets/data/bares.json   # opcional: regenera los locales empaquetados
```

Barcelona (noviembre de 2026): 750 cuadrículas con datos, 99.285 edificios,
122.802 vías, 8.990 locales; 40 MB (12 MB comprimidos, ~16 KB por cuadrícula).

## Ciudades

[`ciudades.json`](ciudades.json): una línea por ciudad con su centro y un
radio (15 km las enormes, 10 km de 1 a 3 millones de habitantes, 7 km de
500.000 a 1 millón, 5 km las capitales pequeñas). La zona cubierta es el
cuadrado de lado 2 × radio.

En España, además: todas las ciudades de más de 100.000 habitantes (7 km
las de más de 200.000, 5 km las demás) y la **Regió Metropolitana de
Barcelona** completa.

### Zonas por límites oficiales

Una zona puede ser un conjunto de límites administrativos de OSM en lugar de
un cuadrado: campo `"limites"` con un archivo de [`zonas/`](zonas/). Así es
Barcelona: los 164 municipios de la Regió Metropolitana (Barcelonès, Baix
Llobregat, Vallès Occidental, Vallès Oriental, Maresme, Garraf y Alt
Penedès, más Castellcir, Castellterçol, Granera y Sant Quirze Safaja, que
pasaron al Moianès en 2015) y la caja de Barcelona ciudad de antes. Entra
toda cuadrícula que toca la zona; el archivo la guarda como rectángulos de
cuadrículas y la tarea mensual solo lo lee. Se rehace (si cambian los
límites) con:

```sh
pip install shapely
python3 tool/datos/zona_limites.py cataluna-latest.osm.pbf tool/datos/zonas/barcelona.json \
    --nombre "Regió Metropolitana de Barcelona" \
    --wikidata Q15348 Q15351 Q13948 Q14303 Q12600 Q15354 Q15355 Q15407 Q15408 Q15418 Q15452 \
    --caja-extra 41.317 2.052 41.469 2.229
python3 tool/datos/elegir_extractos.py tool/datos/ciudades.json /tmp/index-v1.json
```

Las ciudades que quedan dentro (L'Hospitalet, Badalona, Terrassa,
Sabadell, Mataró, Santa Coloma) no tienen zona propia.

Para añadir una: escribir `id`, `nombre`, `pais`, `centro` y `radio_km`
(el resto, cualquier valor) y recalcular caja, extractos y grupo:

```sh
curl -o /tmp/index-v1.json https://download.geofabrik.de/index-v1.json
python3 tool/datos/elegir_extractos.py tool/datos/ciudades.json /tmp/index-v1.json
```

Cada ciudad usa, para cada parte de su cuadrado, el extracto más pequeño de
Geofabrik que la contiene (una ciudad junto a una frontera usa dos extractos
pequeños, no el del país entero). Las que comparten extracto forman un
**grupo**, que se genera en una misma tarea.

Probar un grupo en local (necesita `osmium-tool`):

```sh
python3 tool/datos/preparar_grupo.py tool/datos/ciudades.json gb-leeds /tmp/trabajo
python3 tool/datos/generar_teselas.py /tmp/trabajo/grupo.osm.pbf /tmp/salida \
    --ciudades tool/datos/ciudades.json --grupo gb-leeds \
    --fecha-osm "$(cat /tmp/trabajo/fecha_osm.txt)"
```

## Actualización

`.github/workflows/datos-osm.yml` lo regenera el día 2 de cada mes (y a mano
desde la pestaña *Actions*, para todos los grupos o solo algunos):

1. Una tarea por grupo, hasta 5 a la vez: descarga sus extractos, recorta
   las ciudades (`osmium extract`) y genera sus cuadrículas. Sube **solo
   las que han cambiado** (`cambiadas.py`: huella nueva frente a la del
   manifiesto publicado, leído de R2). Cada subida es una escritura de
   clase A en R2 (gratis hasta 1 millón al mes); en un mes cambia ~15 %.
2. Los grupos que fallan (casi siempre porque Geofabrik rechaza durante un
   rato las conexiones de esa máquina de GitHub) se reintentan solos una
   vez, 10 minutos después y en máquinas nuevas
   (`generar-grupos.yml`, llamado dos veces).
3. Al final, `unir_manifiestos.py` junta los manifiestos de cada grupo y se
   sube `manifest.json`, siempre lo último. Si un grupo falla, conserva su
   cobertura del mes anterior (sus cuadrículas siguen en R2).

Necesita, en el repo
(*Settings → Secrets and variables → Actions*):

| Tipo | Nombre | Valor |
|---|---|---|
| Secret | `R2_ACCOUNT_ID` | ID de la cuenta de Cloudflare |
| Secret | `R2_ACCESS_KEY_ID` | Access Key ID del token de R2 |
| Secret | `R2_SECRET_ACCESS_KEY` | Secret Access Key del token de R2 |
| Variable | `R2_BUCKET` | `lat41lab-datos` |

Las apps guardan cada cuadrícula 30 días, así que los cambios de OSM llegan
a los usuarios en, como mucho, un mes.

## `ciutats.json`

Al final de cada ejecución, `generar_ciutats.py` publica
`https://data.lat41lab.com/ciutats.json` con las ciudades que de verdad
tienen datos ese mes: nombre en ca/es/en, país (código y nombre), centro,
caja y `venda_recomanats` (si allí se ofrece "Recomanat"; de momento solo
España, campo de `ciudades.json`).

- **En las apps:** apartado "Ciutats disponibles" de "Sobre l'app", aviso
  fuera de cobertura y botón "Apareix com a Recomanat" solo donde se vende.
- **En lat41lab.com:** se puede leer desde el navegador, siempre que el
  bucket de R2 permita la web como origen. Esto se configura en Cloudflare →
  R2 → `lat41lab-datos` → Settings → CORS policy:

  ```json
  [{"AllowedOrigins": ["https://lat41lab.com", "https://www.lat41lab.com"],
    "AllowedMethods": ["GET"], "MaxAgeSeconds": 86400}]
  ```

  y en la página, por ejemplo:

  ```html
  <ul id="ciutats"></ul>
  <script>
    const idioma = new URLSearchParams(location.search).get("lang") || "ca";
    fetch("https://data.lat41lab.com/ciutats.json").then(r => r.json()).then(d => {
      const ul = document.getElementById("ciutats");
      for (const c of d.ciutats) {
        const li = document.createElement("li");
        li.textContent = `${c.nom[idioma] || c.nom.en} (${c.pais_nom[idioma] || c.pais_nom.en})`;
        ul.appendChild(li);
      }
    });
  </script>
  ```

## Licencia

Los datos son © colaboradores de OpenStreetMap, con licencia
[ODbL](https://opendatacommons.org/licenses/odbl/). Los archivos derivados
se publican con la misma licencia, y las apps lo atribuyen en el mapa y en
*Acerca de*.

Formato de los archivos: [FORMATO.md](FORMATO.md).
