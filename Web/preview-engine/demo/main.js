import { createPreviewSandbox } from "../src/browser/client.js";
import { sandboxDocument } from "../dist/sandbox-sources.js";

const out = document.getElementById("out");
const status = document.getElementById("status");
const report = { parity: null, isolation: [], timing: {} };
const line = (text, ok) => {
  const span = document.createElement("span");
  if (ok !== undefined) span.className = ok ? "pass" : "fail";
  span.textContent = text + "\n";
  out.append(span);
};

const sandbox = createPreviewSandbox({ sandboxDocument, assetBaseURL: new URL("../dist/assets/", import.meta.url) });
const started = performance.now();
await sandbox.ready;
report.timing.readyMilliseconds = Math.round(performance.now() - started);
status.textContent = `Sandbox ready in ${report.timing.readyMilliseconds} ms`;

const corpus = await (await fetch("../dist/parity-corpus.json")).json();
let matches = 0;
const mismatches = [];
const corpusStarted = performance.now();
for (const item of corpus.corpus) {
  const manifest = item.files["widget.json"] ? JSON.parse(item.files["widget.json"]) : null;
  const result = await sandbox.execute({ files: item.files, manifest, prelude: corpus.prelude });
  const same = item.expected.tree !== undefined ? result.tree === item.expected.tree : result.error?.kind === item.expected.error;
  if (same) matches += 1; else mismatches.push({ name: item.name, error: result.error, tree: result.tree?.slice(0, 200) });
}
report.timing.corpusMilliseconds = Math.round(performance.now() - corpusStarted);
report.parity = { total: corpus.corpus.length, matches, mismatches, recordedTimeZone: corpus.timeZone, browserTimeZone: Intl.DateTimeFormat().resolvedOptions().timeZone };
line(`Parity: ${matches}/${corpus.corpus.length} byte-identical trees (${report.timing.corpusMilliseconds} ms)`, mismatches.length === 0);
for (const item of mismatches) line(`  ✗ ${item.name}: ${JSON.stringify(item.error ?? item.tree)}`, false);

// Each probe returns text; "BLOCKED"/"absent" outcomes are what we require.
const probes = {
  "scrubbed globals": `$render(<text>{[typeof XMLHttpRequest, typeof importScripts, typeof postMessage, typeof indexedDB, typeof self, typeof navigator, typeof setTimeout, typeof Babel, typeof WebSocket].join(",")}</text>)`,
  "prototype fetch is blocked by CSP": `let r; try { const proto = Object.getPrototypeOf(Object.getPrototypeOf(globalThis)); const f = proto.fetch || Object.getPrototypeOf(proto).fetch; await f.call(globalThis, "https://example.com/", { mode: "no-cors" }); r = "REACHED"; } catch (e) { r = "BLOCKED " + e.name; } $render(<text>{r}</text>)`,
  "prototype importScripts is blocked by CSP": `let r; try { let p = globalThis; let f; while (p && !f) { p = Object.getPrototypeOf(p); f = p && Object.getOwnPropertyDescriptor(p, "importScripts")?.value; } f.call(globalThis, "https://example.com/x.js"); r = "REACHED"; } catch (e) { r = "BLOCKED " + e.name; } $render(<text>{r}</text>)`,
  "nested Worker cannot be created": `let r; try { let p = globalThis, W; while (p && !W) { p = Object.getPrototypeOf(p); W = p && Object.getOwnPropertyDescriptor(p, "Worker")?.value; } r = W ? (new W("data:text/javascript,1"), "REACHED") : "absent"; } catch (e) { r = "BLOCKED " + e.name; } $render(<text>{r}</text>)`,
  "frame postMessage is unreachable": `let p = globalThis, post; while (p && !post) { p = Object.getPrototypeOf(p); post = p && Object.getOwnPropertyDescriptor(p, "postMessage")?.value; } post.call(globalThis, "{not json"); $render(<text>late</text>)`,
  "infinite loop is terminated": `while (true) {} $render(<text />)`,
  "eval parity": `$render(<text>{eval("1 + 1")}</text>)`,
};
for (const [name, source] of Object.entries(probes)) {
  const t = performance.now();
  const result = await sandbox.execute({ files: { "main.jsx": source }, timeoutMilliseconds: 1500 });
  const text = result.tree ?? `error ${result.error?.kind}: ${result.error?.message?.split("\n")[0]}`;
  report.isolation.push({ name, text, milliseconds: Math.round(performance.now() - t) });
  line(`${name}: ${text}`);
}

const editTimes = [];
for (let i = 0; i < 10; i += 1) {
  const t = performance.now();
  await sandbox.execute({ files: { "main.jsx": `$render(<vstack><text font="title">Edit ${i}</text><spacer /></vstack>)` } });
  editTimes.push(performance.now() - t);
}
editTimes.sort((a, b) => a - b);
report.timing.warmEditMedianMilliseconds = Math.round(editTimes[5]);
line(`Warm edit→tree median: ${report.timing.warmEditMedianMilliseconds} ms`);
try { await fetch("https://example.com/", { mode: "no-cors" }); report.isolation.push({ name: "control: parent page no-cors fetch", text: "REACHED" }); line("control: parent page no-cors fetch: REACHED"); }
catch (error) { report.isolation.push({ name: "control: parent page no-cors fetch", text: "FAILED " + error.name }); line("control: parent page no-cors fetch: FAILED (network unavailable; CSP attribution unproven)", false); }
window.__report = report;
status.textContent = "Done";
