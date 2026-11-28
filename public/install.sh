#!/bin/sh
set -eu

DEPOT=FantasmaGlad/Bonk
CLE_RELEASE=9F67B75803CE75260FB0D8952F20472E7865EDF1
EMETTEUR=https://token.actions.githubusercontent.com

echec() { echo "ERROR: $1" >&2; exit 1; }
avertir() { echo "WARNING: $1" >&2; }

empreinte() {
  if command -v sha256sum > /dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d ' ' -f 1
}

verifier_signature() {
  if ! command -v gpg > /dev/null; then
    avertir "gpg is missing: the signature of SHA256SUMS by the Bonk release key $CLE_RELEASE was not checked."
    return
  fi
  if ! curl -fsSL "$base/SHA256SUMS.asc" -o "$travail/SHA256SUMS.asc" \
    || ! curl -fsSL "$base/bonk-release-key.asc" -o "$travail/cle.asc"; then
    avertir "Bonk $version has no signature of SHA256SUMS: the signature was not checked."
    return
  fi
  mkdir -m 700 "$travail/gnupg"
  gpg --homedir "$travail/gnupg" --batch --import "$travail/cle.asc" > "$travail/gpg.txt" 2>&1 || true
  gpg --homedir "$travail/gnupg" --batch --status-fd 1 --verify "$travail/SHA256SUMS.asc" "$travail/SHA256SUMS" \
    >> "$travail/gpg.txt" 2>&1 || true
  # VALIDSIG ends with the fingerprint of the primary key that made the signature.
  if ! grep -q "^\[GNUPG:\] VALIDSIG .* $CLE_RELEASE\$" "$travail/gpg.txt"; then
    cat "$travail/gpg.txt" >&2
    echec "SHA256SUMS of Bonk $version is not signed by the Bonk release key $CLE_RELEASE."
  fi
  echo "SHA256SUMS signed by the Bonk release key $CLE_RELEASE."
}

# Without a token the API allows 60 requests an hour per address, shared behind a NAT.
lire_attestations() {
  adresse="https://api.github.com/repos/$DEPOT/attestations/sha256:$(empreinte "$1")"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$adresse" -o "$travail/attestations.json"
  else
    curl -fsSL "$adresse" -o "$travail/attestations.json"
  fi
}

attestation_cosign() {
  identite="https://github.com/$DEPOT/.github/workflows/binaires.yml@refs/tags/v$version"
  lire_attestations "$1" \
    || echec "the attestations of $archive could not be read from api.github.com: try again later, set GITHUB_TOKEN, or sign in with gh auth login."
  nombre=$(jq '.attestations | length' "$travail/attestations.json")
  i=0
  while [ "$i" -lt "$nombre" ]; do
    jq ".attestations[$i].bundle" "$travail/attestations.json" > "$travail/bundle.json"
    if cosign verify-blob-attestation --bundle "$travail/bundle.json" --new-bundle-format \
      --certificate-identity "$identite" --certificate-oidc-issuer "$EMETTEUR" \
      --type https://slsa.dev/provenance/v1 "$1" > /dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

verifier_provenance() {
  if command -v gh > /dev/null && gh auth status > /dev/null 2>&1; then
    gh attestation verify "$1" --repo "$DEPOT" --signer-workflow "$DEPOT/.github/workflows/binaires.yml" \
      --source-ref "refs/tags/v$version" > /dev/null \
      || echec "$archive has no provenance attestation from the release workflow of Bonk $version."
  elif command -v cosign > /dev/null && command -v jq > /dev/null; then
    attestation_cosign "$1" || echec "$archive has no provenance attestation from the release workflow of Bonk $version."
  else
    avertir "neither gh signed in (gh auth login) nor cosign with jq is installed: the provenance of $archive was not checked, only its SHA-256. By hand: gh attestation verify $archive --repo $DEPOT"
    return
  fi
  echo "$archive built by the release workflow of $DEPOT at v$version."
}

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
base="${BONK_RELEASE_URL:-https://github.com/$DEPOT/releases/download/v$version}"
travail=$(mktemp -d)
nettoyer() {
  if [ -d "$travail/gnupg" ]; then gpgconf --homedir "$travail/gnupg" --kill all 2> /dev/null || true; fi
  rm -rf "$travail"
}
trap nettoyer EXIT
curl -fsSL "$base/SHA256SUMS" -o "$travail/SHA256SUMS"
verifier_signature
archive="bonk-cli-$version-$cible.tar.gz"
attendue=$(awk -v nom="$archive" '$2 == nom || $2 == "*" nom { print $1 }' "$travail/SHA256SUMS")
[ -n "$attendue" ] || echec "Bonk $version has no build for $cible."
curl -fsSL "$base/$archive" -o "$travail/$archive"
[ "$(empreinte "$travail/$archive")" = "$attendue" ] || echec "$archive does not match its SHA-256 in SHA256SUMS."
verifier_provenance "$travail/$archive"
tar -xzf "$travail/$archive" -C "$travail"
mkdir -p "$DOSSIER"
install -m 755 "$travail"/bonk-*/bonk "$DOSSIER/bonk"
"$DOSSIER/bonk" --version
case ":$PATH:" in
  *":$DOSSIER:"*) ;;
  *)
    # macOS and many distributions leave ~/.local/bin out of a new terminal's PATH.
    case "${SHELL:-}" in
      */zsh) profil="$HOME/.zshrc" ;;
      */bash) if [ "$systeme" = Darwin ]; then profil="$HOME/.bash_profile"; else profil="$HOME/.bashrc"; fi ;;
      *) profil="$HOME/.profile" ;;
    esac
    ligne="export PATH=\"$DOSSIER:\$PATH\""
    grep -qsxF "$ligne" "$profil" || printf '\n%s\n' "$ligne" >> "$profil"
    echo "$DOSSIER is in PATH from $profil: open a new terminal, or run: $ligne"
    ;;
esac
