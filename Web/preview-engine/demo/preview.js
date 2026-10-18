import { createPreviewSandbox } from "../src/browser/client.js";
import { renderWidget } from "../src/render/renderer.js";
import { sandboxDocument } from "../dist/sandbox-sources.js";

const source = document.getElementById("source");
const family = document.getElementById("family");
const appearance = document.getElementById("appearance");
const stage = document.getElementById("stage");
const status = document.getElementById("status");
const list = document.getElementById("diagnostics");
const sandbox = createPreviewSandbox({ sandboxDocument, assetBaseURL: new URL("../dist/assets/", import.meta.url) });

let generation = 0;
async function refresh() {
  const current = ++generation;
  const started = performance.now();
  const result = await sandbox.execute({
    files: { "main.jsx": source.value },
    environments: { "widget-size": family.value, "widget-param": "" },
    preview: { appearance: appearance.value },
  });
  if (current !== generation) return;
  const items = [...result.diagnostics];
  if (result.error) {
    stage.replaceChildren();
    status.textContent = `[${result.error.kind}] ${result.error.message.split("\n")[0]}`;
  } else {
    const rendered = await renderWidget(result.tree, { family: family.value, appearance: appearance.value });
    if (current !== generation) return;
    stage.replaceChildren(rendered.element);
    items.push(...rendered.diagnostics);
    status.textContent = `Rendered in ${Math.round(performance.now() - started)} ms · web fast preview (verify on iPhone)`;
  }
  list.replaceChildren(...items.map((item) => { const li = document.createElement("li"); li.textContent = `${item.severity}: ${item.message}`; return li; }));
}

let timer = 0;
const schedule = () => { clearTimeout(timer); timer = setTimeout(refresh, 150); };
for (const control of [source, family, appearance]) control.addEventListener("input", schedule);
await sandbox.ready;
refresh();
