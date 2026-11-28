#!/usr/bin/env python3
"""Usage: compteurs.py <ledger directory> [YYYY-MM-DD ...]

Counts the downloads of each channel on packages.bonk-os.app for each given UTC day (by default the days of
the last 30 not yet counted), from Cloudflare's request analytics, then rewrites the totals and the badges.
Needs CLOUDFLARE_ANALYTICS_TOKEN and CLOUDFLARE_ZONE_ID.
"""
import datetime
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

HOTE = "packages.bonk-os.app"
GRAPHQL = "https://api.cloudflare.com/client/v4/graphql"
# Cloudflare keeps 31 days of request analytics.
JOURS_GARDES = 30
# A counted channel downloads through a 302 of /dl/<channel>/; a repository serves its packages itself.
CANAUX = {
    "homebrew": (302, re.compile(r"^/dl/homebrew/v[^/]+/bonk(-cli)?-[^/]+\.tar\.gz$")),
    "script": (302, re.compile(r"^/dl/script/v[^/]+/bonk-cli-[^/]+\.(tar\.gz|zip)$")),
    "scoop": (302, re.compile(r"^/dl/scoop/v[^/]+/bonk(-cli)?-[^/]+\.zip$")),
    "apt": (200, re.compile(r"^/debian/pool/[^/]+\.deb$")),
    "rpm": (200, re.compile(r"^/rpm/[^/]+/[^/]+\.rpm$")),
    "pacman": (200, re.compile(r"^/arch/x86_64/[^/]+\.pkg\.tar\.zst$")),
    "termux": (200, re.compile(r"^/termux/pool/[^/]+\.deb$")),
}
BADGES = {
    "homebrew": ("Homebrew downloads", ["homebrew"]),
    "paquets": ("Downloads", ["apt", "rpm", "pacman", "termux", "script", "scoop"]),
}
REQUETE = """query($zone: String!, $jour: Date!) { viewer { zones(filter: {zoneTag: $zone}) {
  httpRequestsAdaptiveGroups(limit: 10000, filter: {date: $jour, clientRequestHTTPHost: "%s"}) {
    count dimensions { clientRequestPath edgeResponseStatus } } } } }""" % HOTE


def canal(chemin: str, statut: int) -> str | None:
    for nom, (attendu, motif) in CANAUX.items():
        if statut == attendu and motif.match(chemin):
            return nom
    return None


def compter(groupes: list[dict]) -> dict[str, int]:
    comptes = dict.fromkeys(CANAUX, 0)
    for groupe in groupes:
        dimensions = groupe["dimensions"]
        nom = canal(dimensions["clientRequestPath"], dimensions["edgeResponseStatus"])
        if nom:
            comptes[nom] += groupe["count"]
    return comptes


def interroger(jour: str) -> list[dict]:
    corps = json.dumps({"query": REQUETE, "variables": {"zone": os.environ["CLOUDFLARE_ZONE_ID"], "jour": jour}})
    requete = urllib.request.Request(GRAPHQL, data=corps.encode(), headers={
        "Authorization": "Bearer " + os.environ["CLOUDFLARE_ANALYTICS_TOKEN"], "Content-Type": "application/json"})
    with urllib.request.urlopen(requete, timeout=60) as reponse:
        donnees = json.load(reponse)
    if donnees.get("errors"):
        raise SystemExit(f"ERREUR Cloudflare {jour} : {donnees['errors']}")
    return donnees["data"]["viewer"]["zones"][0]["httpRequestsAdaptiveGroups"]


def compact(nombre: int) -> str:
    for seuil, suffixe in ((1_000_000, "M"), (1_000, "k")):
        if nombre >= seuil:
            return f"{nombre / seuil:.1f}".rstrip("0").rstrip(".") + suffixe
    return str(nombre)


def ecrire_totaux(dossier: Path) -> dict[str, int]:
    totaux = dict.fromkeys(CANAUX, 0)
    for fichier in sorted((dossier / "jours").glob("*.json")):
        for nom, nombre in json.loads(fichier.read_text()).items():
            totaux[nom] = totaux.get(nom, 0) + nombre
    (dossier / "totaux.json").write_text(json.dumps(totaux, indent=1) + "\n")
    for badge, (libelle, canaux) in BADGES.items():
        message = compact(sum(totaux[nom] for nom in canaux))
        endpoint = {"schemaVersion": 1, "label": libelle, "message": message, "color": "brightgreen"}
        (dossier / f"{badge}.json").write_text(json.dumps(endpoint) + "\n")
    return totaux


# Today is still being counted: only finished days, from the oldest Cloudflare keeps.
def jours_a_compter(dossier: Path, aujourd_hui: datetime.date) -> list[str]:
    jours = [(aujourd_hui - datetime.timedelta(days=ecart)).isoformat() for ecart in range(JOURS_GARDES, 0, -1)]
    return [jour for jour in jours if not (dossier / "jours" / f"{jour}.json").exists()]


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    dossier = Path(sys.argv[1])
    (dossier / "jours").mkdir(parents=True, exist_ok=True)
    jours = sys.argv[2:] or jours_a_compter(dossier, datetime.datetime.now(datetime.timezone.utc).date())
    for jour in jours:
        comptes = compter(interroger(jour))
        (dossier / "jours" / f"{jour}.json").write_text(json.dumps(comptes, indent=1) + "\n")
        print(jour, comptes)
    print("totaux", ecrire_totaux(dossier))


if __name__ == "__main__":
    main()
