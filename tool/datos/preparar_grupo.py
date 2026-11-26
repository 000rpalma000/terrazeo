#!/usr/bin/env python3
"""Prepara el .osm.pbf de un grupo de ciudades de ciudades.json.

Uso:
    python3 tool/datos/preparar_grupo.py tool/datos/ciudades.json gb-leeds trabajo/
    # → trabajo/grupo.osm.pbf, listo para generar_teselas.py --grupo gb-leeds

1. Descarga de Geofabrik los extractos del grupo y comprueba su MD5.
2. Si son varios, los junta (`osmium merge`).
3. Recorta la caja de cada ciudad, con margen (`osmium extract`), y junta
   los recortes: el generador lee solo eso, unos pocos MB por ciudad.

Necesita `osmium` (osmium-tool) y `curl`.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

GEOFABRIK = "https://download.geofabrik.de/"
AGENTE = "lat41lab-datos (GitHub Actions)"
MARGEN = 0.02  # grados alrededor de cada caja: calles que entran desde fuera
# Geofabrik a veces rechaza conexiones si llegan muchas a la vez: reintentos
# con espera, también ante "connection refused".
CURL = ["curl", "-sSfL", "--retry", "10", "--retry-delay", "60", "--retry-all-errors",
        "-A", AGENTE]


def run(*cmd: str) -> None:
    print("+", " ".join(cmd), file=sys.stderr)
    subprocess.run(cmd, check=True)


def md5(p: Path) -> str:
    h = hashlib.md5()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main() -> None:
    ciudades_json, grupo, trabajo = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    ciudades = [c for c in json.loads(ciudades_json.read_text()) if c["grupo"] == grupo]
    if not ciudades:
        sys.exit(f"no hay ciudades del grupo {grupo}")
    trabajo.mkdir(parents=True, exist_ok=True)

    extractos = sorted({e for c in ciudades for e in c["extractos"]})
    fuentes = []
    for k, ruta in enumerate(extractos):
        destino = trabajo / f"fuente{k}.osm.pbf"
        run(*CURL, "-o", str(destino), GEOFABRIK + ruta)
        esperado = subprocess.run(
            [*CURL, GEOFABRIK + ruta + ".md5"],
            check=True, capture_output=True, text=True).stdout.split()[0]
        if md5(destino) != esperado:
            sys.exit(f"MD5 distinto en {ruta}")
        fuentes.append(destino)

    if len(fuentes) > 1:
        fuente = trabajo / "fuentes.osm.pbf"
        unidas = trabajo / "unidas.osm.pbf"
        run("osmium", "merge", "--overwrite", "-o", str(unidas), *map(str, fuentes))
        # Geofabrik actualiza cada país a una hora distinta: un objeto de la
        # frontera puede venir en dos versiones (Austria + Eslovaquia) y
        # osmium extract lo rechaza ("Node ID twice in input"). time-filter
        # deja solo la versión vigente, la más nueva, de cada objeto.
        run("osmium", "time-filter", "--overwrite", "-o", str(fuente), str(unidas))
        unidas.unlink()
    else:
        fuente = fuentes[0]

    # Un recorte por ciudad, de uno en uno: varios a la vez sobre un
    # extracto grande (Ucrania, 7 ciudades) agotan la memoria del runner.
    recortes = []
    for c in ciudades:
        s, w, n, e = c["caja"]
        salida_c = trabajo / f"ciudad_{c['id']}.osm.pbf"
        run("osmium", "extract", "--overwrite", "--strategy", "complete_ways",
            "-b", f"{w - MARGEN},{s - MARGEN},{e + MARGEN},{n + MARGEN}",
            "-o", str(salida_c), str(fuente))
        recortes.append(str(salida_c))
    salida = trabajo / "grupo.osm.pbf"
    if len(recortes) > 1:
        run("osmium", "merge", "--overwrite", "-o", str(salida), *recortes)
    else:
        Path(recortes[0]).replace(salida)

    # El generador toma la fecha de los datos de la cabecera del extracto.
    fecha = subprocess.run(["osmium", "fileinfo", "-g", "header.option.osmosis_replication_timestamp",
                            str(fuentes[0])], capture_output=True, text=True).stdout.strip()
    (trabajo / "fecha_osm.txt").write_text(fecha)
    for f in fuentes + ([fuente] if fuente not in fuentes else []):
        f.unlink()  # libera disco antes de generar
    print(f"{grupo}: {', '.join(c['id'] for c in ciudades)} → {salida} "
          f"({salida.stat().st_size / 1e6:.0f} MB)", file=sys.stderr)


if __name__ == "__main__":
    main()
