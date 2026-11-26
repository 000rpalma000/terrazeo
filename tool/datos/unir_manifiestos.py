#!/usr/bin/env python3
"""Junta los manifiestos parciales de cada grupo de ciudades en uno solo.

Uso:
    python3 tool/datos/unir_manifiestos.py ciudades.json partes/ salida/manifest.json \\
        [--anterior manifest_actual.json]

- Cada tarea de la acción mensual genera un grupo (ciudades que comparten
  extracto de Geofabrik) y deja su `manifest.json` parcial.
- Si un grupo falla un mes, se conservan su cobertura y sus cuadrículas del
  manifiesto anterior (las cuadrículas siguen en R2): así esa ciudad no pasa
  a Overpass por un fallo puntual.
- Falla (sin escribir nada) si no hay ningún parcial, para no publicar un
  manifiesto vacío.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path


def dentro(clave: str, rects: list[dict]) -> bool:
    i, j = (int(x) for x in clave.split("_"))
    return any(r["i0"] <= i <= r["i1"] and r["j0"] <= j <= r["j1"] for r in rects)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("ciudades", type=Path)
    ap.add_argument("partes", type=Path, help="carpeta con los manifest.json parciales (en subcarpetas)")
    ap.add_argument("salida", type=Path)
    ap.add_argument("--anterior", type=Path, help="manifiesto publicado ahora (opcional)")
    a = ap.parse_args()

    grupos = {c["grupo"] for c in json.loads(a.ciudades.read_text())}
    parciales = [json.loads(p.read_text()) for p in sorted(a.partes.rglob("manifest.json"))]
    if not parciales:
        sys.exit("no hay manifiestos parciales")

    cobertura, cuadriculas, fechas, hechos = [], {}, [], set()
    for m in parciales:
        cobertura += m["cobertura"]
        cuadriculas.update(m["cuadriculas"])
        if m.get("datos_osm"):
            fechas.append(m["datos_osm"])
        hechos |= {c.get("g", "") for c in m["cobertura"]}

    faltan = sorted(grupos - hechos)
    if faltan and a.anterior and a.anterior.exists():
        viejo = json.loads(a.anterior.read_text())
        for g in faltan:
            # Sin "g": el manifiesto de antes de las ciudades (solo Barcelona).
            rects = [c for c in viejo.get("cobertura", [])
                     if c.get("g", "es-barcelona") == g]
            if not rects:
                continue
            for c in rects:
                c["g"] = g
            cobertura += rects
            cuadriculas.update({k: v for k, v in viejo.get("cuadriculas", {}).items()
                                if dentro(k, rects)})
            print(f"{g}: sin datos nuevos, se conserva el mes anterior", file=sys.stderr)
    elif faltan:
        print(f"sin datos (y sin manifiesto anterior): {', '.join(faltan)}", file=sys.stderr)

    base = parciales[0]
    manifiesto = {
        "v": base["v"],
        "generado": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "datos_osm": min(fechas) if fechas else "",
        "fuente": base["fuente"],
        "tam": base["tam"],
        "cobertura": cobertura,
        "cuadriculas": dict(sorted(cuadriculas.items())),
    }
    a.salida.parent.mkdir(parents=True, exist_ok=True)
    a.salida.write_text(json.dumps(manifiesto, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(cobertura)} zonas, {len(cuadriculas)} cuadrículas, "
          f"{len(hechos)} grupos nuevos de {len(grupos)}", file=sys.stderr)


if __name__ == "__main__":
    main()
