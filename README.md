<p align="center">
  <img src="docs/icons/linux.svg" width="96" height="96" alt="Linux">
</p>

<h1 align="center">bonk-packages</h1>

<p align="center">
  Signed APT, DNF, Zypper and pacman repositories, Scoop manifests and install scripts for Bonk.
</p>

<p align="center">
  <a href="https://packages.bonk-os.app">packages.bonk-os.app</a>,
  <a href="https://packages.bonk-os.app/bonk.asc">Signing key</a>,
  <a href="https://bonk-os.app/install/">Install</a>,
  <a href="https://packages.bonk-os.app/fr/">Français</a>
</p>

<p align="center">
  <a href="https://github.com/FantasmaGlad/bonk-packages/actions/workflows/publier.yml"><img src="https://github.com/FantasmaGlad/bonk-packages/actions/workflows/publier.yml/badge.svg?branch=main" alt="Publish"></a>
</p>

## Key

RSA 4096, valid until 2031-10-30, at <https://packages.bonk-os.app/bonk.asc>:

```text
8DE6 80FF BE47 5B66 3E8B  019A 7578 66E3 4D67 014B
```

## <img src="docs/icons/debian.svg" width="20" height="20" valign="middle" alt="Debian"> Debian, Ubuntu

```bash
url=https://packages.bonk-os.app
sudo install -d /etc/apt/keyrings
curl -fsSL "$url/bonk.gpg" \
  | sudo tee /etc/apt/keyrings/bonk.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/bonk.gpg] $url/debian stable main" \
  | sudo tee /etc/apt/sources.list.d/bonk.list
sudo apt update && sudo apt install bonk
```

On 32-bit x86, only `bonk-cli` is published.

## <img src="docs/icons/fedora.svg" width="20" height="20" valign="middle" alt="Fedora"> Fedora, RHEL

```bash
sudo curl -fsSL https://packages.bonk-os.app/rpm/bonk.repo \
  -o /etc/yum.repos.d/bonk.repo
sudo dnf install bonk
```

## <img src="docs/icons/opensuse.svg" width="20" height="20" valign="middle" alt="openSUSE"> openSUSE

```bash
url=https://packages.bonk-os.app
sudo rpm --import "$url/bonk.asc"
sudo zypper addrepo "$url/rpm/bonk.repo"
sudo zypper refresh && sudo zypper install bonk
```

## <img src="docs/icons/arch.svg" width="20" height="20" valign="middle" alt="Arch Linux"> Arch Linux

x86_64 only.

```bash
curl -fsSL https://packages.bonk-os.app/bonk.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 8DE680FFBE475B663E8B019A757866E34D67014B
```

Add this to `/etc/pacman.conf`, then run `sudo pacman -Sy bonk`:

```ini
[bonk]
SigLevel = Required
Server = https://packages.bonk-os.app/arch/$arch
```

## <img src="docs/icons/windows.svg" width="20" height="20" valign="middle" alt="Windows"> Windows

```powershell
scoop install https://packages.bonk-os.app/scoop/bonk.json
```

## <img src="docs/icons/android.svg" width="20" height="20" valign="middle" alt="Android"> Termux

Command line only, on ARM64 and x86_64, without root. It needs the Termux:API app from the same source as Termux, F-Droid or GitHub.

```bash
url=https://packages.bonk-os.app
apt=$PREFIX/etc/apt
curl -fsSL "$url/bonk.asc" -o "$apt/trusted.gpg.d/bonk.asc"
echo "deb $url/termux stable main" > "$apt/sources.list.d/bonk.list"
pkg install bonk
```

Drives are reached through `termux-usb`:

```bash
termux-usb -r -E -e 'bonk list' <device from termux-usb -l>
```

## Command line only

`bonk-cli` is Bonk without its window, from the same repositories. Both packages install the `bonk` command.

| Manager | Install | Remove `bonk` first |
| :--- | :--- | :--- |
| <img src="docs/icons/debian.svg" width="20" height="20" valign="middle" alt="Debian">&nbsp;**APT** | `sudo apt install bonk-cli` | no |
| <img src="docs/icons/fedora.svg" width="20" height="20" valign="middle" alt="Fedora">&nbsp;**DNF** | `sudo dnf install --allowerasing bonk-cli` | no |
| <img src="docs/icons/opensuse.svg" width="20" height="20" valign="middle" alt="openSUSE">&nbsp;**Zypper** | `sudo zypper install bonk-cli` | no, asks |
| <img src="docs/icons/arch.svg" width="20" height="20" valign="middle" alt="Arch Linux">&nbsp;**pacman** | `sudo pacman -S bonk-cli` | no, asks |
| <img src="docs/icons/windows.svg" width="20" height="20" valign="middle" alt="Windows">&nbsp;**Scoop** | `scoop install` [bonk-cli.json](https://packages.bonk-os.app/scoop/bonk-cli.json) | yes |

To go back, remove `bonk-cli`, then install `bonk`.

## Without a package manager

`bonk-cli` only, without administrator rights: Linux and Windows 10 or later on x86_64, ARM64 and x86; macOS 12 or later on x86_64 and ARM64. On Termux, the script adds the repository above.

```bash
curl -fsSL https://packages.bonk-os.app/install.sh | sh
```

```powershell
irm https://packages.bonk-os.app/install.ps1 | iex
```

On a Chromebook, run the script in the Linux development environment, then enable the USB drive for Linux in the ChromeOS settings.

## Latest files

Each file of the latest release keeps a stable address, its name without the version, such as <https://packages.bonk-os.app/download/SHA256SUMS>.

## License

View-only, all rights reserved: [LICENSE](LICENSE).

Report a vulnerability as described in [SECURITY.md](SECURITY.md). Contributions: [CONTRIBUTING.md](CONTRIBUTING.md).

## Related repositories

| Repository | Content |
| :--- | :--- |
| <img src="docs/icons/bonk.png" width="20" height="20" valign="middle" alt="Bonk">&nbsp;**[Bonk](https://github.com/FantasmaGlad/Bonk)** | application |
| <img src="docs/icons/bonk.png" width="20" height="20" valign="middle" alt="BonkWeb">&nbsp;**[BonkWeb](https://github.com/FantasmaGlad/BonkWeb)** | website |
| <img src="docs/icons/bonk.png" width="20" height="20" valign="middle" alt="bonk-catalog">&nbsp;**[bonk-catalog](https://github.com/FantasmaGlad/bonk-catalog)** | image catalog |
| <img src="docs/icons/homebrew.svg" width="20" height="20" valign="middle" alt="homebrew-bonk">&nbsp;**[homebrew-bonk](https://github.com/FantasmaGlad/homebrew-bonk)** | Homebrew tap |
| <img src="docs/icons/bonk.png" width="20" height="20" valign="middle" alt="bonk-security">&nbsp;**[bonk-security](https://github.com/FantasmaGlad/bonk-security)** | security site |
