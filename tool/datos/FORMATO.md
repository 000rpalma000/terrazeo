# Formato de los datos propios (v1)

Todo cuelga de `https://data.lat41lab.com/osm/v1/`.

## Cuadrícula

La misma de las apps (`Tesela`): `i = floor(lat / 0.005)`,
`j = floor(lon / 0.0066)`, unos 550 × 550 m en Barcelona. Clave `"{i}_{j}"`.

## `manifest.json`

```json
{
  "v": 1,
  "generado": "2026-11-25T09:59:01Z",
  "datos_osm": "2026-11-24T21:21:02Z",
  "fuente": "© colaboradores de OpenStreetMap (ODbL) · extracto de Geofabrik",
  "tam": [0.005, 0.0066],
  "cobertura": [{"i0": 8263, "i1": 8293, "j0": 310, "j1": 337}],
  "cuadriculas": {"8276_329": "3f2a9c01b7e4", "…": "…"}
}
```

- `cobertura`: zonas cubiertas, en índices de cuadrícula (inclusive): un
  rectángulo por ciudad, o varios cientos en las zonas hechas con límites
  oficiales (la Regió Metropolitana de Barcelona). Pueden solaparse. `g` es el grupo de ciudades.json que la genera (las apps no
  lo usan; sirve para conservarla si un mes falla su tarea).
- `cuadriculas`: las que tienen datos, con una huella (SHA-1, 12 cifras) de
  su archivo. **Una cuadrícula dentro de la cobertura que no esté aquí está
  vacía** (mar, montaña): no hay que pedirla ni a Overpass.
- Caché HTTP: 5 minutos (las apps lo guardan 24 h).

## `{i}_{j}.json`

```json
{
  "v": 1,
  "t": "8276_329",
  "w": [[id, tipo, etiquetas, nodos, coordenadas], …],
  "n": [["node/123", 41.38, 2.17, "nombre", "bar", 1, "Mo-Su 09:00-23:00"], …]
}
```

### `w`: vías y edificios

| Campo | Contenido |
|---|---|
| `id` | id del *way* de OSM |
| `tipo` | `"b"` edificio o parte de edificio · `"h"` vía (`highway`) · `"a"` parque o plaza |
| `etiquetas` | solo las necesarias: edificios `building`, `height`, `building:height`, `building:levels`, `roof:levels`; partes (`building:part`, solo las que tienen `height` o `building:levels`) `building:part`, `height`, `building:levels`, `roof:levels`, `min_height`, `building:min_level`; vías `highway` (+ `area`); áreas `leisure` o `place` |
| `nodos` | ids de nodo de OSM, solo en vías (grafo peatonal de Alombra); `0` en el resto |
| `coordenadas` | `[lat0, lon0, dlat1, dlon1, …]` en millonésimas de grado; cada par, diferencia con el anterior |

- Edificios, partes y áreas van en **una** cuadrícula: la de su centro.
- Las partes (Simple 3D Buildings) dan la altura de cada trozo del
  edificio. Terrazeo las usa para las sombras cuando cubren al menos el
  80 % de la planta (si no, el contorno con su altura); el contorno se
  sigue usando para saber si un punto cae dentro de un edificio. Una app
  que no las conozca debe ignorar los elementos sin `building` ni
  `highway` que lleven `building:part`.
- Las vías van en **todas** las cuadrículas que toca su caja, para no
  cortar calles largas. Al juntar cuadrículas hay que quitar repetidas por
  `id`.
- Vías: `footway path pedestrian living_street steps residential service
  unclassified tertiary tertiary_link secondary secondary_link track road
  cycleway`, sin `foot=no|private` ni `access=private|no` (la unión de lo
  que usan las dos apps; cada una filtra las suyas).

### `n`: locales

Igual que `assets/data/bares.json`: `[osmId, lat, lon, nombre, amenity,
terraza, horario]`.

- `terraza`: `1` confirmada (`outdoor_seating` = `yes`, `terrace`,
  `sidewalk`, `street`, `pedestrian_zone`, `parklet` u `only`, o
  `amenity=biergarten`); `-1` sin terraza (`outdoor_seating=no`); `0` sin
  etiqueta (sin confirmar).
- `horario`: `opening_hours` tal cual, o `""` si no tiene.

Las apps anteriores leen solo los seis primeros campos y tratan como "sin
terraza declarada" todo lo que no sea `1`, así que el cambio es compatible.
Los locales que son *ways* usan el centro de su caja.

- Caché HTTP: 1 día. Las apps los guardan 30 días.

## Compatibilidad

Un cambio incompatible sube la versión de la ruta (`/osm/v2/`); las apps
viejas siguen leyendo `/osm/v1/` mientras exista.
