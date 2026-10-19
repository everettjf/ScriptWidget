// Cross-browser check for the built Studio and the engine's isolation page.
// Runs in CI on Linux and Windows with Playwright's Chromium, Firefox, and
// WebKit. Usage (after `npm run build` here and `npm run build` in
// Web/preview-engine): node scripts/cross-browser.ts [chromium|firefox|webkit ...]
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium, firefox, webkit, type Browser, type BrowserType } from "playwright";
import { serveDirectory } from "../../preview-engine/scripts/lib/chrome.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const dist = path.resolve(here, "../dist");
const engine = path.resolve(here, "../../preview-engine");
const fixture = fs.readFileSync(path.join(engine, "test/fixtures/web-export.swt"));
const browsers: Record<string, BrowserType> = { chromium, firefox, webkit };

interface EngineReport {
  parity: { matches: number; total: number };
  isolation: Array<{ name: string; text: string }>;
  timing: { warmEditMedianMilliseconds: number };
}

interface Result {
  browser: string;
  platform: string;
  studioStatus?: string | null;
  templates?: number;
  import?: string;
  parity?: string;
  probes?: Record<string, string>;
  warmEditMs?: number;
  checks?: Record<string, boolean>;
  pageErrors?: string[];
  error?: string;
  /// On failure: console errors and the visible page text, to see why.
  consoleErrors?: string[];
  pageText?: string;
}

declare global {
  interface Window { __report?: EngineReport }
}
// Native trees were recorded in this zone; date templates depend on it.
const { timeZone } = JSON.parse(fs.readFileSync(path.join(engine, "test/parity/native-trees.json"), "utf8"));
const requested = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(browsers);

const studio = await serveDirectory(dist, { "/__fixture.swt": { type: "application/zip", body: fixture } });
const engineServer = await serveDirectory(engine);
const results: Result[] = [];
let failed = false;

for (const name of requested) {
  const result: Result = { browser: name, platform: process.platform };
  let browser: Browser | undefined;
  let failureDetail: (() => Promise<void>) | undefined;
  try {
    const type = browsers[name];
    if (!type) throw new Error(`Unknown browser ${name}`);
    browser = await type.launch();
    const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, timezoneId: timeZone, locale: "en-US" });
    const page = await context.newPage();
    const errors: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    const consoleErrors: string[] = [];
    page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text().slice(0, 400)); });
    failureDetail = async () => {
      result.pageErrors = errors;
      result.consoleErrors = consoleErrors;
      result.pageText = (await page.evaluate(() => document.body?.innerText ?? "").catch(() => "")).replace(/\s+/g, " ").slice(0, 600);
    };

    // Studio: starter preview, templates, and .swt import.
    await page.goto(`${studio.origin}/index.html`);
    await page.waitForSelector(".sw-widget", { timeout: 60000 });
    result.studioStatus = await page.textContent("#preview-status");
    await page.click("#open-templates");
    await page.waitForFunction(() => document.querySelectorAll(".template-card").length > 50, null, { timeout: 60000 });
    result.templates = await page.locator(".template-card").count();
    await page.keyboard.press("Escape");
    await page.setInputFiles("#import-input", { name: "Web Export Fixture.swt", mimeType: "application/zip", buffer: fixture });
    await page.waitForFunction(() => document.querySelector(".sw-widget")?.textContent?.includes("From the web"), null, { timeout: 60000 });
    result.import = "ok";

    // Engine: byte-identical trees against the native reference, isolation probes.
    await page.goto(`${engineServer.origin}/demo/index.html`);
    await page.waitForFunction(() => window.__report !== undefined, null, { timeout: 180000 });
    const report = await page.evaluate(() => window.__report as EngineReport);
    result.parity = `${report.parity.matches}/${report.parity.total}`;
    result.probes = Object.fromEntries(report.isolation.map((probe) => [probe.name, probe.text.replace(/^\{.*"children":\["(.*)"\]\}$/, "$1")]));
    result.warmEditMs = report.timing.warmEditMedianMilliseconds;
    const probes = result.probes;
    const blocked = (key: string, pattern: RegExp) => pattern.test(probes[key] ?? "");
    const checks = {
      parity: report.parity.matches === report.parity.total,
      globals: blocked("scrubbed globals", /^undefined(,undefined)+$/),
      fetch: blocked("prototype fetch is blocked by CSP", /BLOCKED/),
      importScripts: blocked("prototype importScripts is blocked by CSP", /BLOCKED/),
      worker: blocked("nested Worker cannot be created", /absent|BLOCKED/),
      loop: blocked("infinite loop is terminated", /resourceLimit/),
    };
    result.checks = checks;
    result.pageErrors = errors;
    if (!Object.values(checks).every(Boolean) || errors.length) failed = true;
  } catch (error) {
    result.error = (error as Error).message.split("\n")[0];
    await failureDetail?.().catch(() => {});
    failed = true;
  } finally {
    await browser?.close();
  }
  results.push(result);
  console.log(JSON.stringify(result));
}

studio.close();
engineServer.close();
if (process.env.GITHUB_STEP_SUMMARY) {
  const rows = results.map((r) => `| ${r.browser} | ${r.platform} | ${r.error ? `❌ ${r.error}` : r.parity} | ${r.templates ?? "-"} | ${r.import ?? "-"} | ${r.checks ? Object.entries(r.checks).filter(([, ok]) => !ok).map(([k]) => k).join(", ") || "all blocked" : "-"} |`);
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, ["| Browser | OS | Tree parity | Templates | Import | Isolation |", "| --- | --- | --- | --- | --- | --- |", ...rows, ""].join("\n"));
}
if (failed) process.exit(1);
console.log(`✓ ${requested.join(", ")} passed on ${process.platform}`);
