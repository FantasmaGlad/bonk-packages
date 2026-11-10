<p align="center">
  <img src="docs/icons/linux.svg" width="96" height="96" alt="Linux">
</p>

<h1 align="center">bonk-packages</h1>

<p align="center">
  <b>Signed APT, DNF, Zypper and pacman repositories, Scoop manifests and install scripts for Bonk.</b>
</p>

<p align="center">
  <a href="https://packages.bonk-os.app"><b>packages.bonk-os.app</b></a> &nbsp;·&nbsp;
  <a href="https://packages.bonk-os.app/bonk.asc"><b>Signing key</b></a> &nbsp;·&nbsp;
  <a href="https://bonk-os.app/install/"><b>Install</b></a> &nbsp;·&nbsp;
  <a href="https://bonk-os.app/reference/"><b>Commands</b></a> &nbsp;·&nbsp;
  <a href="https://packages.bonk-os.app/fr/"><b>Français</b></a>
</p>

<p align="center">
  <a href="https://github.com/FantasmaGlad/bonk-packages/actions/workflows/publier.yml"><img src="https://github.com/FantasmaGlad/bonk-packages/actions/workflows/publier.yml/badge.svg?branch=main" alt="Publish"></a>
</p>

---

## Key

- Signing key: https://packages.bonk-os.app/bonk.asc
- Fingerprint: `8DE6 80FF BE47 5B66 3E8B 019A 7578 66E3 4D67 014B`

## <img src="docs/icons/debian.svg" width="20" height="20" valign="middle" alt="Debian"> Debian, Ubuntu (APT)

```bash
url=https://packages.bonk-os.app
sudo install -d /etc/apt/keyrings
curl -fsSL "$url/bonk.gpg" \
  | sudo tee /etc/apt/keyrings/bonk.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/bonk.gpg] $url/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/bonk.list
sudo apt update && sudo apt install bonk
```

## <img src="docs/icons/fedora.svg" width="20" height="20" valign="middle" alt="Fedora"> Fedora, RHEL (DNF)

```bash
sudo curl -fsSL https://packages.bonk-os.app/rpm/bonk.repo \
  -o /etc/yum.repos.d/bonk.repo
sudo dnf install bonk
```

## <img src="docs/icons/opensuse.svg" width="20" height="20" valign="middle" alt="openSUSE"> openSUSE (Zypper)

```bash
url=https://packages.bonk-os.app
sudo rpm --import "$url/bonk.asc"
sudo zypper addrepo "$url/rpm/bonk.repo"
sudo zypper refresh && sudo zypper install bonk
```

## <img src="docs/icons/arch.svg" width="20" height="20" valign="middle" alt="Arch Linux"> Arch Linux (pacman)

```bash
curl -fsSL https://packages.bonk-os.app/bonk.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 8DE680FFBE475B663E8B019A757866E34D67014B
```

Then add to `/etc/pacman.conf` and run `sudo pacman -Sy bonk`:

```ini
[bonk]
SigLevel = Required
Server = https://packages.bonk-os.app/arch/$arch
```

## <img src="docs/icons/windows.svg" width="20" height="20" valign="middle" alt="Windows"> Windows (Scoop)

```powershell
scoop install https://packages.bonk-os.app/scoop/bonk.json
```

## Command line only

`bonk-cli` is Bonk without a window, from the same repositories.

| Manager | Install | Remove `bonk` first |
| :--- | :--- | :--- |
| **APT** | `sudo apt install bonk-cli` | `sudo apt remove bonk` |
| **DNF** | `sudo dnf install bonk-cli` | `sudo dnf remove bonk` |
| **Zypper** | `sudo zypper install bonk-cli` | `sudo zypper remove bonk` |
| **pacman** | `sudo pacman -S bonk-cli` | `sudo pacman -R bonk` |
| **Scoop** | `scoop install` the `bonk-cli.json` manifest | `scoop uninstall bonk` |

```powershell
scoop install https://packages.bonk-os.app/scoop/bonk-cli.json
```

Both packages install the `bonk` command and cannot be installed together. To go back, remove `bonk-cli`, then install `bonk`.

## Without a package manager

`bonk-cli` only, no administrator rights. Windows: x86_64, ARM64, x86. Linux and macOS: x86_64, ARM64.

```bash
curl -fsSL https://packages.bonk-os.app/install.sh | sh
```

```powershell
irm https://packages.bonk-os.app/install.ps1 | iex
```

---

License: view-only, all rights reserved ([LICENSE](LICENSE)) · Security: [SECURITY.md](SECURITY.md) · Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)

<sub>Related repositories: [Bonk](https://github.com/FantasmaGlad/Bonk) (application) · [BonkWeb](https://github.com/FantasmaGlad/BonkWeb) (website) · [bonk-catalog](https://github.com/FantasmaGlad/bonk-catalog) (image catalog) · [homebrew-bonk](https://github.com/FantasmaGlad/homebrew-bonk) (Homebrew tap) · [bonk-security](https://github.com/FantasmaGlad/bonk-security) (security site) · Security policy: [security.bonk-os.app](https://security.bonk-os.app), [`/.well-known/security.txt`](https://bonk-os.app/.well-known/security.txt)</sub>
