#!/usr/bin/env python3
"""Usage: compteurs.py <ledger directory> [YYYY-MM-DD ...]

Counts the downloads of each channel on packages.bonk-os.app for each given UTC day (by default the days of
the last 30 not yet counted), from Cloudflare's request analytics, reads the downloads of Bonk's program files
on GitHub, then rewrites telechargements.json and the badges. Needs CLOUDFLARE_ANALYTICS_TOKEN and
CLOUDFLARE_ZONE_ID; GITHUB_TOKEN when set.
"""
import datetime
import ipaddress
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

HOTE = "packages.bonk-os.app"
GRAPHQL = "https://api.cloudflare.com/client/v4/graphql"
RELEASES = "https://api.github.com/repos/FantasmaGlad/Bonk/releases?per_page=100&page={}"
META = "https://api.github.com/meta"
LIMITE = 10000
PROGRAMME = r"bonk(-cli)?[-_][^/]+\.(tar\.gz|zip|exe|dmg|deb|rpm|pkg\.tar\.zst|apk)"
# Cloudflare keeps 31 days of request analytics.
JOURS_GARDES = 30
# A counted channel downloads through a 302 of /dl/<channel>/; a repository serves its packages itself.
CANAUX = {
    "homebrew": (302, re.compile(r"^/dl/homebrew/v[^/]+/bonk(-cli)?-[^/]+\.tar\.gz$")),
    "script": (302, re.compile(r"^/dl/script/v[^/]+/bonk-cli-[^/]+\.(tar\.gz|zip)$")),
    "scoop": (302, re.compile(r"^/dl/scoop/v[^/]+/bonk(-cli)?-[^/]+\.zip$")),
    "site": (302, re.compile(rf"^/dl/site/v[^/]+/{PROGRAMME}$")),
    "readme": (200, re.compile(rf"^/download/{PROGRAMME}/(index\.html)?$")),
    "apt": (200, re.compile(r"^/debian/pool/[^/]+\.deb$")),
    "rpm": (200, re.compile(r"^/rpm/[^/]+/[^/]+\.rpm$")),
    "pacman": (200, re.compile(r"^/arch/x86_64/[^/]+\.pkg\.tar\.zst$")),
    "termux": (200, re.compile(r"^/termux/pool/[^/]+\.deb$")),
}
# Served by the repositories themselves; the redirected channels reach GitHub and are in its count.
DEPOTS = ["apt", "rpm", "pacman", "termux"]
# Program files only: hash lists, signatures, keys and manifests are fetched along an install.
TYPES = {
    "archive": re.compile(r"^bonk(-cli)?-[^/]+\.(tar\.gz|zip)$"),
    "installer": re.compile(r"^bonk-[^/]+\.(exe|dmg)$"),
    "package": re.compile(r"^bonk(-cli)?[-_][^/]+\.(deb|rpm|pkg\.tar\.zst)$"),
    "android": re.compile(r"^bonk-[^/]+\.apk$"),
}
REQUETE = """query($zone: String!, $jour: Date!) { viewer { zones(filter: {zoneTag: $zone}) {
  httpRequestsAdaptiveGroups(limit: %d, filter: {date: $jour, clientRequestHTTPHost: "%s"}) {
    count dimensions { clientRequestPath edgeResponseStatus clientIP } } } } }""" % (LIMITE, HOTE)


def canal(chemin: str, statut: int) -> str | None:
    for nom, (attendu, motif) in CANAUX.items():
        if statut == attendu and motif.match(chemin):
            return nom
    return None


# The address is only compared with GitHub's published runner ranges, never kept.
def reseaux_actions() -> list[ipaddress.IPv4Network | ipaddress.IPv6Network]:
    requete = urllib.request.Request(META, headers={"User-Agent": "bonk-packages"})
    with urllib.request.urlopen(requete, timeout=60) as reponse:
        return [ipaddress.ip_network(plage) for plage in json.load(reponse)["actions"]]


def automatise(adresse: str, reseaux: list) -> bool:
    ip = ipaddress.ip_address(adresse)
    return any(ip in reseau for reseau in reseaux)


def compter(groupes: list[dict], reseaux: list) -> dict[str, dict[str, int]]:
    comptes = {"all": dict.fromkeys(CANAUX, 0), "devices": dict.fromkeys(CANAUX, 0)}
    for groupe in groupes:
        dimensions = groupe["dimensions"]
        nom = canal(dimensions["clientRequestPath"], dimensions["edgeResponseStatus"])
        if not nom:
            continue
        comptes["all"][nom] += groupe["count"]
        if not automatise(dimensions["clientIP"], reseaux):
            comptes["devices"][nom] += groupe["count"]
    return comptes


