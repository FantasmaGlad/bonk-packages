import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";
import { PAGES } from "./pages";

const html = PAGES.map(({ page }) => renderToStaticMarkup(page));

it("donne les deux langues, l'empreinte et les commandes de chaque gestionnaire", () => {
  expect(PAGES.map(({ path }) => path)).toEqual(["index.html", "fr/index.html"]);
  for (const page of html) {
    expect(page).toContain("8DE6 80FF BE47 5B66 3E8B 019A 7578 66E3 4D67 014B");
    expect(page).toContain("sudo apt install bonk");
    expect(page).toContain("sudo dnf install bonk");
    expect(page).toContain("sudo zypper install bonk");
    expect(page).toContain("sudo pacman -Sy bonk");
    expect(page).toContain("brew install fantasmaglad/bonk/bonk");
    expect(page).toContain("/scoop/bonk.json");
    expect(page).toContain("/install.sh | sh");
    expect(page).toContain("/install.ps1 | iex");
  }
  expect(html[1]).toContain('lang="fr"');
});

it("garde le style hors de la page et ne charge que le bouton copier", () => {
  for (const page of html) {
    expect(page).toContain('href="/site.css"');
    expect(page).not.toContain("<style");
    expect(page.match(/<script[^>]*>/g)).toEqual(['<script src="/copy.js" defer="">']);
  }
});
