const SITE = "https://packages.bonk-os.app";
const FINGERPRINT = "8DE680FFBE475B663E8B019A757866E34D67014B";
const SPACED = FINGERPRINT.replace(/(.{4})(?!$)/g, "$1 ");

type Text = {
  lang: "en" | "fr";
  path: string;
  title: string;
  description: string;
  lead: string;
  key: string;
  fingerprint: string;
  scripts: string;
  cli: string;
  links: [string, string][];
  other: { href: string; lang: string; label: string };
};

const EN: Text = {
  lang: "en",
  path: "/",
  title: "Bonk packages",
  description:
    "Signed APT, DNF, Zypper and pacman repositories for Bonk, plus Scoop and install scripts.",
  lead: "Signed package repositories for Bonk.",
  key: "Signing key:",
  fingerprint: "Fingerprint:",
  scripts: "Without a window or package manager, on Linux, macOS or Windows:",
  cli: "Replace bonk with bonk-cli for the version without a window. Both install the bonk command: remove one before installing the other.",
  links: [
    ["https://bonk-os.app/install/", "Install"],
    ["https://security.bonk-os.app", "Security"],
  ],
  other: { href: "/fr/", lang: "fr", label: "Français" },
};

const FR: Text = {
  lang: "fr",
  path: "/fr/",
  title: "Paquets de Bonk",
  description:
    "Dépôts APT, DNF, Zypper et pacman signés pour Bonk, avec Scoop et les scripts d'installation.",
  lead: "Dépôts de paquets signés pour Bonk.",
  key: "Clé de signature :",
  fingerprint: "Empreinte :",
  scripts: "Sans fenêtre ni gestionnaire de paquets, sous Linux, macOS ou Windows :",
  cli: "Remplacez bonk par bonk-cli pour la version sans fenêtre. Les deux installent la commande bonk : retirez l'un avant d'installer l'autre.",
  links: [
    ["https://bonk-os.app/install/?lang=fr", "Installer"],
    ["https://security.bonk-os.app/fr/", "Sécurité"],
  ],
  other: { href: "/", lang: "en", label: "English" },
};

const MANAGERS: [string, string][] = [
  [
    "Debian, Ubuntu (APT)",
    `sudo install -d /etc/apt/keyrings
curl -fsSL ${SITE}/bonk.gpg | sudo tee /etc/apt/keyrings/bonk.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/bonk.gpg] ${SITE}/debian stable main" | sudo tee /etc/apt/sources.list.d/bonk.list
sudo apt update && sudo apt install bonk`,
  ],
  [
    "Fedora, RHEL (DNF)",
    `sudo curl -fsSL ${SITE}/rpm/bonk.repo -o /etc/yum.repos.d/bonk.repo
sudo dnf install bonk`,
  ],
  [
    "openSUSE (Zypper)",
    `sudo rpm --import ${SITE}/bonk.asc
sudo zypper addrepo ${SITE}/rpm/bonk.repo
sudo zypper refresh && sudo zypper install bonk`,
  ],
  [
    "Arch Linux (pacman)",
    `curl -fsSL ${SITE}/bonk.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key ${FINGERPRINT}
printf '\\n[bonk]\\nSigLevel = Required\\nServer = ${SITE}/arch/$arch\\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Sy bonk`,
  ],
];

function Page({ text }: { text: Text }) {
  return (
    <html lang={text.lang}>
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{text.title}</title>
        <meta name="description" content={text.description} />
        <link rel="canonical" href={`${SITE}${text.path}`} />
        <link rel="alternate" hrefLang="en" href={`${SITE}/`} />
        <link rel="alternate" hrefLang="fr" href={`${SITE}/fr/`} />
        <link rel="icon" href="/logo.png" />
        <link rel="stylesheet" href="/site.css" />
        <script src="/copy.js" defer />
      </head>
      <body>
        <main>
          <header>
            <h1>{text.title}</h1>
            <p className="lead">
              {text.lead} {text.cli}
            </p>
            <p className="key">
              {text.key} <a href="/bonk.asc">bonk.asc</a> · <a href="/bonk.gpg">bonk.gpg</a> ·{" "}
              {text.fingerprint} <code>{SPACED}</code>
            </p>
          </header>
          {MANAGERS.map(([name, commands]) => (
            <section key={name}>
              <h2>{name}</h2>
              <pre>
                <code>{commands}</code>
              </pre>
            </section>
          ))}
          <section>
            <h2>macOS (Homebrew), Windows (Scoop)</h2>
            <pre>
              <code>brew install fantasmaglad/bonk/bonk</code>
            </pre>
            <pre>
              <code>{`scoop install ${SITE}/scoop/bonk.json`}</code>
            </pre>
            <p>{text.scripts}</p>
            <pre>
              <code>{`curl -fsSL ${SITE}/install.sh | sh`}</code>
            </pre>
            <pre>
              <code>{`irm ${SITE}/install.ps1 | iex`}</code>
            </pre>
          </section>
        </main>
        <footer>
          <p>
            <a href="https://bonk-os.app">bonk-os.app</a> ·{" "}
            {text.links.map(([href, label]) => (
              <span key={href}>
                <a href={href}>{label}</a> ·{" "}
              </span>
            ))}
            <a href="https://github.com/FantasmaGlad/bonk-packages">GitHub</a> ·{" "}
            <a href={text.other.href} lang={text.other.lang} hrefLang={text.other.lang}>
              {text.other.label}
            </a>
          </p>
        </footer>
      </body>
    </html>
  );
}

export const PAGES = [
  { path: "index.html", page: <Page text={EN} /> },
  { path: "fr/index.html", page: <Page text={FR} /> },
];
