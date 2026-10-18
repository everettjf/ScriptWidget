// Page driven by PreviewService over the DevTools protocol: executes the
// package in the sandboxed runtime and renders the tree for a screenshot.
import { createPreviewSandbox } from "../browser/client.js";
import { renderWidget } from "../render/renderer.js";
import { sandboxDocument } from "/__sandbox-sources.js";

const stage = document.getElementById("stage");
const sandbox = createPreviewSandbox({ sandboxDocument, assetBaseURL: new URL("/__runtime/", location.href) });
await sandbox.ready;
window.__render = async (job) => {
  const started = performance.now();
  const result = await sandbox.execute(job.execute);
  const executeMilliseconds = performance.now() - started;
  stage.replaceChildren();
  if (!result.tree) return { ...result, timing: { ...result.timing, executeMilliseconds } };
  await document.fonts.ready;
  const rendered = await renderWidget(result.tree, job.render);
  stage.appendChild(rendered.element);
  await Promise.all([...rendered.element.querySelectorAll("img")].map((image) => image.decode().catch(() => {})));
  const box = rendered.element.getBoundingClientRect();
  return { ...result, renderDiagnostics: rendered.diagnostics, box: { x: box.x, y: box.y, width: box.width, height: box.height }, timing: { ...result.timing, executeMilliseconds, totalMilliseconds: performance.now() - started } };
};
window.__ready = true;
