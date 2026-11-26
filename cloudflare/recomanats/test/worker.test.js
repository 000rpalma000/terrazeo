// Pruebas sin red ni Cloudflare: `npm test`.
import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import worker from "../src/index.js";

const SECRETO = "whsec_prueba";
let r2, kv, env;

// R2 falso con etags (para la escritura condicionada).
function nuevoR2() {
  const objetos = new Map();
  let version = 0;
  return {
    objetos,
    async get(k) {
      const o = objetos.get(k);
      return o ? { etag: o.etag, json: async () => JSON.parse(o.cuerpo) } : null;
    },
    async put(k, cuerpo, op = {}) {
      const actual = objetos.get(k);
      if (op.onlyIf?.etagMatches && actual?.etag !== op.onlyIf.etagMatches) return null;
      objetos.set(k, { cuerpo, etag: `e${++version}`, meta: op.httpMetadata });
      return { etag: `e${version}` };
    },
  };
}
function nuevoKV() {
  const m = new Map();
  return {
    m,
    async get(k, tipo) { const v = m.get(k); return v == null ? null : tipo === "json" ? JSON.parse(v) : v; },
    async put(k, v) { m.set(k, v); },
  };
}

beforeEach(() => {
  r2 = nuevoR2();
  kv = nuevoKV();
  env = { STRIPE_WEBHOOK_SECRET: SECRETO, DATOS: r2, PRIVADO: kv, AVISOS_A: "hola@lat41lab.com", AVISOS_DE: "avisos@lat41lab.com" };
});

let n = 0;
async function enviar(type, object, { firma = true, t = Math.floor(Date.now() / 1000) } = {}) {
  const cuerpo = JSON.stringify({ id: `evt_${++n}`, type, data: { object } });
  const v1 = createHmac("sha256", SECRETO).update(`${t}.${cuerpo}`).digest("hex");
  const headers = firma ? { "stripe-signature": `t=${t},v1=${v1}` } : {};
  return worker.fetch(new Request("https://pagos.lat41lab.com/stripe/webhook", { method: "POST", body: cuerpo, headers }), env, {});
}
const locales = () => JSON.parse(r2.objetos.get("recomanats.json").cuerpo).locales;
const s = (fecha) => Math.floor(new Date(fecha).getTime() / 1000);

test("rechaza firmas falsas, ausentes o viejas", async () => {
  assert.equal((await enviar("invoice.paid", {}, { firma: false })).status, 400);
  assert.equal((await enviar("invoice.paid", {}, { t: Math.floor(Date.now() / 1000) - 3600 })).status, 400);
  const cuerpo = JSON.stringify({ id: "evt_x", type: "invoice.paid", data: { object: {} } });
  const r = await worker.fetch(new Request("https://pagos.lat41lab.com/stripe/webhook",
    { method: "POST", body: cuerpo, headers: { "stripe-signature": `t=${Math.floor(Date.now() / 1000)},v1=00` } }), env, {});
  assert.equal(r.status, 400);
  assert.equal(r2.objetos.size, 0);
});

test("alta: checkout + factura → activo hasta el fin del periodo pagado", async () => {
  await enviar("checkout.session.completed", {
    id: "cs_1", client_reference_id: "node_123", subscription: "sub_1", customer: "cus_1",
    customer_details: { name: "Bar Pepe", email: "pepe@example.com" },
  });
  let l = locales();
  assert.equal(l.length, 1);
  assert.equal(l[0].osm, "node/123");
  assert.equal(l[0].estado, "activo");
  // Lo público no lleva datos de Stripe ni del cliente.
  const pub = r2.objetos.get("recomanats.json").cuerpo;
  assert.ok(!pub.includes("cus_1") && !pub.includes("sub_1") && !pub.includes("pepe@"));
  assert.equal(r2.objetos.get("recomanats.json").meta.cacheControl, "public, max-age=300");

  await enviar("invoice.paid", { subscription: "sub_1", lines: { data: [{ period: { end: s("2027-01-26T10:00:00Z") } }] } });
  assert.equal(locales()[0].fin, "2027-01-26T10:00:00.000Z");
  // Formato nuevo de la API (parent.subscription_details).
  await enviar("invoice.paid", { parent: { subscription_details: { subscription: "sub_1" } }, lines: { data: [{ period: { end: s("2027-02-26T10:00:00Z") } }] } });
  assert.equal(locales()[0].fin, "2027-02-26T10:00:00.000Z");
});

