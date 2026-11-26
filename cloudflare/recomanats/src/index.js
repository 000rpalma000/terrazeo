// Webhooks de Stripe para "Recomanat per Terrazeo": https://pagos.lat41lab.com/stripe/webhook
//
// Mantiene recomanats.json en R2 (público: lo lee la app desde
// data.lat41lab.com/recomanats.json). Solo guarda ahí datos públicos del
// local; la relación suscripción → local va en KV (PRIVADO), que no es
// público.
//
// - checkout.session.completed: alta. El local llega en client_reference_id
//   (node_123 → node/123). Si no llega, se guarda en KV (sin_local:…) para
//   asignarlo a mano; Stripe ya avisa por correo de cada pago.
// - invoice.paid: amplía la fecha de fin hasta el final del periodo pagado.
// - customer.subscription.deleted / .updated (impago, cancelada): estado
//   "baja"; sigue recomendado hasta la fecha de fin ya pagada y luego deja
//   de serlo solo (la app solo enseña los que tienen fin > ahora).
//
// Secretos (wrangler secret put): STRIPE_WEBHOOK_SECRET (el del webhook de
// prueba de Stripe) y STRIPE_WEBHOOK_SECRET_LIVE (el del real). Se acepta
// la firma de cualquiera de los dos.
//
// Los eventos de prueba (livemode: false) van a recomanats_prueba.json y a
// claves de KV con el prefijo "prueba:"; nunca tocan la lista real, que es
// la que lee la app.

/** Dónde guardar según el modo del evento: real o de prueba. */
export const modo = (evento) => evento?.livemode === true
  ? { objeto: "recomanats.json", pre: "" }
  : { objeto: "recomanats_prueba.json", pre: "prueba:" };
const TOLERANCIA_S = 300; // firma de Stripe: como mucho 5 min de diferencia
const DIA = 24 * 3600 * 1000;
const RE_REF = /^(node|way|relation)_(\d{1,15})$/;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/stripe/salud") return json({ ok: true });
    if (url.pathname !== "/stripe/webhook") return json({ error: "No existe" }, 404);
    if (request.method !== "POST") return json({ error: "Método no permitido" }, 405);
    const secretos = [env.STRIPE_WEBHOOK_SECRET, env.STRIPE_WEBHOOK_SECRET_LIVE].filter(Boolean);
    if (!secretos.length) return json({ error: "Falta el secreto del webhook" }, 500);

    const cuerpo = await request.text();
    const firma = request.headers.get("stripe-signature");
    const ahora = Math.floor(Date.now() / 1000);
    let ok = false;
    for (const s of secretos) ok ||= await firmaValida(firma, cuerpo, s, ahora);
    if (!ok) return json({ error: "Firma no válida" }, 400);

    const evento = JSON.parse(cuerpo);
    // Stripe puede repetir un evento: cada uno se procesa una vez.
    const visto = `${modo(evento).pre}evento:${evento.id}`;
    if (await env.PRIVADO.get(visto)) return json({ ok: true, repetido: true });
    await procesar(evento, env);
    await env.PRIVADO.put(visto, "1", { expirationTtl: 30 * 24 * 3600 });
    return json({ ok: true });
  },
};

