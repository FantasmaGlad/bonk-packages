const SITE = "https://bonk-os.app/install/";
const FINGERPRINT = "8DE680FFBE475B663E8B019A757866E34D67014B";

const SOURCES = [
  ["APT", "/debian", "Debian, Ubuntu, Mint"],
  ["DNF, Zypper", "/rpm", "Fedora, RHEL, openSUSE"],
  ["pacman", "/arch", "Arch, Manjaro"],
  ["Scoop", "/scoop", "Windows"],
  ["Script", "/install.sh", "Linux, macOS"],
  ["Script", "/install.ps1", "Windows"],
] as const;

const STYLE = `body{margin:0 auto;max-width:44rem;padding:2rem 1rem;background:#fff;color:#000;font:1rem/1.6 system-ui,sans-serif}
a{color:#000}code{overflow-wrap:anywhere}table{border-collapse:collapse;width:100%}
td,th{border:1px solid #000;padding:.4rem .6rem;text-align:left}`;

function Home() {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Bonk packages</title>
        <meta name="description" content="Signed package repositories for Bonk." />
        <style>{STYLE}</style>
      </head>
      <body>
        <h1>Bonk packages</h1>
        <p>
          Signed package repositories for Bonk. To install it, follow{" "}
          <a href={SITE}>the install page</a>: it gives the commands for your system.
        </p>
        <h2>What is here</h2>
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
                  <code>{path}</code>
                </td>
                <td>{target}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <h2>Signing key</h2>
        <p>
          <a href="/bonk.asc">bonk.asc</a>, <a href="/bonk.gpg">bonk.gpg</a>. Fingerprint:{" "}
          <code>{FINGERPRINT}</code>
        </p>
      </body>
    </html>
  );
}

export const PAGES = [{ path: "index.html", page: <Home /> }];
