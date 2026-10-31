#!/bin/sh
# Installe la version de Bonk sans fenêtre pour cet utilisateur, sans droits d'administrateur.
# Usage : curl -fsSL https://packages.bonk-os.app/install.sh | sh
set -eu

DOSSIER="${BONK_INSTALL_DIR:-$HOME/.local/bin}"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) cible=linux-x86_64-musl ;;
  Linux-aarch64 | Linux-arm64) cible=linux-aarch64-musl ;;
  Darwin-x86_64) cible=cli-macos-x86_64 ;;
  Darwin-arm64) cible=cli-macos-aarch64 ;;
  *) echo "Unsupported system: $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac
version=$(curl -fsSL https://packages.bonk-os.app/version.txt)
case "$cible" in
  cli-*) archive="bonk-cli-$version-${cible#cli-}.tar.gz" ;;
  *) archive="bonk-$version-$cible.tar.gz" ;;
esac
base="https://github.com/FantasmaGlad/Bonk/releases/download/v$version"
travail=$(mktemp -d)
trap 'rm -rf "$travail"' EXIT
curl -fsSL "$base/$archive" -o "$travail/$archive"
curl -fsSL "$base/SHA256SUMS" -o "$travail/SHA256SUMS"
(
  cd "$travail"
  grep " $archive\$" SHA256SUMS > attendu
  if command -v sha256sum > /dev/null; then sha256sum -c attendu > /dev/null; else shasum -a 256 -c attendu > /dev/null; fi
  tar -xzf "$archive"
)
mkdir -p "$DOSSIER"
install -m 755 "$travail"/bonk-*/bonk "$DOSSIER/bonk"
"$DOSSIER/bonk" --version
case ":$PATH:" in
  *":$DOSSIER:"*) ;;
  *) echo "Add $DOSSIER to your PATH." ;;
esac