export async function procesar(evento, env) {
  const o = evento.data?.object ?? {};
  const { objeto, pre } = modo(evento);
  switch (evento.type) {
    case "checkout.session.completed": {
      const sub = idDe(o.subscription);
      const cd = o.customer_details ?? {};
      const m = RE_REF.exec(o.client_reference_id ?? "");
      if (!m) {
        const datos = {
          empresa: cd.business_name || cd.name || "", correo: cd.email || "",
          sesion: o.id, suscripcion: sub, referencia: o.client_reference_id ?? null,
        };
        datos.fecha = new Date().toISOString();
        await env.PRIVADO.put(`${pre}sin_local:${sub ?? o.id}`, JSON.stringify(datos));
        console.log(`Pago sin local: ${JSON.stringify(datos)}`);
        return;
      }
      const osm = `${m[1]}/${m[2]}`;
      if (sub) await env.PRIVADO.put(`${pre}sub:${sub}`, JSON.stringify({ osm, cliente: idDe(o.customer) }));
      // Si la factura llegó antes que el checkout, ya sabemos hasta cuándo.
      const pagado = sub ? await env.PRIVADO.get(`${pre}pago:${sub}`) : null;
      const fin = pagado ?? new Date(Date.now() + 31 * DIA).toISOString();
      await actualizar(env, osm, (l) => ({ ...l, estado: "activo", fin: masTarde(l.fin, fin) }), objeto);
      return;
    }
    case "invoice.paid": {
      const sub = idDe(o.subscription ?? o.parent?.subscription_details?.subscription);
      if (!sub) return;
      const finS = Math.max(0, ...((o.lines?.data ?? []).map((l) => l.period?.end ?? 0)));
      if (!finS) return;
      const fin = new Date(finS * 1000).toISOString();
      const enlace = await env.PRIVADO.get(`${pre}sub:${sub}`, "json");
      if (!enlace) {
        await env.PRIVADO.put(`${pre}pago:${sub}`, fin, { expirationTtl: 7 * 24 * 3600 });
        return;
      }
      await actualizar(env, enlace.osm, (l) => ({ ...l, estado: "activo", fin: masTarde(l.fin, fin) }), objeto);
      return;
    }
    case "customer.subscription.deleted":
    case "customer.subscription.updated": {
      const enlace = await env.PRIVADO.get(`${pre}sub:${o.id}`, "json");
      if (!enlace) {
        // Un pago sin local que se cancela ya no hay que asignarlo.
        if (evento.type === "customer.subscription.deleted") {
          await env.PRIVADO.delete(`${pre}sin_local:${o.id}`);
        }
        return;
      }
      const baja = evento.type === "customer.subscription.deleted" ||
        ["unpaid", "canceled", "incomplete_expired"].includes(o.status);
      if (!baja) {
        if (o.status === "active") await actualizar(env, enlace.osm, (l) => ({ ...l, estado: "activo" }), objeto);
        return;
      }
      // Sigue hasta el final de lo pagado; si se cortó antes (cancelación
      // inmediata), hasta ese momento.
      const corte = o.ended_at ? new Date(o.ended_at * 1000).toISOString() : null;
      await actualizar(env, enlace.osm, (l) => ({
        ...l, estado: "baja", fin: corte && l.fin ? masTemprano(l.fin, corte) : (l.fin ?? corte),
      }), objeto);
      return;
    }
    default:
      return; // invoice.payment_failed y el resto: nada (la fecha de fin manda)
  }
}

/** Lee recomanats.json, aplica [cambio] al local y lo guarda sin pisar
 *  cambios simultáneos (escritura condicionada a la versión leída). */
export async function actualizar(env, osm, cambio, objeto = "recomanats.json") {
  for (let intento = 0; intento < 5; intento++) {
    const obj = await env.DATOS.get(objeto);
    const datos = obj ? await obj.json() : { v: 1, locales: [] };
    const i = datos.locales.findIndex((l) => l.osm === osm);
    const antes = i >= 0 ? datos.locales[i] : { osm, nombre: "", foto: null, texto: {} };
    const despues = cambio(antes);
    if (i >= 0) datos.locales[i] = despues; else datos.locales.push(despues);
    datos.actualizado = new Date().toISOString();
    const opciones = {
      httpMetadata: { contentType: "application/json; charset=utf-8", cacheControl: "public, max-age=300" },
    };
    if (obj) opciones.onlyIf = { etagMatches: obj.etag };
    const r = await env.DATOS.put(objeto, JSON.stringify(datos, null, 1), opciones);
    if (r) return despues;
  }
  throw new Error("recomanats.json cambia demasiado a la vez");
}

/** Firma de Stripe: HMAC-SHA256 de "t.cuerpo" con el secreto del webhook. */
export async function firmaValida(cabecera, cuerpo, secreto, ahoraS) {
  if (!cabecera) return false;
  const partes = cabecera.split(",").map((p) => p.trim().split("="));
  const t = partes.find(([k]) => k === "t")?.[1];
  const firmas = partes.filter(([k]) => k === "v1").map(([, v]) => v);
  if (!t || !firmas.length || Math.abs(ahoraS - Number(t)) > TOLERANCIA_S) return false;
  const clave = await crypto.subtle.importKey("raw", new TextEncoder().encode(secreto),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", clave, new TextEncoder().encode(`${t}.${cuerpo}`)));
  const esperado = [...mac].map((b) => b.toString(16).padStart(2, "0")).join("");
  return firmas.some((f) => igualSeguro(f, esperado));
}

function igualSeguro(a, b) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

const idDe = (x) => (typeof x === "string" ? x : x?.id ?? null);
const masTarde = (a, b) => (!a ? b : !b ? a : a > b ? a : b);
const masTemprano = (a, b) => (a < b ? a : b);
const json = (d, estado = 200) => new Response(JSON.stringify(d), {
  status: estado, headers: { "content-type": "application/json; charset=utf-8" },
});
