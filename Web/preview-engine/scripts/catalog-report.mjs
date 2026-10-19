// Builds a self-contained HTML page comparing every component catalog item
// (test/catalog/catalog.json) on iOS native, the web engine with the iOS
// profile, macOS native, and the web engine with the macos profile.
//
// Usage: node scripts/catalog-report.mjs <ios-compare-dir> <ios-report.json> <mac-batch-dir> <output.html>
//   ios-compare-dir   dist/compare from scripts/compare-snapshots.mjs catalog/
//                     (native | web | diff sheets)
//   ios-report.json   dist/compare-report.json from the same run
//   mac-batch-dir     ScriptWidget Preview --batch <dir> --filter catalog/
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { decodePNG, encodePNG } from "./png.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const [iosCompare, iosReportPath, macBatch, output] = process.argv.slice(2);
if (!output) { console.error("Usage: node scripts/catalog-report.mjs <ios-compare-dir> <ios-report.json> <mac-batch-dir> <output.html>"); process.exit(1); }

const catalog = JSON.parse(fs.readFileSync(path.join(root, "test/catalog/catalog.json"), "utf8"));
const iosReport = new Map(JSON.parse(fs.readFileSync(iosReportPath, "utf8")).map((item) => [item.name, item]));
const macReport = new Map(JSON.parse(fs.readFileSync(path.join(macBatch, "report.json"), "utf8")).results.map((item) => [item.name, item]));
const fileName = (name) => name.replaceAll("/", "__").replaceAll(" ", "_") + ".png";
const dataURL = (buffer) => `data:image/png;base64,${buffer.toString("base64")}`;

/// Splits a compare-snapshots sheet (three panels, 8 px gutters) into PNGs.
function panels(file) {
  const sheet = decodePNG(fs.readFileSync(file));
  const width = (sheet.width - 16) / 3;
  return [0, 1, 2].map((panel) => {
    const pixels = Buffer.alloc(width * sheet.height * 4);
    for (let y = 0; y < sheet.height; y += 1) sheet.pixels.copy(pixels, y * width * 4, (y * sheet.width + panel * (width + 8)) * 4, (y * sheet.width + panel * (width + 8) + width) * 4);
    return dataURL(encodePNG({ width, height: sheet.height, pixels }));
  });
}
const read = (file) => (fs.existsSync(file) ? dataURL(fs.readFileSync(file)) : null);

// Known reasons a render is not a meaningful comparison.
const notes = {
  toggle: "iOS: ImageRenderer draws Toggle as a placeholder in snapshots, so the iOS comparison is not meaningful. macOS widgets draw a checkbox, and the web now draws one too.",
  "text-designs": "Chrome only: Chrome cannot use SF Mono or New York by name, so monospaced and serif text fall back to Menlo and Georgia. WebKit (the macOS column, Safari) uses the Apple fonts.",
};

const tagPattern = /<([a-z][a-zA-Z0-9]*)[\s>/]/g;
const items = catalog.map((item) => {
  const name = `catalog/${item.id}@${item.size}`;
  const ios = iosReport.get(name); const mac = macReport.get(name);
  const sheet = path.join(iosCompare, fileName(name));
  const [iosNative, iosWeb, iosDiff] = fs.existsSync(sheet) ? panels(sheet) : [null, null, null];
  const slug = item.id.replace(/^\d+-/, "");
  return {
    id: item.id, title: item.title, group: item.group, size: item.size, dark: item.dark, source: item.source,
    tags: [...new Set([...item.source.matchAll(tagPattern)].map((match) => match[1]))],
    note: notes[slug] ?? null,
    ios: { diff: ios?.diffPercent ?? null, native: iosNative, web: iosWeb, delta: iosDiff },
    mac: { diff: mac ? +mac.percent.toFixed(2) : null, native: read(path.join(macBatch, "native", fileName(name))), web: read(path.join(macBatch, "web", fileName(name))), delta: read(path.join(macBatch, "diff", fileName(name))) },
  };
});

const page = fs.readFileSync(path.join(root, "scripts/catalog-report.html"), "utf8")
  .replace("/*__DATA__*/null", JSON.stringify({ generated: new Date().toISOString().slice(0, 10), items }).replaceAll("</", "<\\/"));
fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
fs.writeFileSync(output, page);
const mean = (values) => +(100 - values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(2);
console.log(`${items.length} items, iOS mean same ${mean(items.map((item) => item.ios.diff ?? 100))}%, macOS mean same ${mean(items.map((item) => item.mac.diff ?? 100))}%, ${(fs.statSync(output).size / 1e6).toFixed(1)} MB`);
