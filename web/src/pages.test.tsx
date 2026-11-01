import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";
import { PAGES } from "./pages";

it("dit où installer et donne l'empreinte, sans script", () => {
  const html = renderToStaticMarkup(PAGES[0]?.page);
  expect(html).toContain("https://bonk-os.app/install/");
  expect(html).toContain("8DE680FFBE475B663E8B019A757866E34D67014B");
  expect(html).not.toContain("<script");
});
