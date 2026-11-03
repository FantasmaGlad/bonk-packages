import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";
import { PAGES } from "./pages";

it("dit où installer et donne l'empreinte, sans script", () => {
  const html = renderToStaticMarkup(PAGES[0]?.page);
  expect(html).toContain("https://bonk-os.app/install/");
  expect(html).toContain("8DE680FFBE475B663E8B019A757866E34D67014B");
  expect(html).not.toContain("<script");
});

it("partage la charte du site principal, sans style écrit dans la page", () => {
  const html = renderToStaticMarkup(PAGES[0]?.page);
  expect(html).toContain('href="/style.css"');
  expect(html).not.toContain("<style");
  expect(html).toContain('href="https://bonk-os.app/images/"');
});
