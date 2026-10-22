import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "../../preview-engine/scripts/lib/chrome.mjs";
import { importPackage } from "../../preview-engine/src/package/index.js";

const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dist");
const server = await serveDirectory(dist), chrome = await launchChrome({ width: 1500, height: 1180, scale: 1 });
try {
  const page = await chrome.newPage();
  await page.call("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: "light" }] });
  await page.goto(`${server.origin}/index.html`); await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
  const click = async (expression: string) => {
    await page.evaluate(`(${expression}).scrollIntoView({block:'center'})`);
    const point = await page.evaluate<{ x: number; y: number }>(`(()=>{const r=(${expression}).getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);
    await page.call("Input.dispatchMouseEvent", { type: "mousePressed", ...point, button: "left", clickCount: 1 });
    await page.call("Input.dispatchMouseEvent", { type: "mouseReleased", ...point, button: "left", clickCount: 1 });
  };
  const select = async (id: string, value: string) => page.evaluate(`(()=>{const input=document.getElementById(${JSON.stringify(id)});Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,'value').set.call(input,${JSON.stringify(value)});input.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  const edit = async (source: string) => {
    await page.evaluate("document.querySelector('.cm-content').focus();document.execCommand('selectAll')");
    await page.call("Input.insertText", { text: source });
  };
  await click("[...document.querySelectorAll('#file-list button')].find(b=>b.textContent==='widget.json')");
  const manifest = { formatVersion: 2, id: "local.spotify-profile-smoke", name: "Spotify profile preview", version: "1.0.0", runtimeVersion: "1.0", minimumRuntimeVersion: "1.4", entry: "main.jsx", supportedFamilies: ["systemSmall", "systemMedium", "systemLarge"], permissions: ["services", "network"], networkDomains: ["api.spotify.com", "accounts.spotify.com"] };
  await edit(JSON.stringify(manifest, null, 2));
  await click("[...document.querySelectorAll('#file-list button')].find(b=>b.textContent==='main.jsx')");
  const source = `let title='Spotify unavailable',detail='Open native Service Accounts';
const status=await $services.status('spotify');
if(status==='notConnected')title='Connect Spotify';
else if(status==='notGranted')title='No profile access';
else if(status==='connected'){try{const p=await $services.profile('spotify');title=p.displayName||p.subject;detail='Spotify profile';}catch(e){const error=String(e);title=error.includes('service_expired')?'Refresh connection':error.includes('service_rate_limit')?'Rate limited':'Service unavailable';}}
$render(<vstack frame="max" padding="18" spacing="7" alignment="leading" background="#f0f9f5"><icon systemName="person.crop.circle.fill" size="30" color="#166534"/><text font="title2" color="#152f23">{title}</text><text font="caption" color="#506a5c">{detail}</text></vstack>);`;
  await edit(source); await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Sample listener')", 20000);
  await click("[...document.querySelectorAll('[role=tab]')].find(tab=>tab.textContent==='Mock Data')");
  await page.waitFor("document.getElementById('mock-data-panel').offsetParent!==null");
  await select("mock-group", "services"); await select("mock-api", "$services.profile"); await select("mock-service-provider", "spotify");
  await page.waitFor("document.getElementById('mock-result.displayName')?.value==='Sample listener'");
  await page.evaluate("(()=>{const input=document.getElementById('mock-result.displayName');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'Edited listener');input.dispatchEvent(new Event('input',{bubbles:true}));})()");
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Edited listener')", 20000);
  await select("mock-service-provider", "github"); await page.waitFor("document.getElementById('mock-result.username')?.value==='octocat'");
  assert.equal(await page.evaluate("document.querySelector('.sw-widget').textContent.includes('Edited listener')"), true);
  await select("mock-service-provider", "spotify");
  for (const [label, expected] of [["No widget access", "No profile access"], ["Disconnected", "Connect Spotify"], ["Token expired", "Refresh connection"], ["Rate limited", "Rate limited"], ["Offline", "Service unavailable"], ["Unavailable", "Spotify unavailable"], ["Name not shared", "sample-listener"], ["Sample success", "Sample listener"]]) {
    await click(`[...document.querySelectorAll('#mock-data-panel button')].find(b=>b.textContent===${JSON.stringify(label)})`);
    await page.waitFor(`document.querySelector('.sw-widget')?.textContent.includes(${JSON.stringify(expected)})`, 20000);
  }
  assert.equal(await page.evaluate("[...document.querySelectorAll('.cm-content .cm-line')].map(line=>line.textContent).join(String.fromCharCode(10))"), source);
  if (process.env.SCRIPTWIDGET_SPOTIFY_PROFILE_WEB) {
    await page.call("Emulation.setDeviceMetricsOverride", { width: 1500, height: 1800, deviceScaleFactor: 1, mobile: false });
    await page.evaluate("document.querySelector('section[aria-label=Preview]').scrollTop=0");
    fs.writeFileSync(process.env.SCRIPTWIDGET_SPOTIFY_PROFILE_WEB, await page.screenshot());
  }
  await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
  await page.evaluate("window.__objectURL=URL.createObjectURL;URL.createObjectURL=blob=>{window.__exported=blob;return window.__objectURL.call(URL,blob)}");
  await click("document.getElementById('export-package')"); await page.waitFor("window.__exported?.type==='application/zip'");
  const encoded = await page.evaluate<string>("(async()=>{const bytes=new Uint8Array(await window.__exported.arrayBuffer());let text='';for(const b of bytes)text+=String.fromCharCode(b);return btoa(text)})()");
  const imported = await importPackage(Buffer.from(encoded, "base64"));
  if (imported.error !== undefined) throw new Error(imported.error);
  assert.equal(imported.files["main.jsx"], source);
  assert.ok(!JSON.stringify(imported.files).includes("sample-listener"));
  await page.goto(`${server.origin}/index.html`); await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Sample listener')", 20000);
  await click("[...document.querySelectorAll('[role=tab]')].find(tab=>tab.textContent==='Mock Data')");
  await page.waitFor("document.getElementById('mock-data-panel').offsetParent!==null");
  await select("mock-group", "services"); await select("mock-api", "$services.profile"); await select("mock-service-provider", "spotify");
  await page.waitFor("document.getElementById('mock-result.displayName')?.value==='Sample listener'");
  const playbackSource = `let title='No current playback';try{const p=await $services.playback('spotify');if(p)title=p.itemType==='unsupported'?'Unsupported item':(p.isPlaying?'Playing: ':'Paused: ')+p.title;}catch(e){const error=String(e);title=error.includes('service_permission')?'Allow playback':error.includes('service_not_connected')?'Connect Spotify':error.includes('service_expired')?'Refresh connection':error.includes('service_rate_limit')?'Rate limited':error.includes('service_operation')?'Spotify unavailable':'Service unavailable';}$render(<text>{title}</text>);`;
  await edit(playbackSource);
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Playing: Morning Light')",20000);
  await select("mock-api","$services.playback");
  await page.waitFor("document.getElementById('mock-result.title')?.value==='Morning Light'");
  await page.evaluate("(()=>{const input=document.getElementById('mock-result.title');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'Edited playback');input.dispatchEvent(new Event('input',{bubbles:true}));})()");
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Edited playback')",20000);
  for (const [label,expected] of [["Paused","Paused: Morning Light"],["No current playback","No current playback"],["Unsupported item","Unsupported item"],["No playback access","Allow playback"],["Disconnected","Connect Spotify"],["Token expired","Refresh connection"],["Rate limited","Rate limited"],["Offline","Service unavailable"],["Unavailable","Spotify unavailable"],["Playing","Playing: Morning Light"]]) {
    await click(`[...document.querySelectorAll('#mock-data-panel button')].find(b=>b.textContent===${JSON.stringify(label)})`);
    await page.waitFor(`document.querySelector('.sw-widget')?.textContent.includes(${JSON.stringify(expected)})`,20000);
  }
  if (process.env.SCRIPTWIDGET_SPOTIFY_PLAYBACK_WEB) {
    await page.call("Emulation.setDeviceMetricsOverride", {width:1500,height:1800,deviceScaleFactor:1,mobile:false});
    await page.evaluate("document.querySelector('section[aria-label=Preview]').scrollTop=0");
    fs.writeFileSync(process.env.SCRIPTWIDGET_SPOTIFY_PLAYBACK_WEB,await page.screenshot());
  }
  await select("mock-service-provider","github");
  await page.waitFor("document.getElementById('mock-api')?.value==='$services.profile'");
  assert.equal(await page.evaluate("[...document.getElementById('mock-api').options].some(option=>option.value==='$services.playback')"),false);
  await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
  await page.goto(`${server.origin}/index.html`);
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Playing: Morning Light')",20000);
  await page.call("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 1, mobile: false });
  assert.equal(await page.evaluate("document.documentElement.scrollWidth<=innerWidth+1"), true);
  assert.deepEqual(page.consoleMessages.filter((line: string) => line.startsWith("exception") || line.startsWith("error")), []);
  console.log("✓ Spotify profile: manifest/source editing, provider-isolated mocks, editable name, eight states, unchanged source, package excludes fixtures, reload, separate playback access, editable track, ten playback states and phone width passed");
} finally { await chrome.close(); server.close(); }
