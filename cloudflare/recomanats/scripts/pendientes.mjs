// Lista los pagos que llegaron sin local (client_reference_id): `npm run pendientes`.
import { execFileSync } from "node:child_process";

const wr = (...a) => execFileSync("npx", ["wrangler", ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
const claves = JSON.parse(wr("kv", "key", "list", "--binding", "PRIVADO", "--remote", "--prefix", "sin_local:"));
if (!claves.length) {
  console.log("No hay pagos sin asignar.");
} else {
  for (const { name } of claves) {
    const d = JSON.parse(wr("kv", "key", "get", "--binding", "PRIVADO", "--remote", name));
    console.log(`${d.fecha ?? "?"}  ${d.empresa || "(sin nombre)"}  <${d.correo || "sin correo"}>  suscripción ${d.suscripcion ?? "-"}  (${name})`);
  }
}
