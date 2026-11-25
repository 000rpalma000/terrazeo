# Datos propios de Lat41 Lab

Edificios, calles y locales de OpenStreetMap, cortados en cuadrículas y
servidos desde Cloudflare R2 en `https://data.lat41lab.com/osm/v1/`. En las
zonas cubiertas (hoy, Barcelona) **Terrazeo y Alombra los usan en lugar de
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

## Actualización

`.github/workflows/datos-osm.yml` lo regenera el día 2 de cada mes (y a mano
desde la pestaña *Actions*) y lo sube al bucket de R2. Necesita, en el repo
(*Settings → Secrets and variables → Actions*):

| Tipo | Nombre | Valor |
|---|---|---|
| Secret | `R2_ACCOUNT_ID` | ID de la cuenta de Cloudflare |
| Secret | `R2_ACCESS_KEY_ID` | Access Key ID del token de R2 |
| Secret | `R2_SECRET_ACCESS_KEY` | Secret Access Key del token de R2 |
| Variable | `R2_BUCKET` | `lat41lab-datos` |

Las apps guardan cada cuadrícula 30 días, así que los cambios de OSM llegan
a los usuarios en, como mucho, un mes.

## Añadir otra ciudad

Una línea en `ZONAS` de `generar_teselas.py` (y otro extracto de Geofabrik
si queda fuera de Cataluña). El manifiesto admite varias zonas.

## Licencia

Los datos son © colaboradores de OpenStreetMap, con licencia
[ODbL](https://opendatacommons.org/licenses/odbl/). Los archivos derivados
se publican con la misma licencia, y las apps lo atribuyen en el mapa y en
*Acerca de*.

Formato de los archivos: [FORMATO.md](FORMATO.md).
