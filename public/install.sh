#!/bin/sh
set -eu

# Termux runs the Android build: it reaches the drive through termux-usb.
if [ -n "${TERMUX_VERSION:-}" ] || [ "$(uname -o 2>/dev/null)" = Android ]; then
  systeme=Android
  DOSSIER="${BONK_INSTALL_DIR:-${PREFIX:-$HOME/.local}/bin}"
else
  systeme=$(uname -s)
  DOSSIER="${BONK_INSTALL_DIR:-$HOME/.local/bin}"
fi
case "$systeme-$(uname -m)" in
  Android-aarch64) cible=android-aarch64 ;;
  Android-x86_64) cible=android-x86_64 ;;
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
if [ "$systeme" = Android ]; then
  echo "Drives are reached through termux-usb (Termux:API): termux-usb -r -E -e 'bonk list' <device from termux-usb -l>"
fi
case ":$PATH:" in
  *":$DOSSIER:"*) ;;
  *) echo "Add $DOSSIER to your PATH." ;;
esac
