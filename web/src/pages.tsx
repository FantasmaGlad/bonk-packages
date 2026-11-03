const SITE = "https://bonk-os.app/install/";
const FINGERPRINT = "8DE680FFBE475B663E8B019A757866E34D67014B";

const SOURCES = [
  ["APT", "/debian", "Debian, Ubuntu, Mint"],
  ["DNF, Zypper", "/rpm", "Fedora, RHEL, openSUSE"],
  ["pacman", "/arch", "Arch, Manjaro"],
  ["Homebrew", "fantasmaglad/bonk", "macOS, Linux"],
  ["Scoop", "/scoop", "Windows"],
  ["Script", "/install.sh", "Linux, macOS"],
  ["Script", "/install.ps1", "Windows"],
] as const;

const MAIN = "https://bonk-os.app";

function Home() {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#faf7f2" />
        <title>Bonk packages</title>
        <meta name="description" content="Signed package repositories for Bonk." />
        <link rel="stylesheet" href="/style.css" />
        <link rel="icon" href="/logo.png" />
      </head>
      <body>
        <header className="site-header">
          <div className="bar">
            <a className="brand" href={MAIN}>
              <img src="/logo.png" alt="" width="36" height="36" />
              <span>Bonk</span>
            </a>
            <nav className="menu" aria-label="Bonk">
              <a href={`${MAIN}/images/`}>Systems</a>
              <a href={SITE}>Get Bonk</a>
              <a href={`${MAIN}/docs/`}>Commands</a>
            </nav>
          </div>
        </header>
        <main>
          <h1>Bonk packages</h1>
          <p className="lead">
            Signed package repositories for Bonk. The <a href={SITE}>install page</a> gives the
            commands for your system.
          </p>
          <h2>Repositories</h2>
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Manager</th>
                  <th>Address</th>
                  <th>For</th>
                </tr>
              </thead>
              <tbody>
                {SOURCES.map(([manager, path, target]) => (
                  <tr key={path}>
                    <td>{manager}</td>
                    <td>
                      {path.startsWith("/") ? (
                        <code>{path}</code>
                      ) : (
                        // The Homebrew tap is a GitHub repository of its own, not a folder here.
                        <a href={`https://github.com/${path.replace("/", "/homebrew-")}`}>
                          <code>{path}</code>
                        </a>
                      )}
                    </td>
                    <td>{target}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <h2>Signing key</h2>
          <div className="card">
            <p>
              <a href="/bonk.asc">bonk.asc</a>, <a href="/bonk.gpg">bonk.gpg</a>
            </p>
            <p className="muted">Fingerprint</p>
            <p className="command">
              <code>{FINGERPRINT}</code>
            </p>
          </div>
        </main>
        <footer className="site-footer">
          <div className="bar">
            <p>
              <a href={MAIN}>bonk-os.app</a>
              <a href="https://github.com/FantasmaGlad/bonk-packages">Source code</a>
              <a href="https://security.bonk-os.app">Security reports</a>
            </p>
          </div>
        </footer>
      </body>
    </html>
  );
}

export const PAGES = [{ path: "index.html", page: <Home /> }];
