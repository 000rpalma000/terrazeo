#!/usr/bin/env python3
"""Genera assets/data/bares.json con los bares/cafés/restaurantes de una zona.

La app lo carga al arrancar para pintar la capa de locales al instante, sin
esperar a Overpass (que a menudo tarda 30 s o más). Fuera de esta zona la app
sigue pidiendo los locales a Overpass como antes.

Uso (desde la raíz del repo):
    python3 tool/generar_bares.py            # Barcelona y alrededores
    python3 tool/generar_bares.py S W N E    # otra caja (grados)

Conviene regenerarlo antes de cada publicación (los locales cambian). Datos
© colaboradores de OpenStreetMap, licencia ODbL (atribución ya en Acerca de).

Formato (compacto, una fila por local):
    {"generado": "2026-11-22", "bbox": [S, W, N, E],
     "bares": [["node/123", lat, lon, "Nombre", "bar", 1], ...]}
La última columna es 1 si tiene terraza declarada (outdoor_seating) o 0.
"""

import datetime
import json
import pathlib
import sys
import urllib.parse
import urllib.request

# Barcelona + L'Hospitalet, Badalona, Sant Adrià, Esplugues, Sant Just.
BBOX_POR_DEFECTO = (41.317, 2.052, 41.469, 2.229)

AMENITIES = "bar|pub|cafe|restaurant|biergarten|fast_food|ice_cream"
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
SALIDA = pathlib.Path(__file__).resolve().parent.parent / "assets/data/bares.json"


def descargar(bbox):
    s, w, n, e = bbox
    query = (
        f"[out:json][timeout:180];"
        f'nwr["amenity"~"^({AMENITIES})$"]({s},{w},{n},{e});'
        f"out center tags;"
    )
    body = urllib.parse.urlencode({"data": query}).encode()
    ultimo_error = None
    for ep in ENDPOINTS:
        try:
            req = urllib.request.Request(
                ep, data=body, headers={"User-Agent": "terrazeo-datos/1.0"}
            )
            with urllib.request.urlopen(req, timeout=240) as r:
                return json.load(r)
        except Exception as ex:  # prueba el siguiente servidor
            print(f"  {ep}: {ex}", file=sys.stderr)
            ultimo_error = ex
    raise SystemExit(f"Ningún servidor Overpass respondió: {ultimo_error}")


def main():
    bbox = tuple(map(float, sys.argv[1:5])) if len(sys.argv) == 5 else BBOX_POR_DEFECTO
    print(f"Descargando locales en {bbox}…")
    data = descargar(bbox)

    filas = []
    for el in data.get("elements", []):
        tags = el.get("tags") or {}
        lat = el.get("lat") or (el.get("center") or {}).get("lat")
        lon = el.get("lon") or (el.get("center") or {}).get("lon")
        if lat is None or lon is None:
            continue
        amenity = tags.get("amenity", "bar")
        outdoor = str(tags.get("outdoor_seating", "")).lower()
        terraza = 1 if outdoor in ("yes", "terrace") or amenity == "biergarten" else 0
        filas.append([
            f"{el['type']}/{el['id']}",
            round(lat, 6),
            round(lon, 6),
            tags.get("name", ""),
            amenity,
            terraza,
        ])

    filas.sort(key=lambda f: f[0])
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(
        json.dumps(
            {
                "generado": datetime.date.today().isoformat(),
                "bbox": list(bbox),
                "bares": filas,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    )
    print(f"{len(filas)} locales -> {SALIDA} ({SALIDA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
