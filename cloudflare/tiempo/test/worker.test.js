// Pruebas del Worker sin red ni Cloudflare: `npm test`.
import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";

const env = { AEMET_API_KEY: "clave-de-prueba" };
let llamadas, aemetResponde, guardado, ahora;

// Caché de Cloudflare falsa (en memoria).
globalThis.caches = {
  default: {
    async match(req) {
      const r = guardado.get(req.url);
      return r ? r.clone() : undefined;
    },
    async put(req, res) {
      guardado.set(req.url, res.clone());
    },
  },
};

// AEMET falso: metadatos con la URL de `datos`, y datos en ISO-8859-1.
globalThis.fetch = async (url, opts = {}) => {
  llamadas.push({ url: String(url), clave: opts.headers?.api_key });
  if (aemetResponde === "429") return new Response("", { status: 429 });
  if (aemetResponde === "caido") throw new Error("sin conexión");
  if (String(url).startsWith("https://opendata.aemet.es/opendata/api/")) {
    return Response.json({ estado: 200, datos: "https://opendata.aemet.es/opendata/sh/abc" });
  }
  // "Barcelona, Observatori Fabra · 12,5 ºC" en latin1
  const bytes = Uint8Array.from(Buffer.from('[{"ubi":"Observatori Fabra","ta":12.5,"u":"ºC"}]', "latin1"));
  return new Response(bytes);
};

const ctx = { waitUntil: (p) => p };
const pedir = (ruta, metodo = "GET") =>
  worker.fetch(new Request(`https://api.lat41lab.com${ruta}`, { method: metodo }), env, ctx);

const realNow = Date.now;
beforeEach(() => {
  llamadas = [];
  aemetResponde = "ok";
  guardado = new Map();
  ahora = 1_800_000_000_000;
  Date.now = () => ahora;
});

const OBS = "/tiempo/observacion/convencional/datos/estacion/0076";

test("pasa a AEMET con la clave, convierte a UTF-8 y guarda en caché", async () => {
  const r = await pedir(OBS);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get("x-cache"), "MISS");
  assert.match(r.headers.get("content-type"), /utf-8/);
  assert.deepEqual(await r.json(), [{ ubi: "Observatori Fabra", ta: 12.5, u: "ºC" }]);
  assert.equal(llamadas.length, 2);
  assert.equal(llamadas[0].url, "https://opendata.aemet.es/opendata/api/observacion/convencional/datos/estacion/0076");
  assert.equal(llamadas[0].clave, "clave-de-prueba");
  assert.equal(llamadas[1].clave, undefined); // la URL de datos no lleva la clave
});

test("la segunda petición sale de la caché, sin llamar a AEMET", async () => {
  await pedir(OBS);
  ahora += 10 * 60 * 1000;
  const r = await pedir(OBS + "?saltar=1");
  assert.equal(r.headers.get("x-cache"), "HIT");
  assert.equal(llamadas.length, 2);
  assert.equal(r.headers.get("cache-control"), "public, max-age=1200");
});

test("caducada y AEMET caído: devuelve la copia vieja", async () => {
  await pedir(OBS);
  ahora += 2 * 60 * 60 * 1000;
  aemetResponde = "caido";
  const r = await pedir(OBS);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get("x-cache"), "STALE");
});

test("sin copia y AEMET saturado: 503 con Retry-After", async () => {
  aemetResponde = "429";
  const r = await pedir("/tiempo/prediccion/especifica/municipio/horaria/08019");
  assert.equal(r.status, 503);
  assert.equal(r.headers.get("retry-after"), "60");
  assert.equal(r.headers.get("cache-control"), "no-store");
});

test("solo acepta las consultas de la app", async () => {
  for (const ruta of [
    "/tiempo/prediccion/especifica/municipio/diaria/08019",
    "/tiempo/observacion/convencional/todas",
    "/tiempo/prediccion/especifica/municipio/horaria/08019/../../x",
    "/tiempo/maestro/municipios/extra",
    "/otra/cosa",
    "/",
  ]) {
    assert.equal((await pedir(ruta)).status, 404, ruta);
  }
  assert.equal((await pedir(OBS, "POST")).status, 405);
  assert.equal(llamadas.length, 0);
});

test("sin clave configurada: 503 y no llama a AEMET", async () => {
  const r = await worker.fetch(new Request(`https://api.lat41lab.com${OBS}`), {}, ctx);
  assert.equal(r.status, 503);
  assert.equal(llamadas.length, 0);
});

test.after(() => {
  Date.now = realNow;
});
