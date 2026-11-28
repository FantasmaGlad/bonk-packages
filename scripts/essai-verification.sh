#!/bin/sh
# Usage: essai-verification.sh <install.sh>
# Needs gpg and a provenance tool (gh signed in, or cosign with jq): the genuine release installs with both
# checks passed, a substituted archive and a modified SHA256SUMS are refused.
set -eu
script=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
ici=$(cd "$(dirname "$0")" && pwd)
version=$(curl -fsSL https://packages.bonk-os.app/version.txt)
release="https://github.com/FantasmaGlad/Bonk/releases/download/v$version"
miroir="https://gitlab.com/api/v4/projects/89566133/packages/generic/bonk/$version"
travail=$(mktemp -d)
serveur=
arreter() { if [ -n "$serveur" ]; then kill "$serveur" 2> /dev/null || true; fi; }
trap 'arreter; rm -rf "$travail"' EXIT

installer() {
  remplacements=$1
  shift
  arreter
  python3 "$ici/release-locale.py" 8089 "$release" "$remplacements" "$@" &
  serveur=$!
  sleep 1
  maison=$(mktemp -d "$travail/maison.XXXXXX")
  HOME=$maison BONK_INSTALL_DIR=$maison/bin BONK_RELEASE_URL=http://127.0.0.1:8089 SHELL=/bin/sh \
    sh "$script" > "$travail/sortie" 2>&1
}

attendre() {
  if ! grep -qF "$1" "$travail/sortie"; then
    cat "$travail/sortie" >&2
    echo "ERREUR : « $1 » absent de la sortie de $2" >&2
    exit 1
  fi
}

# The signature of releases published before it was joined on GitHub lives on the GitLab mirror.
mkdir "$travail/vraie"
curl -fsSL "$release/SHA256SUMS" -o "$travail/vraie/SHA256SUMS"
for f in SHA256SUMS.asc bonk-release-key.asc; do
  curl -fsSL "$release/$f" -o "$travail/vraie/$f" 2> /dev/null || curl -fsSL "$miroir/$f" -o "$travail/vraie/$f"
done

installer "$travail/vraie" || { cat "$travail/sortie" >&2; echo "ERREUR : la vraie release est refusée" >&2; exit 1; }
attendre "signed by the Bonk release key" "la vraie release"
attendre "built by the release workflow" "la vraie release"
archive=$(sed -n 's/^\(bonk-cli-[^ ]*\.tar\.gz\) built by .*/\1/p' "$travail/sortie")
echo "OK vraie release : signature et provenance de $archive vérifiées"

mkdir "$travail/archive"
curl -fsSL "$release/$archive" -o "$travail/archive/$archive"
printf 'x' >> "$travail/archive/$archive"
if command -v sha256sum > /dev/null; then somme="sha256sum"; else somme="shasum -a 256"; fi
(cd "$travail/archive" && $somme "$archive") > "$travail/archive/SHA256SUMS"
if installer "$travail/archive" SHA256SUMS.asc; then
  cat "$travail/sortie" >&2
  echo "ERREUR : archive substituée installée" >&2
  exit 1
fi
attendre "has no provenance attestation" "l'archive substituée"
echo "OK archive substituée, SHA256SUMS recalculé : refusée"

mkdir "$travail/sommes"
cp "$travail/vraie/SHA256SUMS.asc" "$travail/vraie/bonk-release-key.asc" "$travail/sommes/"
awk 'NR == 1 { $0 = (substr($0, 1, 1) == "0" ? "1" : "0") substr($0, 2) } { print }' "$travail/vraie/SHA256SUMS" \
  > "$travail/sommes/SHA256SUMS"
if installer "$travail/sommes"; then
  cat "$travail/sortie" >&2
  echo "ERREUR : SHA256SUMS modifié accepté" >&2
  exit 1
fi
attendre "is not signed by the Bonk release key" "SHA256SUMS modifié"
echo "OK SHA256SUMS modifié sous une vraie signature : refusé"
