// Driven by scripts/compare-snapshots.mjs over the DevTools protocol.
import { createPreviewSandbox } from "../src/browser/client.js";
import { renderWidget } from "../src/render/renderer.js";
import { sandboxDocument } from "../dist/sandbox-sources.js";

const stage = document.getElementById("stage");
const fontMode = new URLSearchParams(location.search).get("fonts");
if (fontMode) globalThis.__scriptWidgetFontStack = fontMode;
if (fontMode === "inter") {
  const face = new FontFace("ScriptWidget Inter", `url(${new URL("../dist/assets/inter.woff2", import.meta.url)})`, { weight: "100 900" });
  document.fonts.add(await face.load());
}
const sandbox = createPreviewSandbox({ sandboxDocument, assetBaseURL: new URL("../dist/assets/", import.meta.url) });
const corpus = await (await fetch("../dist/parity-corpus.json")).json();
const cases = await (await fetch("../test/render/cases.json")).json();

const items = [];
for (const item of corpus.corpus) for (const family of ["small", "medium", "large"]) items.push({ name: `${item.name}@${family}`, family, files: item.files, resources: item.resources });
for (const item of cases) items.push({ name: `case/${item.name}@${item.size}`, family: item.size, appearance: item.dark ? "dark" : "light", files: { "main.jsx": item.source } });

window.__items = items.map((item) => item.name);
window.__render = async (index) => {
  const item = items[index];
  const manifest = item.files["widget.json"] ? JSON.parse(item.files["widget.json"]) : null;
  const result = await sandbox.execute({ files: item.files, manifest, prelude: corpus.prelude, environments: { "widget-size": item.family, "widget-param": "" }, preview: { appearance: item.appearance ?? "light" } });
  stage.replaceChildren();
  if (!result.tree) return { name: item.name, error: result.error };
  await document.fonts.ready;
  const rendered = await renderWidget(result.tree, { family: item.family, appearance: item.appearance ?? "light", lockScreen: false, resources: item.resources ?? {} });
  stage.appendChild(rendered.element);
  await Promise.all([...rendered.element.querySelectorAll("img")].map((image) => image.decode().catch(() => {})));
  const box = rendered.element.getBoundingClientRect();
  return { name: item.name, x: box.x, y: box.y, width: box.width, height: box.height, diagnostics: rendered.diagnostics };
};
await sandbox.ready;
window.__ready = true;
