// Renders every corpus entry and calibration case in headless Chrome, then
// compares each against the native iOS PNG in dist/native-snapshots.
// Usage: node scripts/compare-snapshots.mjs [name-prefix[,name-prefix...]]
import { spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { decodePNG, encodePNG } from "./png.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const prefixes = (process.argv[2] ?? "").split(",");
const nativeDirectory = path.join(root, "dist/native-snapshots");
const webDirectory = path.join(root, "dist/web-snapshots");
const compareDirectory = path.join(root, "dist/compare");
for (const directory of [webDirectory, compareDirectory]) fs.mkdirSync(directory, { recursive: true });
const fileName = (name) => name.replaceAll("/", "__").replaceAll(" ", "_") + ".png";

const types = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".png": "image/png" };
const server = http.createServer((request, response) => {
  const target = path.join(root, decodeURIComponent(new URL(request.url, "http://x").pathname));
  if (!target.startsWith(root) || !fs.existsSync(target) || fs.statSync(target).isDirectory()) { response.writeHead(404).end(); return; }
  response.writeHead(200, { "content-type": types[path.extname(target)] ?? "application/octet-stream" });
  fs.createReadStream(target).pipe(response);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const port = server.address().port;

const chromePath = process.env.CHROME_PATH ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "sw-chrome-"));
const chrome = spawn(chromePath, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--force-device-scale-factor=2",
  "--window-size=800,800", "--hide-scrollbars", "--font-render-hinting=none", "about:blank"], { stdio: ["ignore", "ignore", "pipe"] });
const wsURL = await new Promise((resolve, reject) => {
  let buffer = "";
  chrome.stderr.on("data", (chunk) => { buffer += chunk; const match = /DevTools listening on (ws:\S+)/.exec(buffer); if (match) resolve(match[1]); });
  chrome.on("exit", () => reject(new Error("Chrome exited")));
});
const browser = new WebSocket(wsURL);
await new Promise((resolve) => browser.addEventListener("open", resolve, { once: true }));
let sequence = 0;
const waiting = new Map();
browser.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (message.id && waiting.has(message.id)) { waiting.get(message.id)(message); waiting.delete(message.id); }
});
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const id = ++sequence;
  waiting.set(id, (message) => (message.error ? reject(new Error(`${method}: ${message.error.message}`)) : resolve(message.result)));
  browser.send(JSON.stringify({ id, method, params, sessionId }));
});

