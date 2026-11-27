#!/usr/bin/env python3
"""Genera ciutats.json: las ciudades que de verdad tienen datos propios.

Uso:
    python3 tool/datos/generar_ciutats.py tool/datos/ciudades.json manifest.json ciutats.json

Una ciudad entra si el manifiesto publicado tiene la cobertura de su grupo
y la cuadrícula de su centro está en ella (si un grupo falla un mes y no
hay copia anterior, o una ciudad nueva aún no se ha generado, no sale).
Lo usan las apps ("Ciutats disponibles", aviso fuera de cobertura y si se
vende "Recomanat" en esa ciudad) y la web lat41lab.com.

Formato:
    {"v": 1, "generado": "...", "ciutats": [
      {"id": "barcelona", "nom": {"ca": "Barcelona", "es": "...", "en": "..."},
       "pais": "es", "pais_nom": {"ca": "Espanya", "es": "España", "en": "Spain"},
       "centre": [41.39, 2.17], "caixa": [s, w, n, e], "venda_recomanats": true}, …]}
"""

from __future__ import annotations

import datetime as dt
import json
import math
import sys
from pathlib import Path

PAISOS = {
    "al": ("Albània", "Albania", "Albania"), "at": ("Àustria", "Austria", "Austria"),
    "be": ("Bèlgica", "Bélgica", "Belgium"), "bg": ("Bulgària", "Bulgaria", "Bulgaria"),
    "ch": ("Suïssa", "Suiza", "Switzerland"), "cy": ("Xipre", "Chipre", "Cyprus"),
    "cz": ("Txèquia", "Chequia", "Czechia"), "de": ("Alemanya", "Alemania", "Germany"),
    "dk": ("Dinamarca", "Dinamarca", "Denmark"), "ee": ("Estònia", "Estonia", "Estonia"),
    "es": ("Espanya", "España", "Spain"), "fi": ("Finlàndia", "Finlandia", "Finland"),
    "fr": ("França", "Francia", "France"), "gb": ("Regne Unit", "Reino Unido", "United Kingdom"),
    "gr": ("Grècia", "Grecia", "Greece"), "hr": ("Croàcia", "Croacia", "Croatia"),
    "hu": ("Hongria", "Hungría", "Hungary"), "ie": ("Irlanda", "Irlanda", "Ireland"),
    "it": ("Itàlia", "Italia", "Italy"), "lt": ("Lituània", "Lituania", "Lithuania"),
    "lu": ("Luxemburg", "Luxemburgo", "Luxembourg"), "lv": ("Letònia", "Letonia", "Latvia"),
    "md": ("Moldàvia", "Moldavia", "Moldova"), "mk": ("Macedònia del Nord", "Macedonia del Norte", "North Macedonia"),
    "mt": ("Malta", "Malta", "Malta"), "nl": ("Països Baixos", "Países Bajos", "Netherlands"),
    "no": ("Noruega", "Noruega", "Norway"), "pl": ("Polònia", "Polonia", "Poland"),
    "pt": ("Portugal", "Portugal", "Portugal"), "ro": ("Romania", "Rumanía", "Romania"),
    "rs": ("Sèrbia", "Serbia", "Serbia"), "se": ("Suècia", "Suecia", "Sweden"),
    "si": ("Eslovènia", "Eslovenia", "Slovenia"), "sk": ("Eslovàquia", "Eslovaquia", "Slovakia"),
    "ua": ("Ucraïna", "Ucrania", "Ukraine"),
}


def main() -> None:
    ciudades = json.loads(Path(sys.argv[1]).read_text())
    manifiesto = json.loads(Path(sys.argv[2]).read_text())
    # Sin "g": manifiesto de antes de las ciudades (solo Barcelona).
    cob = manifiesto.get("cobertura", [])
    con_datos = {c.get("g", "es-barcelona") for c in cob}
    tam_lat, tam_lon = manifiesto.get("tam", [0.005, 0.0066])

    def cubierta(lat: float, lon: float) -> bool:
        i, j = math.floor(lat / tam_lat), math.floor(lon / tam_lon)
        return any(r["i0"] <= i <= r["i1"] and r["j0"] <= j <= r["j1"] for r in cob)

    ciutats = []
    for c in ciudades:
        if c["grupo"] not in con_datos or not cubierta(*c["centro"]):
            continue
        ca, es, en = PAISOS[c["pais"]]
        ciutats.append({
            "id": c["id"],
            "nom": c["nombres"],
            "pais": c["pais"],
            "pais_nom": {"ca": ca, "es": es, "en": en},
            "centre": c["centro"],
            "caixa": c["caja"],
            "venda_recomanats": bool(c.get("venda_recomanats")),
        })
    salida = {
        "v": 1,
        "generado": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ciutats": ciutats,
    }
    Path(sys.argv[3]).write_text(json.dumps(salida, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(ciutats)} ciudades con datos de {len(ciudades)}", file=sys.stderr)


if __name__ == "__main__":
    main()
