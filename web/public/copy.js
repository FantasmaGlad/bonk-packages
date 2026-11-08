(() => {
  const fr = document.documentElement.lang === "fr";
  const labels = fr ? ["Copier", "Copié"] : ["Copy", "Copied"];
  const NS = "http://www.w3.org/2000/svg";
  const icon = (paths) => {
    const svg = document.createElementNS(NS, "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("aria-hidden", "true");
    for (const d of paths) {
      const path = document.createElementNS(NS, "path");
      path.setAttribute("d", d);
      svg.append(path);
    }
    return svg;
  };
  const COPY = ["M9 9h10v10H9z", "M5 15V5h10"];
  const DONE = ["M5 13l4 4 10-10"];
  for (const pre of document.querySelectorAll("pre")) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy";
    button.title = labels[0];
    button.setAttribute("aria-label", labels[0]);
    button.append(icon(COPY));
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(pre.querySelector("code")?.textContent ?? pre.textContent);
        button.replaceChildren(icon(DONE));
        button.title = labels[1];
        button.setAttribute("aria-label", labels[1]);
        setTimeout(() => {
          button.replaceChildren(icon(COPY));
          button.title = labels[0];
          button.setAttribute("aria-label", labels[0]);
        }, 1600);
      } catch {
        const range = document.createRange();
        range.selectNodeContents(pre.querySelector("code") ?? pre);
        getSelection()?.removeAllRanges();
        getSelection()?.addRange(range);
      }
    });
    pre.append(button);
  }
})();
