#!/bin/sh
set -eu
PUBLIC=https://packages.bonk-os.app
U=${BONK_DEPOT:-$PUBLIC}
EMPREINTE=${BONK_EMPREINTE:-8DE680FFBE475B663E8B019A757866E34D67014B}
# Le fichier .repo nomme l'adresse publique : le pointer sur l'arbre essayé.
repo_local() { sed "s#$PUBLIC#$U#g" "$1"; }
# Le binaire installé doit être Bonk, à la version publiée : un autre paquet du même nom peut l'emporter.
verifier() {
  attendu="bonk $(curl -fsSL "$U/version.txt")"
  obtenu=$(bonk --version)
  [ "$obtenu" = "$attendu" ] || { echo "ERREUR : « $obtenu » au lieu de « $attendu »"; exit 1; }
  echo "OK $obtenu"
}
if command -v apt-get > /dev/null; then
  apt-get update -q
  apt-get install -yq curl ca-certificates
  install -d /etc/apt/keyrings
  curl -fsSL "$U/bonk.gpg" -o /etc/apt/keyrings/bonk.gpg
  echo "deb [signed-by=/etc/apt/keyrings/bonk.gpg] $U/debian stable main" > /etc/apt/sources.list.d/bonk.list
  apt-get update -q
  apt-get install -yq --no-install-recommends bonk
  verifier
  apt-get remove -yq bonk
  apt-get install -yq --no-install-recommends bonk-cli
elif command -v zypper > /dev/null; then
  command -v curl > /dev/null || zypper --non-interactive install --no-recommends curl
  # Les commandes de la page d'installation : le fichier .repo choisit le dépôt du processeur ($basearch).
  rpm --import "$U/bonk.asc"
  if [ "$U" = "$PUBLIC" ]; then
    zypper --non-interactive addrepo "$U/rpm/bonk.repo"
  else
    curl -fsSL "$U/rpm/bonk.repo" -o /tmp/bonk.repo && repo_local /tmp/bonk.repo > /tmp/bonk-local.repo
    zypper --non-interactive addrepo /tmp/bonk-local.repo
  fi
  zypper --non-interactive refresh
  zypper --non-interactive install --no-recommends bonk
  verifier
  zypper --non-interactive remove bonk
  zypper --non-interactive install --no-recommends bonk-cli
elif command -v dnf > /dev/null; then
  curl -fsSL "$U/rpm/bonk.repo" -o /tmp/bonk.repo
  repo_local /tmp/bonk.repo > /etc/yum.repos.d/bonk.repo
  dnf install -y --setopt=install_weak_deps=False bonk
  verifier
  dnf remove -y bonk
  dnf install -y --setopt=install_weak_deps=False bonk-cli
elif command -v pacman > /dev/null; then
  pacman-key --init
  curl -fsSL "$U/bonk.asc" -o /tmp/bonk.asc
  pacman-key --add /tmp/bonk.asc
  pacman-key --lsign-key "$EMPREINTE"
  printf '\n[bonk]\nSigLevel = Required\nServer = %s/arch/$arch\n' "$U" >> /etc/pacman.conf
  pacman -Sy --noconfirm bonk
  verifier
  pacman -R --noconfirm bonk
  pacman -S --noconfirm bonk-cli
else
  apk add --no-cache curl
  curl -fsSL "$U/install.sh" | sh
  PATH="$HOME/.local/bin:$PATH"
fi
verifier
