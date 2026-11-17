#!/bin/sh
set -eu

# Termux: Bonk's package repository, so that pkg upgrade keeps it current.
if [ -n "${TERMUX_VERSION:-}" ] || [ "$(uname -o 2>/dev/null)" = Android ]; then
  mkdir -p "$PREFIX/etc/apt/trusted.gpg.d" "$PREFIX/etc/apt/sources.list.d"
  curl -fsSL https://packages.bonk-os.app/bonk.asc -o "$PREFIX/etc/apt/trusted.gpg.d/bonk.asc"
  echo "deb https://packages.bonk-os.app/termux stable main" > "$PREFIX/etc/apt/sources.list.d/bonk.list"
  pkg install -y bonk
  bonk --version
  echo "Drives are reached through termux-usb (Termux:API): termux-usb -r -E -e 'bonk list' <device from termux-usb -l>"
  exit 0
fi
systeme=$(uname -s)
DOSSIER="${BONK_INSTALL_DIR:-$HOME/.local/bin}"
case "$systeme-$(uname -m)" in
  Linux-x86_64) cible=linux-x86_64 ;;
  Linux-aarch64 | Linux-arm64) cible=linux-aarch64 ;;
  Linux-i686) cible=linux-i686 ;;
  Darwin-x86_64) cible=macos-x86_64 ;;
  Darwin-arm64) cible=macos-aarch64 ;;
  *) echo "Unsupported system: $systeme $(uname -m)" >&2; exit 1 ;;
esac
version=$(curl -fsSL https://packages.bonk-os.app/version.txt)
base="https://github.com/FantasmaGlad/Bonk/releases/download/v$version"
travail=$(mktemp -d)
trap 'rm -rf "$travail"' EXIT
curl -fsSL "$base/SHA256SUMS" -o "$travail/SHA256SUMS"
archive="bonk-cli-$version-$cible.tar.gz"
if ! grep -q " $archive\$" "$travail/SHA256SUMS"; then
  echo "Bonk $version has no build for $cible." >&2
  exit 1
fi
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
