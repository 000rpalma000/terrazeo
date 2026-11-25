// Intermediario de AEMET para Terrazeo: https://api.lat41lab.com/tiempo/…
//
// La app pide aquí lo mismo que pediría a AEMET, pero sin clave: el Worker
// añade la clave (secreto AEMET_API_KEY de Cloudflare, nunca en el código),
// hace los dos pasos de la API de AEMET (metadatos → URL de `datos`), pasa el
// resultado de ISO-8859-1 a UTF-8 y lo guarda en la caché de Cloudflare. Así
// todos los usuarios comparten unas pocas llamadas a AEMET por hora, en vez
// de gastar cada uno la cuota de la misma clave.
//
// Solo acepta las cuatro consultas que usa la app (no es un proxy abierto).
// Si AEMET falla, devuelve la última copia guardada aunque esté caducada
// (hasta `RESERVA`); si no hay ninguna, un 502/503 y la app usa Open-Meteo.

const AEMET = "https://opendata.aemet.es/opendata/api";

const MIN = 60;
const HORA = 60 * MIN;
const DIA = 24 * HORA;

/** Consultas permitidas: patrón de la ruta y cuánto vale la respuesta. */
const RUTAS = [
  // Observación de una estación: AEMET la publica cada hora, con retraso.
  { re: /^\/observacion\/convencional\/datos\/estacion\/[0-9A-Z]{4,6}$/, vigencia: 30 * MIN, reserva: 6 * HORA },
  // Predicción horaria de un municipio (código INE de 5 cifras).
  { re: /^\/prediccion\/especifica\/municipio\/horaria\/\d{5}$/, vigencia: HORA, reserva: DIA },
  // Maestros (listas de municipios y estaciones): casi no cambian.
  { re: /^\/maestro\/municipios$/, vigencia: 7 * DIA, reserva: 30 * DIA, espera: 45 },
  { re: /^\/valores\/climatologicos\/inventarioestaciones\/todasestaciones$/, vigencia: 7 * DIA, reserva: 30 * DIA, espera: 45 },
];

const PREFIJO = "/tiempo";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return error(405, "Método no permitido");
    }
    if (!url.pathname.startsWith(PREFIJO + "/")) return error(404, "No existe");
    const ruta = url.pathname.slice(PREFIJO.length);
    const regla = RUTAS.find((r) => r.re.test(ruta));
    if (!regla) return error(404, "Consulta no permitida");
    if (!env.AEMET_API_KEY) return error(503, "Falta la clave de AEMET");

    // La clave de caché no lleva parámetros: `?x=1` no se salta la caché.
    const clave = new Request(`https://cache.lat41lab.com${PREFIJO}${ruta}`);
    const cache = caches.default;
    const guardada = await cache.match(clave);
    const edad = guardada ? (Date.now() - Number(guardada.headers.get("x-guardado") || 0)) / 1000 : Infinity;

    if (guardada && edad < regla.vigencia) {
      return paraLaApp(await guardada.text(), regla.vigencia - edad, "HIT");
    }

    try {
      const texto = await deAemet(ruta, env.AEMET_API_KEY, (regla.espera ?? 15) * 1000);
      const copia = new Response(texto, {
        headers: {
          "content-type": "application/json; charset=utf-8",
          "x-guardado": String(Date.now()),
          // Lo que dura en la caché de Cloudflare: la vigencia más la reserva.
          "cache-control": `public, max-age=${regla.vigencia + regla.reserva}`,
        },
      });
      ctx.waitUntil(cache.put(clave, copia));
      return paraLaApp(texto, regla.vigencia, "MISS");
    } catch (e) {
      console.log(`AEMET ${ruta}: ${e.message}`);
      if (guardada && edad < regla.vigencia + regla.reserva) {
        // Mejor un dato de hace un rato que ninguno; la app lo pedirá otra vez pronto.
        return paraLaApp(await guardada.text(), 5 * MIN, "STALE");
      }
      return error(e.ocupado ? 503 : 502, `AEMET no responde (${e.message})`, e.ocupado ? 60 : undefined);
    }
  },
};

/** Los dos pasos de AEMET; devuelve el JSON final como texto UTF-8. */
async function deAemet(ruta, clave, espera) {
  const meta = await fetch(AEMET + ruta, {
    headers: { api_key: clave, accept: "application/json" },
    signal: AbortSignal.timeout(15000),
  });
  // AEMET contesta 401 o 429 cuando la clave pasa de su límite por minuto.
  if (meta.status === 429 || meta.status === 401) throw fallo("límite de peticiones", true);
  if (!meta.ok) throw fallo(`HTTP ${meta.status}`, meta.status >= 500);
  const m = await meta.json();
  // AEMET a veces responde 200 con el error en `estado`.
  if (m.estado === 429) throw fallo("límite de peticiones", true);
  if (!m.datos) throw fallo(m.descripcion || `estado ${m.estado}`);

  const datos = await fetch(m.datos, { signal: AbortSignal.timeout(espera) });
  if (!datos.ok) throw fallo(`datos: HTTP ${datos.status}`, datos.status >= 500);
  const texto = new TextDecoder("iso-8859-1").decode(await datos.arrayBuffer());
  JSON.parse(texto); // que no se guarde en caché algo que no es JSON
  return texto;
}

function fallo(mensaje, ocupado = false) {
  const e = new Error(mensaje);
  e.ocupado = ocupado;
  return e;
}

function paraLaApp(texto, segundos, estado) {
  return new Response(texto, {
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": `public, max-age=${Math.max(60, Math.round(segundos))}`,
      "x-cache": estado,
    },
  });
}

function error(estado, mensaje, reintentar) {
  return new Response(JSON.stringify({ error: mensaje }), {
    status: estado,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...(reintentar ? { "retry-after": String(reintentar) } : {}),
    },
  });
}
