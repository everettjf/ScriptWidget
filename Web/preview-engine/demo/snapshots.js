// Driven by scripts/compare-snapshots.mjs over the DevTools protocol.
import { createPreviewSandbox } from "../src/browser/client.js";
import { renderWidget } from "../src/render/renderer.js";
import { deviceProfiles } from "../src/render/profiles.js";
import { sandboxDocument } from "../dist/sandbox-sources.js";

const stage = document.getElementById("stage");
const fontMode = new URLSearchParams(location.search).get("fonts");
// ?profile=macos renders the calibration cases with another device profile.
const caseProfile = new URLSearchParams(location.search).get("profile") ?? "iphone-393";
if (fontMode) globalThis.__scriptWidgetFontStack = fontMode;
if (fontMode === "inter") {
  const face = new FontFace("ScriptWidget Inter", `url(${new URL("../dist/assets/inter.woff2", import.meta.url)})`, { weight: "100 900" });
  document.fonts.add(await face.load());
}
const sandbox = createPreviewSandbox({ sandboxDocument, assetBaseURL: new URL("../dist/assets/", import.meta.url) });
const corpus = await (await fetch("../dist/parity-corpus.json")).json();
const cases = await (await fetch("../test/render/cases.json")).json();
const catalog = await (await fetch("../test/catalog/catalog.json")).json();

// Every iOS profile and family, deduplicated by size like
// BrowserPreviewSnapshotProfile.renders in the native tests. Names without a
// "~profile" suffix are the 393-point iPhone.
const defaultProfile = "iphone-393";
const renders = [];
const seen = new Set();
for (const [profile, sizes] of Object.entries(deviceProfiles)) {
  if (sizes.platform === "macos") continue;
  for (const [family, size] of Object.entries(sizes)) {
    if (!Array.isArray(size) || (family.startsWith("accessory") && profile !== defaultProfile)) continue;
    const key = `${family} ${size[0]}x${size[1]}`;
    if (seen.has(key)) continue;
    seen.add(key);
    renders.push({ profile, family, suffix: profile === defaultProfile ? `@${family}` : `@${family}~${profile}` });
  }
}
const items = [];
for (const item of corpus.corpus) for (const render of renders) items.push({ name: `${item.name}${render.suffix}`, ...render, files: item.files, resources: item.resources });
// A case may name an iOS profile ("profile": "iphone-375"); its name then
// carries the "~profile" suffix like the native export.
for (const item of cases) items.push({ name: `case/${item.name}@${item.size}${item.profile && item.profile !== defaultProfile ? `~${item.profile}` : ""}`, profile: caseProfile === defaultProfile ? item.profile ?? caseProfile : caseProfile, family: item.size, appearance: item.dark ? "dark" : "light", files: { "main.jsx": item.source } });
for (const item of catalog) items.push({ name: `catalog/${item.id}@${item.size}`, profile: caseProfile, family: item.size, appearance: item.dark ? "dark" : "light", files: { "main.jsx": item.source } });

window.__items = items.map((item) => item.name);
window.__render = async (index) => {
  const item = items[index];
  const manifest = item.files["widget.json"] ? JSON.parse(item.files["widget.json"]) : null;
  const result = await sandbox.execute({ files: item.files, manifest, prelude: corpus.prelude, environments: { "widget-size": item.family, "widget-param": "" }, preview: { appearance: item.appearance ?? "light" } });
  stage.replaceChildren();
  if (!result.tree) return { name: item.name, error: result.error };
  await document.fonts.ready;
  // The parity prelude's fixed clock, as ScriptWidgetRenderClock in the native export.
  const rendered = await renderWidget(result.tree, { family: item.family, profile: item.profile, appearance: item.appearance ?? "light", lockScreen: false, resources: item.resources ?? {}, now: 1767268800000, animations: "firstFrame" });
  stage.appendChild(rendered.element);
  await Promise.all([...rendered.element.querySelectorAll("img")].map((image) => image.decode().catch(() => {})));
  const box = rendered.element.getBoundingClientRect();
  return { name: item.name, x: box.x, y: box.y, width: box.width, height: box.height, diagnostics: rendered.diagnostics };
};
await sandbox.ready;
window.__ready = true;
