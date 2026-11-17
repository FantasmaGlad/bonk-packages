#!/usr/bin/env python3
"""Usage: liens.py <tag vX.Y.Z> <site directory>

Writes download/<name without version>/index.html for each asset of the release: a stable address that
forwards to the latest file, so links in READMEs and pages never name a version.
"""
import html
import json
import re
import subprocess
import sys
from pathlib import Path

DEPOT = "FantasmaGlad/Bonk"


def stable(nom: str, version: str) -> str:
    """bonk-0.1.0-linux-x86_64.tar.gz, bonk_0.1.0-1_amd64.deb: the name with its version and release removed."""
    return re.sub(rf"[-_]{re.escape(version)}(-1)?", "", nom)


def page(cible: str) -> str:
    adresse = html.escape(cible, quote=True)
    return (
        '<!doctype html>\n<meta charset="utf-8">\n<title>Bonk</title>\n'
        f'<meta http-equiv="refresh" content="0; url={adresse}">\n'
        f'<link rel="canonical" href="{adresse}">\n<a href="{adresse}">{adresse}</a>\n'
    )


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    tag, site = sys.argv[1], Path(sys.argv[2])
    version = tag.removeprefix("v")
    sortie = subprocess.run(
        ["gh", "release", "view", tag, "--repo", DEPOT, "--json", "assets"],
        check=True, capture_output=True, text=True,
    ).stdout
    noms = [asset["name"] for asset in json.loads(sortie)["assets"]]
    vus: dict[str, str] = {}
    for nom in noms:
        cle = stable(nom, version)
        if cle in vus:
            raise SystemExit(f"deux fichiers pour {cle} : {vus[cle]}, {nom}")
        vus[cle] = nom
        dossier = site / "download" / cle
        dossier.mkdir(parents=True, exist_ok=True)
        cible = f"https://github.com/{DEPOT}/releases/download/{tag}/{nom}"
        (dossier / "index.html").write_text(page(cible), encoding="utf-8")
    print(f"{len(vus)} liens stables vers {tag}")


if __name__ == "__main__":
    main()
