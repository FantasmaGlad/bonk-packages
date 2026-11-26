#!/bin/sh
# Usage: essai-script.sh <bash | sh | zsh> <install.sh>
# The install script as a user runs it, then a new shell of that kind finds bonk at the published version.
set -eu
coquille=$1
script=$2
if ! command -v curl > /dev/null || ! command -v "$coquille" > /dev/null; then
  if command -v apt-get > /dev/null; then
    apt-get update -q
    apt-get install -yq curl ca-certificates "$coquille"
  else
    apk add --no-cache curl
  fi
fi
attendu="bonk $(curl -fsSL https://packages.bonk-os.app/version.txt)"
SHELL=$(command -v "$coquille") sh "$script"
case "$coquille" in
  sh) obtenu=$(sh -lc 'bonk --version') ;;
  *) obtenu=$("$coquille" -ic 'bonk --version' 2> /dev/null) ;;
esac
[ "$obtenu" = "$attendu" ] || { echo "ERREUR : « $obtenu » au lieu de « $attendu »" >&2; exit 1; }
echo "OK $obtenu, trouvé par un nouveau $coquille"
