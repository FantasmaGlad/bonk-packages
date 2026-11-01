import { cpSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import { PAGES } from "./pages";

/* The pages are written once as plain HTML: they must work without JavaScript. */
const output = "dist";
cpSync("public", output, { recursive: true });
for (const { path, page } of PAGES) {
  const target = join(output, path);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, `<!doctype html>\n${renderToStaticMarkup(page)}\n`);
}
