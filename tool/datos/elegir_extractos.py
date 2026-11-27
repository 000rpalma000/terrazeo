#!/usr/bin/env python3
"""Recalcula en ciudades.json la caja, los extractos de Geofabrik y el grupo
de cada ciudad.

Uso (tras añadir o cambiar una ciudad: id, nombre, nombres {ca, es, en},
pais, centro, radio_km y venda_recomanats):
    curl -o /tmp/index-v1.json https://download.geofabrik.de/index-v1.json
    python3 tool/datos/elegir_extractos.py tool/datos/ciudades.json /tmp/index-v1.json

- caja: el cuadrado de lado 2 × radio_km alrededor del centro. Si la zona
  tiene "limites" (archivo de zonas/ hecho con zona_limites.py), la caja
  de ese archivo. Si radio_km es null y no hay límites, la caja escrita a
  mano.
- extractos: para cada punto de una rejilla sobre la caja (con margen), el
  extracto más pequeño de Geofabrik que lo contiene. Así una ciudad junto a
  una frontera usa los dos extractos pequeños y no el del continente.
- grupo: las ciudades que comparten algún extracto van juntas en una misma
  tarea de la acción mensual (y así sus cuadrículas no se pisan).
"""

from __future__ import annotations

import collections
import json
import math
import sys
from pathlib import Path

MARGEN = 0.02  # grados: vías que entran desde fuera de la caja
REJILLA = 6
TAM_LAT = 0.005  # cuadrícula de generar_teselas.py
TAM_LON = 0.0066


def anillos(g):
    return [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]


def dentro_pol(lon, lat, pol):
    res = False
    for r in pol:  # exterior y agujeros
        j = len(r) - 1
        for i in range(len(r)):
            xi, yi = r[i][:2]
            xj, yj = r[j][:2]
            if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
                res = not res
            j = i
    return res


def area(g):
    return sum(abs(sum(r[i][0] * r[i - 1][1] - r[i - 1][0] * r[i][1] for i in range(len(r)))) / 2
               for p in anillos(g) for r in p[:1])


def caja(lat, lon, r):
    dlat = r / 111.32
    dlon = r / (111.32 * math.cos(math.radians(lat)))
    return [round(lat - dlat, 4), round(lon - dlon, 4), round(lat + dlat, 4), round(lon + dlon, 4)]


def main() -> None:
    ruta, indice = Path(sys.argv[1]), Path(sys.argv[2])
    ciudades = json.loads(ruta.read_text())
    regiones = [f for f in json.loads(indice.read_text())["features"]
                if f.get("geometry") and ("/europe" in f["properties"]["urls"]["pbf"]
                                          or "/canary-islands" in f["properties"]["urls"]["pbf"])]
    for f in regiones:
        xs = [c[0] for p in anillos(f["geometry"]) for c in p[0]]
        ys = [c[1] for p in anillos(f["geometry"]) for c in p[0]]
        f["_bb"] = (min(xs), min(ys), max(xs), max(ys))
        f["_area"] = area(f["geometry"])
    regiones.sort(key=lambda f: f["_area"])  # de menor a mayor

    for c in ciudades:
        puntos = []
        if c.get("limites"):
            zona = json.loads((ruta.parent / c["limites"]).read_text())
            c["caja"] = zona["caja"]
            # Las esquinas de cada rectángulo de cuadrículas (con margen): no
            # el mar ni las comarcas de alrededor que entran en la caja.
            for i0, i1, j0, j1 in zona["rects"]:
                for i in (i0, i1 + 1):
                    for j in (j0, j1 + 1):
                        for di in (-MARGEN, MARGEN):
                            puntos.append((j * TAM_LON + di, i * TAM_LAT + di))
        else:
            if c.get("radio_km"):
                c["caja"] = caja(*c["centro"], c["radio_km"])
            s, w, n, e = c["caja"]
            for a in range(REJILLA + 1):
                for b in range(REJILLA + 1):
                    puntos.append((w - MARGEN + (e - w + 2 * MARGEN) * a / REJILLA,
                                   s - MARGEN + (n - s + 2 * MARGEN) * b / REJILLA))
        ext = set()
        for x, y in puntos:
            for f in regiones:
                bx = f["_bb"]
                if bx[0] <= x <= bx[2] and bx[1] <= y <= bx[3] and dentro_pol_multi(x, y, f):
                    ext.add(f["properties"]["urls"]["pbf"].split("download.geofabrik.de/")[1])
                    break
        c["extractos"] = sorted(ext)

    # Grupos: componentes conexas de "comparten algún extracto".
    padre = {c["id"]: c["id"] for c in ciudades}

    def raiz(x):
        while padre[x] != x:
            x = padre[x]
        return x

    por_ext = collections.defaultdict(list)
    for c in ciudades:
        for e in c["extractos"]:
            por_ext[e].append(c["id"])
    for ids in por_ext.values():
        for i in ids[1:]:
            padre[raiz(i)] = raiz(ids[0])
    primero = {}
    for c in ciudades:
        r = raiz(c["id"])
        primero.setdefault(r, c)
        c["grupo"] = f"{primero[r]['pais']}-{primero[r]['id']}"

    claves = ["id", "nombre", "nombres", "pais", "centro", "radio_km", "limites", "caja",
              "extractos", "grupo", "venda_recomanats"]
    opcionales = {"limites"}
    ruta.write_text("[\n" + ",\n".join(json.dumps({k: c.get(k) for k in claves
                                                   if k not in opcionales or c.get(k)},
                                                  ensure_ascii=False)
                                       for c in ciudades) + "\n]\n")
    print(f"{len(ciudades)} zonas, {len({c['grupo'] for c in ciudades})} grupos, "
          f"{len(por_ext)} extractos", file=sys.stderr)


def dentro_pol_multi(x, y, f):
    return any(dentro_pol(x, y, p) for p in anillos(f["geometry"]))


if __name__ == "__main__":
    main()
