#!/bin/sh
# Installe Bonk depuis packages.bonk-os.app avec le gestionnaire du système, comme le ferait un utilisateur.
set -eu
U=https://packages.bonk-os.app
if command -v apt-get > /dev/null; then
  apt-get update -q
  apt-get install -yq curl ca-certificates
  install -d /etc/apt/keyrings
  curl -fsSL "$U/bonk.gpg" -o /etc/apt/keyrings/bonk.gpg
  echo "deb [signed-by=/etc/apt/keyrings/bonk.gpg] $U/debian stable main" > /etc/apt/sources.list.d/bonk.list
  apt-get update -q
  apt-get install -yq --no-install-recommends bonk
elif command -v zypper > /dev/null; then
  zypper --non-interactive --gpg-auto-import-keys addrepo "$U/rpm/x86_64" bonk
  rpm --import "$U/bonk.asc"
  zypper --non-interactive --gpg-auto-import-keys install --no-recommends bonk
elif command -v dnf > /dev/null; then
  curl -fsSL "$U/rpm/bonk.repo" -o /etc/yum.repos.d/bonk.repo
  dnf install -y --setopt=install_weak_deps=False bonk
elif command -v pacman > /dev/null; then
  pacman-key --init
  curl -fsSL "$U/bonk.asc" -o /tmp/bonk.asc
  pacman-key --add /tmp/bonk.asc
  pacman-key --lsign-key 8DE680FFBE475B663E8B019A757866E34D67014B
  printf '\n[bonk]\nSigLevel = Required\nServer = %s/arch/$arch\n' "$U" >> /etc/pacman.conf
  pacman -Sy --noconfirm bonk
else
  apk add --no-cache curl
  curl -fsSL "$U/install.sh" | sh
  PATH="$HOME/.local/bin:$PATH"
fi
bonk --version