test("la factura puede llegar antes que el checkout", async () => {
  await enviar("invoice.paid", { subscription: "sub_2", lines: { data: [{ period: { end: s("2027-01-01T00:00:00Z") } }] } });
  assert.equal(r2.objetos.size, 0);
  await enviar("checkout.session.completed", { id: "cs_2", client_reference_id: "way_77", subscription: "sub_2" });
  assert.equal(locales()[0].osm, "way/77");
  assert.equal(locales()[0].fin, "2027-01-01T00:00:00.000Z");
});

test("baja: conserva lo pagado; si se corta antes, hasta el corte", async () => {
  await enviar("checkout.session.completed", { id: "cs_3", client_reference_id: "node_5", subscription: "sub_3" });
  await enviar("invoice.paid", { subscription: "sub_3", lines: { data: [{ period: { end: s("2027-03-01T00:00:00Z") } }] } });
  await enviar("customer.subscription.updated", { id: "sub_3", status: "unpaid" });
  assert.equal(locales()[0].estado, "baja");
  assert.equal(locales()[0].fin, "2027-03-01T00:00:00.000Z");
  await enviar("customer.subscription.deleted", { id: "sub_3", status: "canceled", ended_at: s("2027-02-10T00:00:00Z") });
  assert.equal(locales()[0].fin, "2027-02-10T00:00:00.000Z");
});

test("respeta nombre, foto y texto puestos a mano", async () => {
  await r2.put("recomanats.json", JSON.stringify({ v: 1, locales: [
    { osm: "node/9", nombre: "Bar Nou", foto: "https://data.lat41lab.com/fotos/9.jpg", texto: { ca: "Terrassa!" }, estado: "baja", fin: "2026-01-01T00:00:00.000Z" },
  ] }));
  await enviar("checkout.session.completed", { id: "cs_4", client_reference_id: "node_9", subscription: "sub_4" });
  const l = locales()[0];
  assert.equal(l.nombre, "Bar Nou");
  assert.equal(l.texto.ca, "Terrassa!");
  assert.equal(l.estado, "activo");
  assert.ok(l.fin > "2026-11-01");
});

test("pago sin local: no toca la lista y deja un aviso", async () => {
  await enviar("checkout.session.completed", {
    id: "cs_5", subscription: "sub_5", customer_details: { business_name: "Cafè del Mar SL", email: "x@example.com" },
  });
  assert.equal(r2.objetos.size, 0);
  const aviso = [...kv.m.entries()].find(([k]) => k.startsWith("aviso:"));
  assert.ok(aviso && aviso[1].includes("Cafè del Mar SL"));
  assert.ok(kv.m.has("sin_local:sub_5"));
});

test("un evento repetido se procesa una sola vez", async () => {
  const cuerpo = JSON.stringify({ id: "evt_rep", type: "checkout.session.completed",
    data: { object: { id: "cs_6", client_reference_id: "node_6", subscription: "sub_6" } } });
  const t = Math.floor(Date.now() / 1000);
  const v1 = createHmac("sha256", SECRETO).update(`${t}.${cuerpo}`).digest("hex");
  const pedir = () => worker.fetch(new Request("https://pagos.lat41lab.com/stripe/webhook",
    { method: "POST", body: cuerpo, headers: { "stripe-signature": `t=${t},v1=${v1}` } }), env, {});
  await pedir();
  const r = await (await pedir()).json();
  assert.equal(r.repetido, true);
  assert.equal(locales().length, 1);
});

test("escrituras simultáneas no se pisan", async () => {
  await Promise.all([
    enviar("checkout.session.completed", { id: "a", client_reference_id: "node_1", subscription: "s_a" }),
    enviar("checkout.session.completed", { id: "b", client_reference_id: "node_2", subscription: "s_b" }),
    enviar("checkout.session.completed", { id: "c", client_reference_id: "node_3", subscription: "s_c" }),
  ]);
  assert.deepEqual(locales().map((l) => l.osm).sort(), ["node/1", "node/2", "node/3"]);
});
