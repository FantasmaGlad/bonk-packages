#!/bin/sh
# Installe la version de Bonk sans fenêtre pour cet utilisateur, sans droits d'administrateur.
# Usage : curl -fsSL https://packages.bonk-os.app/install.sh | sh
set -eu

DOSSIER="${BONK_INSTALL_DIR:-$HOME/.local/bin}"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) cible=linux-x86_64 ;;
  Linux-aarch64 | Linux-arm64) cible=linux-aarch64 ;;
  Darwin-x86_64) cible=macos-x86_64 ;;
  Darwin-arm64) cible=macos-aarch64 ;;
  *) echo "Unsupported system: $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac
version=$(curl -fsSL https://packages.bonk-os.app/version.txt)
base="https://github.com/FantasmaGlad/Bonk/releases/download/v$version"
travail=$(mktemp -d)
trap 'rm -rf "$travail"' EXIT
curl -fsSL "$base/SHA256SUMS" -o "$travail/SHA256SUMS"
archive="bonk-cli-$version-$cible.tar.gz"
curl -fsSL "$base/$archive" -o "$travail/$archive"
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
