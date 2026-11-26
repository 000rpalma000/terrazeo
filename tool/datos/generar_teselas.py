#!/usr/bin/env python3
"""Genera los datos propios de Lat41 Lab (edificios, calles y locales) por
cuadrículas a partir de un extracto de OpenStreetMap de Geofabrik.

Sustituye a Overpass en las zonas cubiertas: los archivos se suben a R2 y se
sirven desde https://data.lat41lab.com/osm/v1/. Formato en FORMATO.md.

Uso:
    python3 tool/datos/generar_teselas.py cataluna-latest.osm.pbf salida/
    python3 tool/datos/generar_teselas.py extracto.pbf salida/ --zona barcelona \\
        --bares assets/data/bares.json

Necesita `pip install osmium` (pyosmium 4).
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

import osmium

VERSION = 1

# Cuadrícula fija: la misma que Tesela en las dos apps.
TAM_LAT = 0.005
TAM_LON = 0.0066

# Zonas cubiertas [sur, oeste, norte, este]. Añadir una ciudad = una línea.
ZONAS = {
    "barcelona": (41.317, 2.052, 41.469, 2.229),
}

# Los mismos filtros que las consultas a Overpass de las apps.
# Vías: unión de las de Terrazeo (espacio público) y Alombra (caminables);
# cada app filtra luego las suyas.
VIAS = set(
    "footway path pedestrian living_street steps residential service "
    "unclassified tertiary tertiary_link secondary secondary_link track road "
    "cycleway".split()
)
OCIO = {"park", "garden", "common", "playground"}
RE_BARES = re.compile(r"^(bar|pub|cafe|restaurant|biergarten|fast_food|ice_cream)$")
# Valores de outdoor_seating que significan "tiene terraza".
TERRAZA_SI = {"yes", "terrace", "sidewalk", "street", "pedestrian_zone", "parklet", "only"}
FOOT_NO = {"no", "private"}
ACCESS_NO = {"private", "no"}

# Etiquetas que se guardan de cada edificio (las que usa el estimador de
# alturas de las apps).
TAGS_EDIFICIO = ("building", "height", "building:height", "building:levels", "roof:levels")


def tesela(lat: float, lon: float) -> tuple[int, int]:
    return math.floor(lat / TAM_LAT), math.floor(lon / TAM_LON)


def teselas_caja(s: float, w: float, n: float, e: float):
    i0, j0 = tesela(s, w)
    i1, j1 = tesela(n, e)
    for i in range(i0, i1 + 1):
        for j in range(j0, j1 + 1):
            yield i, j


def coords_compactas(pts: list[tuple[float, float]]) -> list[int]:
    """[lat0, lon0, dlat1, dlon1, …] en millonésimas de grado."""
    q = [(round(lat * 1e6), round(lon * 1e6)) for lat, lon in pts]
    plano = [q[0][0], q[0][1]]
    for (a0, a1), (b0, b1) in zip(q, q[1:]):
        plano += [b0 - a0, b1 - a1]
    return plano


class Recolector:
    def __init__(self, caja: tuple[float, float, float, float]):
        s, w, n, e = caja
        # Margen de una cuadrícula: vías que entran desde fuera de la zona.
        self.s, self.w = s - TAM_LAT, w - TAM_LON
        self.n, self.e = n + TAM_LAT, e + TAM_LON
        self.cob = {
            "i0": tesela(s, w)[0], "j0": tesela(s, w)[1],
            "i1": tesela(n, e)[0], "j1": tesela(n, e)[1],
        }
        self.vias: dict[tuple[int, int], list] = defaultdict(list)
        self.bares: dict[tuple[int, int], list] = defaultdict(list)
        self.filas_bares: list[list] = []
        self.cuenta = defaultdict(int)

    def en_cobertura(self, i: int, j: int) -> bool:
        c = self.cob
        return c["i0"] <= i <= c["i1"] and c["j0"] <= j <= c["j1"]

    def dentro(self, lat: float, lon: float) -> bool:
        return self.s <= lat <= self.n and self.w <= lon <= self.e

    # --- Locales -----------------------------------------------------------

    def bar(self, tipo: str, ident: int, lat: float, lon: float, tags) -> None:
        amenity = tags.get("amenity", "")
        outdoor = tags.get("outdoor_seating", "").strip().lower()
        if outdoor in TERRAZA_SI or amenity == "biergarten":
            terraza = 1
        elif outdoor == "no":
            terraza = -1
        else:
            terraza = 0  # sin etiqueta: terraza sin confirmar
        fila = [
            f"{tipo}/{ident}",
            round(lat, 6),
            round(lon, 6),
            tags.get("name", ""),
            amenity,
            terraza,
            tags.get("opening_hours", "").strip(),
        ]
        i, j = tesela(lat, lon)
        if self.en_cobertura(i, j):
            self.bares[(i, j)].append(fila)
            self.filas_bares.append(fila)
            self.cuenta["bares"] += 1

    def nodo(self, n) -> None:
        if not n.location.valid() or not RE_BARES.match(n.tags.get("amenity", "")):
            return
        lat, lon = n.location.lat, n.location.lon
        if self.dentro(lat, lon):
            self.bar("node", n.id, lat, lon, n.tags)

    # --- Vías ----------------------------------------------------------------

    def via(self, w) -> None:
        tags = w.tags
        try:
            pts = [(nd.location.lat, nd.location.lon) for nd in w.nodes]
        except osmium.InvalidLocationError:
            return
        if len(pts) < 2 or not any(self.dentro(la, lo) for la, lo in pts):
            return
        lats = [p[0] for p in pts]
        lons = [p[1] for p in pts]
        s, n, oe, e = min(lats), max(lats), min(lons), max(lons)
        centro = ((s + n) / 2, (oe + e) / 2)

        if RE_BARES.match(tags.get("amenity", "")):
            self.bar("way", w.id, centro[0], centro[1], tags)
            if "building" not in tags:
                return

        hw = tags.get("highway")
        if "building" in tags:
            if len(pts) < 3:
                return
            tg = {k: tags[k] for k in TAGS_EDIFICIO if k in tags}
            elem = [w.id, "b", tg, 0, coords_compactas(pts)]
            destino = [tesela(*centro)]  # una sola: por su centro
            self.cuenta["edificios"] += 1
        elif hw in VIAS and tags.get("foot") not in FOOT_NO and tags.get("access") not in ACCESS_NO:
            tg = {"highway": hw}
            if tags.get("area") == "yes":
                tg["area"] = "yes"
            elem = [w.id, "h", tg, [nd.ref for nd in w.nodes], coords_compactas(pts)]
            # En todas las que toca su caja: así ninguna calle larga se corta.
            destino = list(teselas_caja(s, oe, n, e))
            self.cuenta["vias"] += 1
        elif tags.get("leisure") in OCIO or tags.get("place") == "square":
            tg = {"leisure": tags["leisure"]} if "leisure" in tags else {"place": "square"}
            elem = [w.id, "a", tg, 0, coords_compactas(pts)]
            destino = [tesela(*centro)]
            self.cuenta["areas"] += 1
        else:
            return
        for t in destino:
            if self.en_cobertura(*t):
                self.vias[t].append(elem)


def generar(pbf: Path, salida: Path, zona: str, bares_json: Path | None) -> None:
    caja = ZONAS[zona]
    rec = Recolector(caja)
    t0 = time.time()
    claves = ("building", "highway", "leisure", "place", "amenity")
    fp = (
        osmium.FileProcessor(str(pbf), osmium.osm.NODE | osmium.osm.WAY)
        .with_locations()
        .with_filter(osmium.filter.KeyFilter(*claves))
    )
    for obj in fp:
        if obj.is_node():
            rec.nodo(obj)
        elif obj.is_way():
            rec.via(obj)
    print(f"leído en {time.time() - t0:.0f} s: {dict(rec.cuenta)}", file=sys.stderr)

    fecha_osm = osmium.io.Reader(str(pbf), osmium.osm.NOTHING).header().get(
        "osmosis_replication_timestamp", "")
    destino = salida / "osm" / f"v{VERSION}"
    destino.mkdir(parents=True, exist_ok=True)
    huellas: dict[str, str] = {}
    total = 0
    for t in sorted(set(rec.vias) | set(rec.bares)):
        clave = f"{t[0]}_{t[1]}"
        cuerpo = json.dumps(
            {"v": VERSION, "t": clave, "w": rec.vias.get(t, []), "n": rec.bares.get(t, [])},
            ensure_ascii=False, separators=(",", ":"),
        ).encode()
        (destino / f"{clave}.json").write_bytes(cuerpo)
        huellas[clave] = hashlib.sha1(cuerpo).hexdigest()[:12]
        total += len(cuerpo)

    manifiesto = {
        "v": VERSION,
        "generado": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "datos_osm": fecha_osm,
        "fuente": "© colaboradores de OpenStreetMap (ODbL) · extracto de Geofabrik",
        "tam": [TAM_LAT, TAM_LON],
        # Toda cuadrícula dentro de "cobertura" que no esté en "cuadriculas"
        # está vacía (mar, montaña): no hace falta pedirla a ningún sitio.
        "cobertura": [rec.cob],
        "cuadriculas": huellas,
    }
    (destino / "manifest.json").write_text(
        json.dumps(manifiesto, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(huellas)} cuadrículas, {total / 1e6:.1f} MB en {destino}", file=sys.stderr)

    if bares_json:
        filas = sorted(rec.filas_bares, key=lambda f: f[0])
        s, w, n, e = caja
        bares_json.write_text(json.dumps(
            {"generado": dt.date.today().isoformat(), "bbox": [s, w, n, e], "bares": filas},
            ensure_ascii=False, separators=(",", ":")))
        print(f"{len(filas)} locales en {bares_json}", file=sys.stderr)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pbf", type=Path, help="extracto .osm.pbf de Geofabrik")
    ap.add_argument("salida", type=Path, help="carpeta de salida")
    ap.add_argument("--zona", default="barcelona", choices=sorted(ZONAS))
    ap.add_argument("--bares", type=Path, help="reescribe también este bares.json")
    a = ap.parse_args()
    generar(a.pbf, a.salida, a.zona, a.bares)


if __name__ == "__main__":
    main()
