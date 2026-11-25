# Intermediario de AEMET (`api.lat41lab.com/tiempo`)

Worker de Cloudflare entre Terrazeo y la API OpenData de AEMET.

- **La clave de AEMET no está en la app ni en el repositorio**: es el secreto
  `AEMET_API_KEY` del Worker.
- **Caché compartida**: todos los usuarios de una misma zona comparten la
  misma respuesta, así que la clave no se agota por número de usuarios.
- **Solo cuatro consultas** (las de la app); cualquier otra ruta da 404:

| Ruta (tras `/tiempo`) | Vigencia | Reserva si AEMET falla |
|---|---|---|
| `/observacion/convencional/datos/estacion/{idema}` | 30 min | 6 h |
| `/prediccion/especifica/municipio/horaria/{municipio}` | 1 h | 24 h |
| `/maestro/municipios` | 7 días | 30 días |
| `/valores/climatologicos/inventarioestaciones/todasestaciones` | 7 días | 30 días |

- **Respuesta**: el JSON final de AEMET, ya en UTF-8. El Worker hace los dos
  pasos de la API (metadatos → `datos`).
- **Si AEMET falla** (o limita la clave, con 401/429): devuelve la última copia
  aunque haya caducado, dentro de la reserva. Si no hay ninguna, responde 502
  o 503 con `Retry-After`, y la app usa Open-Meteo.
- **Qué recibe el Worker**: solo el código de la estación o del municipio. La
  app elige cuál en el propio teléfono y no envía su ubicación. Cloudflare ve,
  como en cualquier web, la IP y el *user agent*. El Worker no guarda nada de
  eso; los registros de Cloudflare (*observability*) se borran solos a los
  pocos días.

## Uso

```sh
npm install
npm test                 # pruebas sin red
npx wrangler login       # una vez
npx wrangler deploy      # crea/actualiza el Worker y api.lat41lab.com
npx wrangler secret put AEMET_API_KEY   # pide la clave (no se ve al pegarla)
```

En local: `npx wrangler dev --env-file <fichero con AEMET_API_KEY=…>` (fuera
del repositorio) y la app con
`--dart-define=TIEMPO_URL=http://127.0.0.1:8787/tiempo`.
