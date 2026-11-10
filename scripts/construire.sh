#!/usr/bin/env bash
set -euo pipefail

DEPOT=FantasmaGlad/Bonk
SITE=$PWD/site
ENTREE=$PWD/entree
rm -rf "$SITE" "$ENTREE"
mkdir -p "$ENTREE" "$SITE"
cp -r public/. "$SITE/"
cp -r web/dist/. "$SITE/"

mapfile -t TAGS < <(gh release list --repo "$DEPOT" --limit 10 --exclude-drafts --exclude-pre-releases \
  --json tagName --jq '.[].tagName' | head -n 2)
[ "${#TAGS[@]}" -gt 0 ] || { echo "aucune release publiée"; exit 1; }
echo "${TAGS[0]#v}" > "$SITE/version.txt"

for tag in "${TAGS[@]}"; do
  dossier="$ENTREE/$tag"
  mkdir -p "$dossier"
  gh release download "$tag" --repo "$DEPOT" --dir "$dossier" \
    --pattern '*.deb' --pattern '*.rpm' --pattern '*.pkg.tar.zst' --pattern SHA256SUMS \
    --pattern '*-linux-*-musl.tar.gz' --pattern 'bonk-cli-*-linux-*.tar.gz'
  (cd "$dossier" && sha256sum --ignore-missing --check --quiet SHA256SUMS && mv SHA256SUMS "$ENTREE/$tag.sums")
  # Releases up to 0.0.5 carry no bonk-cli package: build them from the archives.
  compgen -G "$dossier/bonk-cli_*.deb" > /dev/null || bash scripts/paquets-cli.sh "$dossier" "${tag#v}"
done

mkdir -p "$SITE/debian/pool"
find "$ENTREE" -name '*.deb' -exec cp -t "$SITE/debian/pool" {} +
(
  cd "$SITE/debian"
  for arch in amd64 arm64 i386; do
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
    -o "APT::FTPArchive::Release::Architectures=amd64 arm64 i386" \
    release dists/stable > dists/stable/Release
  gpg --batch --yes --local-user "$GPG_KEY_ID" --clearsign -o dists/stable/InRelease dists/stable/Release
  gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
)

for arch in x86_64 aarch64; do
  mkdir -p "$SITE/rpm/$arch"
  find "$ENTREE" -name "*.$arch.rpm" -exec cp -t "$SITE/rpm/$arch" {} +
  rpmsign --define "_gpg_name $GPG_KEY_ID" --define "__gpg /usr/bin/gpg" --addsign "$SITE/rpm/$arch"/*.rpm
  createrepo_c --quiet "$SITE/rpm/$arch"
  gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign \
    -o "$SITE/rpm/$arch/repodata/repomd.xml.asc" "$SITE/rpm/$arch/repodata/repomd.xml"
done
# Priority 90: otherwise zypper picks openSUSE's "bonk", another tool with a higher version.
cat > "$SITE/rpm/bonk.repo" <<'REPO'
[bonk]
name=Bonk
baseurl=https://packages.bonk-os.app/rpm/$basearch
enabled=1
priority=90
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.bonk-os.app/bonk.asc
REPO

# Pages does not serve symlinks: real files.
mkdir -p "$SITE/arch/x86_64"
find "$ENTREE" -name '*.pkg.tar.zst' -exec cp -t "$SITE/arch/x86_64" {} +
if compgen -G "$SITE/arch/x86_64/*.pkg.tar.zst" > /dev/null; then
  docker run --rm --volume "$SITE/arch/x86_64:/depot" archlinux:latest sh -ec \
    'cd /depot && repo-add --quiet bonk.db.tar.gz ./*.pkg.tar.zst && chown -R '"$(id -u):$(id -g)"' /depot'
  (
    cd "$SITE/arch/x86_64"
    rm -f bonk.db bonk.files
    cp bonk.db.tar.gz bonk.db
    cp bonk.files.tar.gz bonk.files
    for f in *.pkg.tar.zst bonk.db bonk.files; do
      gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign -o "$f.sig" "$f"
    done
  )
fi

# The manifest is attached right after the release is published: briefly missing, harmless.
mkdir -p "$SITE/scoop"
gh release download "${TAGS[0]}" --repo "$DEPOT" --dir "$SITE/scoop" --pattern bonk.json || echo "manifeste Scoop pas encore joint"

# The windowless build has no manifest on the release: it is derived from the hashes.
python3 scripts/scoop-cli.py "$ENTREE/${TAGS[0]}.sums" "${TAGS[0]#v}" > "$SITE/scoop/bonk-cli.json"

touch "$SITE/.nojekyll"
echo packages.bonk-os.app > "$SITE/CNAME"