def interroger(jour: str) -> list[dict]:
    corps = json.dumps({"query": REQUETE, "variables": {"zone": os.environ["CLOUDFLARE_ZONE_ID"], "jour": jour}})
    requete = urllib.request.Request(GRAPHQL, data=corps.encode(), headers={
        "Authorization": "Bearer " + os.environ["CLOUDFLARE_ANALYTICS_TOKEN"], "Content-Type": "application/json"})
    with urllib.request.urlopen(requete, timeout=60) as reponse:
        donnees = json.load(reponse)
    if donnees.get("errors"):
        raise SystemExit(f"ERREUR Cloudflare {jour} : {donnees['errors']}")
    groupes = donnees["data"]["viewer"]["zones"][0]["httpRequestsAdaptiveGroups"]
    if len(groupes) >= LIMITE:
        raise SystemExit(f"ERREUR Cloudflare {jour} : {LIMITE} groupes, relevé tronqué")
    return groupes


def type_github(nom: str) -> str | None:
    return next((genre for genre, motif in TYPES.items() if motif.match(nom)), None)


def lire_github() -> dict[str, int]:
    entetes = {"Accept": "application/vnd.github+json", "User-Agent": "bonk-packages"}
    if os.environ.get("GITHUB_TOKEN"):
        entetes["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    fichiers: dict[str, int] = {}
    for page in range(1, 100):
        requete = urllib.request.Request(RELEASES.format(page), headers=entetes)
        with urllib.request.urlopen(requete, timeout=60) as reponse:
            releases = json.load(reponse)
        for release in releases:
            for fichier in release["assets"]:
                if type_github(fichier["name"]):
                    fichiers[fichier["name"]] = fichier["download_count"]
        if len(releases) < 100:
            break
    return fichiers


# A deleted release takes its counters with it on GitHub: the ledger keeps the highest count seen per file.
def garder_github(dossier: Path, lus: dict[str, int]) -> dict[str, int]:
    chemin = dossier / "github.json"
    gardes = json.loads(chemin.read_text()) if chemin.exists() else {}
    for nom, nombre in lus.items():
        gardes[nom] = max(gardes.get(nom, 0), nombre)
    chemin.write_text(json.dumps(dict(sorted(gardes.items())), indent=1) + "\n")
    return gardes


def compact(nombre: int) -> str:
    for seuil, suffixe in ((1_000_000, "M"), (1_000, "k")):
        if nombre >= seuil:
            return f"{nombre / seuil:.1f}".rstrip("0").rstrip(".") + suffixe
    return str(nombre)


def badge(dossier: Path, nom: str, libelle: str, nombre: int) -> None:
    endpoint = {"schemaVersion": 1, "label": libelle, "message": compact(nombre), "color": "brightgreen"}
    (dossier / f"{nom}.json").write_text(json.dumps(endpoint) + "\n")


# A day counted before devices were told apart holds one flat count, from before the proxy: nothing to split.
def lire_jour(fichier: Path) -> dict[str, dict[str, int]]:
    jour = json.loads(fichier.read_text())
    return jour if "all" in jour else {"all": jour, "devices": jour}


def ecrire_totaux(dossier: Path, github: dict[str, int]) -> dict:
    canaux = dict.fromkeys(CANAUX, 0)
    appareils = dict.fromkeys(CANAUX, 0)
    jours = sorted((dossier / "jours").glob("*.json"))
    for fichier in jours:
        jour = lire_jour(fichier)
        for nom, nombre in jour["all"].items():
            canaux[nom] = canaux.get(nom, 0) + nombre
        for nom, nombre in jour["devices"].items():
            appareils[nom] = appareils.get(nom, 0) + nombre
    par_type = dict.fromkeys(TYPES, 0)
    for nom, nombre in github.items():
        genre = type_github(nom)
        if genre:
            par_type[genre] += nombre
    depots = sum(canaux[nom] for nom in DEPOTS)
    resume = {
        "counted_until": jours[-1].stem if jours else None,
        "total": sum(par_type.values()) + depots,
        "github": {"total": sum(par_type.values()), **par_type},
        "repositories": depots,
        "channels": canaux,
        "devices": {"total": sum(appareils.values()), **appareils},
    }
    (dossier / "telechargements.json").write_text(json.dumps(resume, indent=1) + "\n")
    badge(dossier, "total", "Downloads", resume["total"])
    badge(dossier, "homebrew", "Homebrew downloads", canaux["homebrew"])
    badge(dossier, "paquets", "Downloads", depots + canaux["script"] + canaux["scoop"])
    return resume


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
    reseaux = reseaux_actions()
    for jour in jours:
        comptes = compter(interroger(jour), reseaux)
        (dossier / "jours" / f"{jour}.json").write_text(json.dumps(comptes, indent=1) + "\n")
        print(jour, comptes)
    (dossier / "totaux.json").unlink(missing_ok=True)
    print(json.dumps(ecrire_totaux(dossier, garder_github(dossier, lire_github()))))


if __name__ == "__main__":
    main()
