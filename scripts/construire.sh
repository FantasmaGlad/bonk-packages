#!/usr/bin/env bash
# Construit l'arbre publié (site/) depuis les deux dernières releases de Bonk : APT, DNF, pacman, signés.
# Sans état : rien de binaire n'est versionné ici, tout vient des releases, empreintes contrôlées.
# Demande GH_TOKEN et GPG_KEY_ID, la clé privée étant déjà importée dans gpg.
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
  bash scripts/paquets-cli.sh "$dossier" "${tag#v}"
done

# APT
mkdir -p "$SITE/debian/pool"
find "$ENTREE" -name '*.deb' -exec cp -t "$SITE/debian/pool" {} +
(
  cd "$SITE/debian"
  for arch in amd64 arm64; do
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
    -o "APT::FTPArchive::Release::Architectures=amd64 arm64" \
    release dists/stable > dists/stable/Release
  gpg --batch --yes --local-user "$GPG_KEY_ID" --clearsign -o dists/stable/InRelease dists/stable/Release
  gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
)

# DNF et zypper : paquets signés, et métadonnées signées
for arch in x86_64 aarch64; do
  mkdir -p "$SITE/rpm/$arch"
  find "$ENTREE" -name "*.$arch.rpm" -exec cp -t "$SITE/rpm/$arch" {} +
  rpmsign --define "_gpg_name $GPG_KEY_ID" --define "__gpg /usr/bin/gpg" --addsign "$SITE/rpm/$arch"/*.rpm
  createrepo_c --quiet "$SITE/rpm/$arch"
  gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign \
    -o "$SITE/rpm/$arch/repodata/repomd.xml.asc" "$SITE/rpm/$arch/repodata/repomd.xml"
done
cat > "$SITE/rpm/bonk.repo" <<'REPO'
[bonk]
name=Bonk
baseurl=https://packages.bonk-os.app/rpm/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.bonk-os.app/bonk.asc
REPO

# pacman : x86_64 seul, le paquet n'existe que pour lui. Pages ne sert pas de liens : vrais fichiers.
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

# Scoop lit un manifeste par adresse. Joint à la release juste après sa publication : absent un instant, sans gravité.
mkdir -p "$SITE/scoop"
gh release download "${TAGS[0]}" --repo "$DEPOT" --dir "$SITE/scoop" --pattern bonk.json || echo "manifeste Scoop pas encore joint"

# La version sans fenêtre ne porte pas de manifeste sur la release : il se déduit des empreintes.
python3 scripts/scoop-cli.py "$ENTREE/${TAGS[0]}.sums" "${TAGS[0]#v}" > "$SITE/scoop/bonk-cli.json"

touch "$SITE/.nojekyll"
echo packages.bonk-os.app > "$SITE/CNAME"
