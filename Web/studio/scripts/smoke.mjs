// Loads the built Studio in headless Chrome and checks that the sandboxed
// runtime renders the starter widget, a template, and that export works.
// Usage: npm run build && node scripts/smoke.mjs [screenshot.png]
//        SITE_ROOT=<assembled _site> node scripts/smoke.mjs   (tests /studio/ like GitHub Pages)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "../../preview-engine/scripts/lib/chrome.mjs";

const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dist");
const fixture = fs.readFileSync(path.resolve(dist, "../../preview-engine/test/fixtures/web-export.swt"));
const siteRoot = process.env.SITE_ROOT ? path.resolve(process.env.SITE_ROOT) : null;
const server = await serveDirectory(siteRoot ?? dist, { "/__fixture.swt": { type: "application/zip", body: fixture } });
const studioPath = siteRoot ? "/studio/index.html" : "/index.html";
const chrome = await launchChrome({ width: 1400, height: 900, scale: 1 });
let failed = false;
try {
  const page = await chrome.newPage();
  await page.goto(`${server.origin}${studioPath}`);
  await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
  const status = await page.evaluate("document.getElementById('preview-status').textContent");
  console.log("starter:", status);
  const sandboxed = await page.evaluate("document.querySelector('iframe').getAttribute('sandbox')");
  if (sandboxed !== "allow-scripts") throw new Error("runtime frame is not sandboxed");
  // Open a template.
  await page.evaluate("document.getElementById('open-templates').click()");
  await page.waitFor("document.querySelectorAll('.template-card').length > 50");
  const count = await page.evaluate("document.querySelectorAll('.template-card').length");
  await page.evaluate("[...document.querySelectorAll('.template-card')].find((card) => card.textContent.includes('Image Basic Usage') || card.textContent.includes('Image')).click()");
  await page.waitFor("document.getElementById('preview-status').textContent.startsWith('Web fast preview') && !!document.querySelector('.sw-widget img')", 20000);
  console.log(`templates: ${count}; image template rendered`);
  // Import a .swt through the file input, as a user would.
  await page.evaluate(`(async () => {
    const bytes = await (await fetch("/__fixture.swt")).arrayBuffer();
    const transfer = new DataTransfer();
    transfer.items.add(new File([bytes], "Web Export Fixture.swt", { type: "application/zip" }));
    const input = document.getElementById("import-input");
    input.files = transfer.files;
    input.dispatchEvent(new Event("change"));
  })()`);
  await page.waitFor("document.getElementById('project-name').value === 'Web Export Fixture' && document.querySelector('.sw-widget')?.textContent.includes('From the web')", 20000);
  console.log("imported .swt renders");
  if (process.argv[2]) fs.writeFileSync(process.argv[2], await page.screenshot());
  const problems = await page.evaluate("document.getElementById('problems').textContent");
  console.log("problems:", problems.slice(0, 200));
  if (page.consoleMessages.some((line) => line.startsWith("exception"))) { console.log(page.consoleMessages.join("\n")); failed = true; }
} catch (error) {
  console.error(error.message);
  failed = true;
} finally {
  await chrome.close();
  server.close();
}
if (failed) process.exit(1);
console.log("✓ Studio smoke test passed");
