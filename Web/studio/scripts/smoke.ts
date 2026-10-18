// Loads the built Studio in headless Chrome and checks that the sandboxed
// runtime renders the starter widget, a template, an imported .swt, and that
// phones show the preview before the editor.
// Usage: npm run build && node scripts/smoke.ts [screenshot.png]
//        SITE_ROOT=<assembled _site> node scripts/smoke.ts   (tests /studio/ like GitHub Pages)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory, type ChromePage } from "../../preview-engine/scripts/lib/chrome.mjs";

const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dist");
const fixture = fs.readFileSync(path.resolve(dist, "../../preview-engine/test/fixtures/web-export.swt"));
const siteRoot = process.env.SITE_ROOT ? path.resolve(process.env.SITE_ROOT) : null;
const server = await serveDirectory(siteRoot ?? dist, { "/__fixture.swt": { type: "application/zip", body: fixture } });
const studioURL = `${server.origin}${siteRoot ? "/studio/index.html" : "/index.html"}`;
const exceptions = (page: ChromePage) => page.consoleMessages.filter((line) => line.startsWith("exception") || line.startsWith("error"));
let failed = false;

async function desktop(): Promise<void> {
  const chrome = await launchChrome({ width: 1400, height: 900, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(studioURL);
    await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
    console.log("starter:", await page.evaluate<string>("document.getElementById('preview-status').textContent"));
    const sandboxed = await page.evaluate<string>("document.querySelector('iframe').getAttribute('sandbox')");
    if (sandboxed !== "allow-scripts") throw new Error("runtime frame is not sandboxed");
    // Open a template.
    await page.evaluate("document.getElementById('open-templates').click()");
    await page.waitFor("document.querySelectorAll('.template-card').length > 50");
    const count = await page.evaluate<number>("document.querySelectorAll('.template-card').length");
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
      input.dispatchEvent(new Event("change", { bubbles: true }));
    })()`);
    await page.waitFor("document.getElementById('project-name').value === 'Web Export Fixture' && document.querySelector('.sw-widget')?.textContent.includes('From the web')", 20000);
    console.log("imported .swt renders");
    // Editing the source updates the preview.
    await page.evaluate("document.querySelector('.cm-content').focus(); document.execCommand('selectAll')");
    await page.call("Input.insertText", { text: "$render(<text>Edited in the smoke test</text>)" });
    await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Edited in the smoke test')", 20000);
    console.log("editing updates the preview");
    if (process.argv[2]) fs.writeFileSync(process.argv[2], await page.screenshot());
    console.log("problems:", (await page.evaluate<string>("document.getElementById('problems').textContent")).slice(0, 200));
    if (exceptions(page).length) { console.log(exceptions(page).join("\n")); failed = true; }
  } finally {
    await chrome.close();
  }
}

async function phone(): Promise<void> {
  const chrome = await launchChrome({ width: 390, height: 844, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(studioURL);
    await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
    const order = await page.evaluate<{ stage: number; editor: number; overflow: number }>(`({
      stage: document.getElementById('stage').getBoundingClientRect().top,
      editor: document.getElementById('editor').getBoundingClientRect().top,
      overflow: document.documentElement.scrollWidth - window.innerWidth,
    })`);
    if (!(order.stage < order.editor)) throw new Error(`on phones the preview should come before the editor (${JSON.stringify(order)})`);
    if (order.overflow > 1) throw new Error(`the phone layout scrolls horizontally by ${order.overflow}px`);
    if (process.argv[3]) fs.writeFileSync(process.argv[3], await page.screenshot());
    console.log("phone: preview first, no horizontal scroll");
    if (exceptions(page).length) { console.log(exceptions(page).join("\n")); failed = true; }
  } finally {
    await chrome.close();
  }
}

try {
  await desktop();
  await phone();
} catch (error) {
  console.error((error as Error).message);
  failed = true;
} finally {
  server.close();
}
if (failed) process.exit(1);
console.log("✓ Studio smoke test passed");
