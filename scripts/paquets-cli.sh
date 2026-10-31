#!/usr/bin/env bash
# Emballe la version sans fenêtre d'une release en paquet bonk-cli : .deb, .rpm et pacman.
# Le binaire est statique, donc sans dépendance ; il remplace le paquet bonk, qui installe le même nom de commande.
# Usage : paquets-cli.sh <dossier de la release> <version>
set -euo pipefail

DOSSIER=$(realpath "$1")
VERSION=$2
RESUME="Bonk without a window: bootable media writer, command line only"
ADRESSE=https://github.com/FantasmaGlad/Bonk
travail=$(mktemp -d)
trap 'rm -rf "$travail"' EXIT

for arch in x86_64 aarch64; do
  archive=$(find "$DOSSIER" -maxdepth 1 \( -name "bonk-cli-$VERSION-linux-$arch.tar.gz" -o -name "bonk-$VERSION-linux-$arch-musl.tar.gz" \) | head -n 1)
  [ -n "$archive" ] || { echo "archive sans fenêtre absente : $VERSION $arch"; exit 1; }
  source="$travail/$arch"
  mkdir -p "$source"
  tar -xzf "$archive" -C "$source" --strip-components=1

  case "$arch" in x86_64) deb=amd64 ;; aarch64) deb=arm64 ;; esac
  racine="$travail/deb-$arch"
  mkdir -p "$racine/DEBIAN" "$racine/usr/bin" "$racine/usr/share/doc/bonk-cli"
  install -m 755 "$source/bonk" "$racine/usr/bin/bonk"
  install -m 644 "$source/LICENSE" "$racine/usr/share/doc/bonk-cli/copyright"
  cat > "$racine/DEBIAN/control" <<CONTROLE
Package: bonk-cli
Version: $VERSION-1
Architecture: $deb
Maintainer: FantasmaGlad <fanta@bonk-os.app>
Section: admin
Priority: optional
Homepage: https://bonk-os.app
Provides: bonk
Conflicts: bonk
Replaces: bonk
Description: $RESUME
CONTROLE
  dpkg-deb --root-owner-group --build "$racine" "$DOSSIER/bonk-cli_$VERSION-1_$deb.deb" > /dev/null

  cat > "$travail/bonk-cli.spec" <<SPEC
%global debug_package %{nil}
%global __os_install_post %{nil}
Name: bonk-cli
Version: $VERSION
Release: 1
Summary: $RESUME
License: MIT
URL: $ADRESSE
AutoReqProv: no
Provides: bonk = $VERSION
Conflicts: bonk

%description
$RESUME.

%install
install -Dm755 $source/bonk %{buildroot}/usr/bin/bonk
install -Dm644 $source/LICENSE %{buildroot}/usr/share/licenses/bonk-cli/LICENSE

%files
/usr/bin/bonk
/usr/share/licenses/bonk-cli/LICENSE
SPEC
  rpmbuild --quiet -bb --target "$arch" --define "_topdir $travail/rpm" "$travail/bonk-cli.spec"
  find "$travail/rpm/RPMS" -name '*.rpm' -exec mv -t "$DOSSIER" {} +
done

# pacman : x86_64 seul, comme le dépôt. Un paquet pacman est une archive avec son .PKGINFO en tête.
racine="$travail/pacman"
mkdir -p "$racine"
install -Dm755 "$travail/x86_64/bonk" "$racine/usr/bin/bonk"
install -Dm644 "$travail/x86_64/LICENSE" "$racine/usr/share/licenses/bonk-cli/LICENSE"
cat > "$racine/.PKGINFO" <<INFO
pkgname = bonk-cli
pkgbase = bonk-cli
pkgver = $VERSION-1
pkgdesc = $RESUME
url = $ADRESSE
builddate = $(date +%s)
packager = FantasmaGlad <fanta@bonk-os.app>
size = $(du -sb "$racine/usr" | cut -f1)
arch = x86_64
license = MIT
conflict = bonk
provides = bonk=$VERSION
INFO
tar --zstd --owner=0 --group=0 --numeric-owner -C "$racine" -cf "$DOSSIER/bonk-cli-$VERSION-1-x86_64.pkg.tar.zst" .PKGINFO usr
