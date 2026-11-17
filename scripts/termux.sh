#!/usr/bin/env bash
# Usage: termux.sh <directory of releases> <site directory>
# Termux APT repository: the Android command line, packaged under the Termux prefix.
set -euo pipefail
umask 022

ENTREE=$1
SITE=$2
PREFIXE=data/data/com.termux/files/usr
DEPOT="$SITE/termux"
travail=$(mktemp -d)
trap 'rm -rf "$travail"' EXIT

mkdir -p "$DEPOT/pool"
find "$ENTREE" -name 'bonk-cli-*-android-*.tar.gz' -print0 | while IFS= read -r -d '' archive; do
  nom=$(basename "$archive" .tar.gz)
  version=${nom#bonk-cli-}
  version=${version%-android-*}
  arch=${nom##*-android-}
  racine="$travail/$nom"
  mkdir -p "$racine/DEBIAN" "$racine/$PREFIXE/bin" "$racine/$PREFIXE/share/doc/bonk"
  tar -xzf "$archive" -C "$travail"
  install -m 755 "$travail/$nom/bonk" "$racine/$PREFIXE/bin/bonk"
  install -m 644 "$travail/$nom/LICENSE" "$racine/$PREFIXE/share/doc/bonk/copyright"
  rm -f "$travail/$nom/bonk" "$travail/$nom/LICENSE"
  cat > "$racine/DEBIAN/control" <<CONTROL
Package: bonk
Version: $version
Architecture: $arch
Maintainer: FantasmaGlad <security@bonk-os.app>
Depends: termux-api
Homepage: https://bonk-os.app
Description: Bootable media writer for USB drives, command line
 Writes bootable images to a USB drive plugged into the phone, through termux-usb.
CONTROL
  dpkg-deb --root-owner-group -Zxz --build "$racine" "$DEPOT/pool/bonk_${version}_$arch.deb" > /dev/null
done

(
  cd "$DEPOT"
  for arch in aarch64 x86_64; do
    mkdir -p "dists/stable/main/binary-$arch"
    dpkg-scanpackages --multiversion --arch "$arch" pool /dev/null > "dists/stable/main/binary-$arch/Packages"
    gzip -9kn "dists/stable/main/binary-$arch/Packages"
  done
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=Bonk \
    -o APT::FTPArchive::Release::Label=Bonk \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Components=main \
    -o "APT::FTPArchive::Release::Architectures=aarch64 x86_64" \
    release dists/stable > "$travail/Release"
  mv "$travail/Release" dists/stable/Release
  if [ -n "${GPG_KEY_ID:-}" ]; then
    gpg --batch --yes --local-user "$GPG_KEY_ID" --clearsign -o dists/stable/InRelease dists/stable/Release
    gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
  fi
)
