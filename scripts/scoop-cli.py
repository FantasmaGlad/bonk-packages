#!/usr/bin/env python3
"""Écrit le manifeste Scoop de bonk-cli d'après le fichier SHA256SUMS d'une release.

Usage : scoop-cli.py <SHA256SUMS> <version>
"""
import json
import re
import sys
from pathlib import Path

chemin, version = Path(sys.argv[1]), sys.argv[2]
empreintes = {}
for ligne in chemin.read_text(encoding="utf-8").splitlines():
    m = re.fullmatch(r"([0-9a-f]{64}) [ *](\S+)", ligne.strip())
    if m:
        empreintes[m.group(2)] = m.group(1)


def entree(cible: str) -> dict[str, str]:
    dossier = f"bonk-cli-{version}-{cible}"
    return {
        "url": f"https://github.com/FantasmaGlad/Bonk/releases/download/v{version}/{dossier}.zip",
        "hash": empreintes[f"{dossier}.zip"],
        "extract_dir": dossier,
    }


print(
    json.dumps(
        {
            "version": version,
            "description": "Bonk without a window: bootable media writer, command line only.",
            "homepage": "https://bonk-os.app",
            "license": "MIT",
            "architecture": {
                "64bit": entree("windows-x86_64"),
                "arm64": entree("windows-aarch64"),
                "32bit": entree("windows-i686"),
            },
            "bin": "bonk.exe",
            "checkver": {"github": "https://github.com/FantasmaGlad/Bonk"},
        },
        indent=2,
    )
)
