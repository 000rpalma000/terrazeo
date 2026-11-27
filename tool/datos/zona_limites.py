#!/usr/bin/env python3
"""Convierte límites administrativos de OSM en la lista de cuadrículas que
cubre una zona (en lugar de una caja alrededor de un centro).

Uso (herramienta local; la tarea mensual solo lee el resultado):
    pip install shapely
    curl -LO https://download.geofabrik.de/europe/spain/cataluna/cataluna-latest.osm.pbf
    python3 tool/datos/zona_limites.py cataluna-latest.osm.pbf \\
        tool/datos/zonas/barcelona.json \\
        --nombre "Regió Metropolitana de Barcelona" \\
        --wikidata Q15348 Q15351 Q13948 Q14303 Q12600 Q15354 Q15355 \\
                   Q15407 Q15408 Q15418 Q15452 \\
        --caja-extra 41.317 2.052 41.469 2.229

- --wikidata: relaciones `boundary=administrative` que forman la zona (por
  su `wikidata`, que no cambia aunque cambie el nombre). Se unen.
- --caja-extra: una caja que se añade tal cual (la de Barcelona ciudad de
  antes, para no perder ninguna cuadrícula que ya se servía).
- Entra toda cuadrícula que toca la zona. Se guardan como rectángulos
  [i0, i1, j0, j1] (inclusive): tramos de cada fila, juntando las filas
  seguidas con el mismo tramo.

- contorno: el de la zona, ensanchado 300 m y simplificado (~100 m), para
  el aviso de "fuera de cobertura" de las apps (va en ciutats.json).
  Polígonos [lat0, lon0, lat1, lon1, …] con 4 decimales, solo el anillo
  exterior.

Los límites casi nunca cambian: basta con rehacerlo si cambia la zona.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from shapely.geometry import box, shape
from shapely.ops import unary_union
from shapely.prepared import prep

TAM_LAT = 0.005  # igual que generar_teselas.py y Tesela en las apps
TAM_LON = 0.0066


def limites(pbf: Path, qids: set[str]):
    with tempfile.TemporaryDirectory() as tmp:
        filtrado = Path(tmp) / "limites.osm.pbf"
        geo = Path(tmp) / "limites.geojsonseq"
        subprocess.run(["osmium", "tags-filter", "--overwrite", "-o", str(filtrado), str(pbf),
                        "r/boundary=administrative"], check=True)
        subprocess.run(["osmium", "export", "--overwrite", "-f", "geojsonseq", "-o", str(geo),
                        "--geometry-types=polygon", str(filtrado)], check=True)
        hallados = {}
        for linea in geo.read_text().split("\x1e"):
            if not linea.strip():
                continue
            f = json.loads(linea)
            q = f["properties"].get("wikidata")
            if q in qids:
                hallados[q] = (f["properties"].get("name", q), shape(f["geometry"]).buffer(0))
    faltan = qids - set(hallados)
    if faltan:
        sys.exit(f"no están en el extracto: {', '.join(sorted(faltan))}")
    return hallados


def rectangulos(celdas: set[tuple[int, int]]) -> list[list[int]]:
    # Tramos por fila.
    filas: dict[int, list[tuple[int, int]]] = {}
    for i in sorted({i for i, _ in celdas}):
        js = sorted(j for ii, j in celdas if ii == i)
        tramos, a = [], js[0]
        for x, y in zip(js, js[1:] + [None]):
            if y != x + 1:
                tramos.append((a, x))
                a = y
        filas[i] = tramos
    # Junta filas seguidas con el mismo tramo.
    abiertos: dict[tuple[int, int], int] = {}
    rects = []
    previas: set = set()
    for i in sorted(filas):
        actuales = set(filas[i])
        for t in previas - actuales:
            rects.append([abiertos.pop(t), i - 1, *t])
        for t in actuales - previas:
            abiertos[t] = i
        previas = actuales
        ultima = i
    for t, i0 in abiertos.items():
        rects.append([i0, ultima, *t])
    return sorted(rects)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pbf", type=Path)
    ap.add_argument("salida", type=Path)
    ap.add_argument("--nombre", required=True)
    ap.add_argument("--wikidata", nargs="+", required=True)
    ap.add_argument("--caja-extra", nargs=4, type=float, metavar=("S", "W", "N", "E"))
    a = ap.parse_args()

    partes = limites(a.pbf, set(a.wikidata))
    zona = unary_union([g for _, g in partes.values()])
    p = prep(zona)
    w, s, e, n = zona.bounds
    celdas = set()
    for i in range(math.floor(s / TAM_LAT), math.floor(n / TAM_LAT) + 1):
        for j in range(math.floor(w / TAM_LON), math.floor(e / TAM_LON) + 1):
            if p.intersects(box(j * TAM_LON, i * TAM_LAT, (j + 1) * TAM_LON, (i + 1) * TAM_LAT)):
                celdas.add((i, j))
    if a.caja_extra:
        cs, cw, cn, ce = a.caja_extra
        for i in range(math.floor(cs / TAM_LAT), math.floor(cn / TAM_LAT) + 1):
            for j in range(math.floor(cw / TAM_LON), math.floor(ce / TAM_LON) + 1):
                celdas.add((i, j))
        s, w, n, e = min(s, cs), min(w, cw), max(n, cn), max(e, ce)

    rects = rectangulos(celdas)
    simple = zona.buffer(0.003).simplify(0.001)
    contorno = [[round(v, 4) for x, y in pol.exterior.coords for v in (y, x)]
                for pol in getattr(simple, "geoms", [simple])]
    assert {(i, j) for i0, i1, j0, j1 in rects
            for i in range(i0, i1 + 1) for j in range(j0, j1 + 1)} == celdas
    km2 = zona.area * 111.32 ** 2 * math.cos(math.radians((s + n) / 2))
    a.salida.parent.mkdir(parents=True, exist_ok=True)
    a.salida.write_text(json.dumps({
        "nombre": a.nombre,
        "fuente": "límites administrativos de OpenStreetMap (ODbL), "
                  + dt.date.today().isoformat(),
        "partes": {q: nombre for q, (nombre, _) in sorted(partes.items())},
        "km2": round(km2),
        "caja": [round(s, 4), round(w, 4), round(n, 4), round(e, 4)],
        "cuadriculas": len(celdas),
        "rects": rects,
        "contorno": contorno,
    }, ensure_ascii=False, indent=1))
    print(f"{a.nombre}: {len(partes)} límites, {km2:.0f} km², {len(celdas)} cuadrículas "
          f"en {len(rects)} rectángulos, contorno de {sum(len(c) // 2 for c in contorno)} "
          f"puntos → {a.salida}", file=sys.stderr)


if __name__ == "__main__":
    main()
