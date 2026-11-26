# "Destacat a Terrazeo" (Stripe → `recomanats.json`)

Worker de Cloudflare en `https://pagos.lat41lab.com/stripe/webhook` que
recibe los webhooks de Stripe y mantiene la lista pública de locales
recomendados en R2: `https://data.lat41lab.com/recomanats.json`.

- **Cobro:** suscripción de 5 €/mes (IVA incluido) con el enlace de pago de
  Stripe. La app solo abre el navegador; no hay pagos dentro de la app.
- **Qué local paga:** el enlace lleva `?client_reference_id=node_123` (el id
  de OpenStreetMap con `_` en lugar de `/`, porque Stripe solo admite
  letras, números, `-` y `_`).
- **Lo que hace la app con los destacados:** icono con estrella, etiqueta
  "Destacat" (traducida) con el aviso "Patrocinat · paga per aparèixer
  destacat…", primeros a igual confort y filtro "Només destacats". **Nunca
  cambia los cálculos de sol, sombra o viento.**
- **Desde la ficha:** en Android, el botón abre el pago de Stripe con el
  local ya indicado; en iPhone, la página `lat41lab.com/locals.html`.

## Modo real y modo de prueba

- **Secretos:** el Worker acepta la firma de dos webhooks de Stripe:
  `STRIPE_WEBHOOK_SECRET` (el de prueba) y `STRIPE_WEBHOOK_SECRET_LIVE` (el
  real).
- **Eventos reales** (`livemode: true`): van a `recomanats.json`, que es la
  lista que lee la app.
- **Eventos de prueba:** van a `recomanats_prueba.json`
  (`https://data.lat41lab.com/recomanats_prueba.json`) y a claves de KV con
  el prefijo `prueba:`. Nunca salen en la app publicada.
- **Ver los de prueba en la app:** se compila con
  `--dart-define=RECOMANATS_URL=https://data.lat41lab.com/recomanats_prueba.json`.

## Eventos

| Evento de Stripe | Qué hace |
|---|---|
| `checkout.session.completed` | Alta del local de `client_reference_id`, activo. Sin `client_reference_id`: no toca la lista y lo guarda en KV (empresa, correo, suscripción) para asignarlo a mano |
| `invoice.paid` | La fecha de fin pasa al final del periodo pagado |
| `customer.subscription.updated` (impago: `unpaid`, `canceled`…) | Estado `baja`; sigue recomendado hasta la fecha de fin ya pagada |
| `customer.subscription.deleted` | Estado `baja`; si se cortó antes de tiempo, la fecha de fin pasa al corte |

- **Cuándo deja de ser recomendado:** la app solo enseña los que tienen
  `fin` posterior a ahora. Si no llega otro pago, cada local deja de serlo
  solo al acabar lo pagado.
- **Firma y repeticiones:** cada evento se comprueba con la firma de Stripe
  (`Stripe-Signature`, máximo 5 minutos de diferencia) y se procesa una
  sola vez.

## `recomanats.json` (público)

```json
{"v": 1, "actualizado": "2026-11-26T13:18:32Z", "locales": [
  {"osm": "node/123", "nombre": "Bar Pepe", "foto": "https://…/foto.jpg",
   "texto": {"ca": "…", "es": "…", "en": "…"},
   "estado": "activo", "fin": "2026-12-26T10:00:00Z"}
]}
```

- **Campos a mano:** `nombre`, `foto` (solo `https://`) y `texto` se rellenan
  a mano y el Worker los respeta.
- **Datos privados:** no hay nada de Stripe ni del cliente. La relación
  suscripción → local va en KV (`PRIVADO`), que no es público, igual que los
  avisos y los eventos ya procesados.
- **Caché:** 5 minutos (`Cache-Control`).

Para editarlo a mano (por ejemplo, para añadir la foto o asignar un pago que
llegó sin local):

```sh
npx wrangler r2 object get lat41lab-datos/recomanats.json --remote --file recomanats.json
# editar
npx wrangler r2 object put lat41lab-datos/recomanats.json --remote --file recomanats.json \
  --content-type "application/json; charset=utf-8" --cache-control "public, max-age=300"
```

Si un pago llegó sin local, además de añadirlo a la lista hay que enlazar su
suscripción, para que los pagos siguientes amplíen la fecha:

```sh
npx wrangler kv key put --remote --binding PRIVADO "sub:sub_XXXX" '{"osm":"node/123"}'
```

## Pagos sin local por asignar

Stripe avisa por correo de cada pago. Los que llegaron sin
`client_reference_id` (por ejemplo, desde el enlace de la web) quedan
guardados en el Worker. Para verlos:

```sh
cd cloudflare/recomanats && npm run pendientes
```

Para asignar uno, se añade el local a `recomanats.json` y se enlaza la
suscripción (ver arriba). Después se borra de la lista:

```sh
npx wrangler kv key delete --remote --binding PRIVADO "sin_local:sub_XXXX"
```

## Uso

```sh
npm install
npm test                                          # pruebas sin red
npx wrangler deploy                               # Worker y pagos.lat41lab.com
npx wrangler secret put STRIPE_WEBHOOK_SECRET       # secreto del webhook de prueba
npx wrangler secret put STRIPE_WEBHOOK_SECRET_LIVE  # secreto del webhook real
```
