#!/usr/bin/env python3
"""Deja en una carpeta aparte solo las cuadrículas que han cambiado desde el
manifiesto publicado, para subir solo esas a R2.

Uso:
    python3 tool/datos/cambiadas.py salida/osm/v1 anterior.json subir/osm/v1

- Compara la huella (SHA-1, 12 cifras) de cada cuadrícula nueva con la del
  manifiesto anterior. Las iguales ya están en R2 tal cual: no se suben.
- Si no hay manifiesto anterior (o no se puede leer), se suben todas.
- Las cuadrículas que dejan de existir se quedan en R2 sin usar: el
  manifiesto nuevo ya no las nombra y las apps no las piden.

Cada subida es una escritura (operación de clase A) en R2: subir solo las
cambiadas es ~15 % de las cuadrículas al mes en vez del 100 %.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path


def main() -> None:
    origen, anterior, destino = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    nuevo = json.loads((origen / "manifest.json").read_text())["cuadriculas"]
    try:
        viejo = json.loads(anterior.read_text())["cuadriculas"]
    except (OSError, ValueError, KeyError) as e:
        print(f"sin manifiesto anterior ({e}): se suben todas", file=sys.stderr)
        viejo = {}
    destino.mkdir(parents=True, exist_ok=True)
    cambiadas = [k for k, h in nuevo.items() if viejo.get(k) != h]
    for k in cambiadas:
        shutil.copy2(origen / f"{k}.json", destino / f"{k}.json")
    print(f"{len(cambiadas)} de {len(nuevo)} cuadrículas han cambiado "
          f"({100 * len(cambiadas) / max(len(nuevo), 1):.1f} %)", file=sys.stderr)


if __name__ == "__main__":
    main()