const { targetId } = await send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
const page = (method, params) => send(method, params, sessionId);
await page("Page.enable");
await page("Emulation.setDeviceMetricsOverride", { width: 800, height: 800, deviceScaleFactor: 2, mobile: false });
await page("Emulation.setTimezoneOverride", { timezoneId: JSON.parse(fs.readFileSync(path.join(root, "test/parity/native-trees.json"), "utf8")).timeZone });
await page("Page.navigate", { url: `http://127.0.0.1:${port}/demo/snapshots.html${process.env.SW_FONTS ? `?fonts=${process.env.SW_FONTS}` : ""}` });
const evaluate = async (expression) => {
  const result = await page("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? "evaluation failed");
  return result.result.value;
};
for (let attempt = 0; attempt < 200 && !(await evaluate("window.__ready === true").catch(() => false)); attempt += 1) await new Promise((r) => setTimeout(r, 100));
const names = await evaluate("window.__items");

const report = [];
for (let index = 0; index < names.length; index += 1) {
  if (!prefixes.some((prefix) => names[index].startsWith(prefix))) continue;
  const nativeFile = path.join(nativeDirectory, fileName(names[index]));
  if (!fs.existsSync(nativeFile)) continue;
  const box = await evaluate(`window.__render(${index})`);
  if (box.error) { report.push({ name: box.name, error: box.error.kind }); continue; }
  const shot = await page("Page.captureScreenshot", { format: "png", clip: { x: box.x, y: box.y, width: box.width, height: box.height, scale: 1 } });
  const webPNG = Buffer.from(shot.data, "base64");
  fs.writeFileSync(path.join(webDirectory, fileName(box.name)), webPNG);
  const native = decodePNG(nativeFile); const web = decodePNG(webPNG);
  const width = Math.min(native.width, web.width); const height = Math.min(native.height, web.height);
  let different = 0;
  const diff = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) for (let x = 0; x < width; x += 1) {
    const a = (y * native.width + x) * 4; const b = (y * web.width + x) * 4; const d = (y * width + x) * 4;
    const delta = Math.max(Math.abs(native.pixels[a] - web.pixels[b]), Math.abs(native.pixels[a + 1] - web.pixels[b + 1]), Math.abs(native.pixels[a + 2] - web.pixels[b + 2]));
    if (delta > 48) different += 1;
    diff[d] = 255; diff[d + 1] = delta > 48 ? 0 : 255 - delta; diff[d + 2] = delta > 48 ? 0 : 255 - delta; diff[d + 3] = 255;
  }
  const gutter = 8;
  const sheet = { width: width * 3 + gutter * 2, height, pixels: Buffer.alloc((width * 3 + gutter * 2) * height * 4, 200) };
  const blit = (image, offset) => { for (let y = 0; y < height; y += 1) image.pixels.copy(sheet.pixels, (y * sheet.width + offset) * 4, (y * image.width) * 4, (y * image.width + width) * 4); };
  blit(native, 0); blit(web, width + gutter); blit({ width, pixels: diff }, (width + gutter) * 2);
  fs.writeFileSync(path.join(compareDirectory, fileName(box.name)), encodePNG(sheet));
  report.push({ name: box.name, diffPercent: +(100 * different / (width * height)).toFixed(2), sizeMatch: native.width === web.width && native.height === web.height, diagnostics: box.diagnostics.map((item) => item.code) });
}
report.sort((a, b) => (b.diffPercent ?? 100) - (a.diffPercent ?? 100));
fs.writeFileSync(path.join(root, process.env.SW_FONTS ? `dist/compare-report-${process.env.SW_FONTS}-fonts.json` : "dist/compare-report.json"), JSON.stringify(report, null, 1));
const scored = report.filter((item) => item.diffPercent !== undefined);
const median = scored.length ? scored.map((item) => item.diffPercent).sort((a, b) => a - b)[Math.floor(scored.length / 2)] : null;
console.log(`compared ${scored.length}, errors ${report.length - scored.length}, median diff ${median}%`);
for (const item of report.slice(0, 15)) console.log(String(item.diffPercent ?? item.error).padStart(7), item.name);

// Coverage by size: one row per family and device profile ("small",
// "medium~iphone-430", ...). "Same" is the share of matching pixels.
const groups = new Map();
for (const item of scored) {
  const key = item.name.startsWith("case/") ? "calibration cases" : item.name.slice(item.name.lastIndexOf("@") + 1);
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(item.diffPercent);
}
const summarize = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const share = (limit) => +(100 * sorted.filter((value) => value <= limit).length / sorted.length).toFixed(1);
  return {
    renders: sorted.length, medianDiff: sorted[Math.floor(sorted.length / 2)],
    meanSame: +(100 - sorted.reduce((sum, value) => sum + value, 0) / sorted.length).toFixed(2),
    within1: share(1), within3: share(3), within5: share(5),
  };
};
const summary = { all: summarize(scored.map((item) => item.diffPercent)), sizes: Object.fromEntries([...groups].sort(([a], [b]) => a.localeCompare(b)).map(([key, values]) => [key, summarize(values)])) };
fs.writeFileSync(path.join(root, "dist/compare-summary.json"), JSON.stringify(summary, null, 1));
console.log("\n| Size | Renders | Median diff | Mean same | ≥99% same | ≤3% diff | ≤5% diff |\n| --- | --- | --- | --- | --- | --- | --- |");
for (const [key, row] of [...Object.entries(summary.sizes), ["all", summary.all]]) {
  console.log(`| ${key} | ${row.renders} | ${row.medianDiff}% | ${row.meanSame}% | ${row.within1}% | ${row.within3}% | ${row.within5}% |`);
}
browser.close(); server.close();
await new Promise((resolve) => { chrome.once("exit", resolve); chrome.kill(); });
fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
