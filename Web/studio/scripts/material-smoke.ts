import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory, clickReady } from "../../preview-engine/scripts/lib/chrome.mjs";

const dist=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"../dist");
const server=await serveDirectory(dist),chrome=await launchChrome({width:1440,height:1060,scale:1});
const page=await chrome.newPage();
async function savedSource() {
  await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
  // CodeMirror virtualizes offscreen lines: .cm-content.textContent is not
  // the document. Compare the actual persisted source across preview changes.
  return page.evaluate<string>(`(async()=>{
    const db=await new Promise((resolve,reject)=>{const request=indexedDB.open('scriptwidget-studio',1);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)});
    try {
      const id=JSON.parse(localStorage.getItem('scriptwidget-studio.project'));
      const project=await new Promise((resolve,reject)=>{const request=db.transaction('projects').objectStore('projects').get(id);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)});
      return project.files[document.getElementById('current-file').textContent];
    } finally {db.close()}
  })()`);
}
try {
  await page.call("Emulation.setEmulatedMedia",{features:[{name:"prefers-color-scheme",value:"light"},{name:"prefers-reduced-motion",value:"no-preference"},{name:"prefers-reduced-transparency",value:"no-preference"}]});
  await page.goto(`${server.origin}/index.html`); await page.waitFor("!!document.querySelector('.sw-widget')",20000);
  const click = (expression: string) => clickReady(page, expression);
  const button=(name:string)=>`[...document.querySelectorAll('.sw-layout button')].find(b=>b.textContent===${JSON.stringify(name)})`;
  const choose=async(id:string,label:string)=>{
    await click(`document.getElementById(${JSON.stringify(id)})`);
    await page.waitFor(`!![...document.querySelectorAll('[role=option]')].find(o=>o.textContent===${JSON.stringify(label)})`);
    await click(`[...document.querySelectorAll('[role=option]')].find(o=>o.textContent===${JSON.stringify(label)})`);
    await page.waitFor(`document.getElementById(${JSON.stringify(id)}).getAttribute('data-state')==='closed' && document.getElementById(${JSON.stringify(id)}).textContent===${JSON.stringify(label)}`);
  };
  await click("document.getElementById('open-templates')");
  await page.waitFor("!![...document.querySelectorAll('.template-card')].find(card=>card.textContent.includes('Material Study') && card.querySelector('span.text-primary')?.textContent==='Gallery')");
  await click("[...document.querySelectorAll('.template-card')].find(card=>card.textContent.includes('Material Study') && card.querySelector('span.text-primary')?.textContent==='Gallery')");
  await page.waitFor("!!document.getElementById('template-copy')");
  await page.waitFor("!document.querySelector('[role=dialog]').getAnimations({subtree:true}).some(a=>a.playState==='running')");
  // Keep the closing Gallery overlay alive after the fast material preview.
  await page.call("Animation.enable");
  await page.call("Animation.setPlaybackRate", {playbackRate:0.1});
  await click("document.getElementById('template-copy')");
  await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material=thin]')",20000);
  assert.equal(await page.evaluate("document.querySelector('.sw-widget [data-sw-material]').style.backdropFilter.includes('blur')"),true);
  assert.equal(await page.evaluate("[...document.querySelectorAll('.sw-widget [style]')].some(e=>e.style.transform.includes('rotate3d'))"),true);
  const code=await savedSource();
  assert.equal(typeof code,"string");
  assert.ok(code.includes('backgroundMaterial="thin"'));
  await click("document.getElementById('reduce-transparency')");
  await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material-fallback=solid]')",20000);
  assert.equal(await page.evaluate("document.querySelector('.sw-widget [data-sw-material]').style.backdropFilter"),"");
  await click("document.getElementById('reduce-motion')");
  await page.waitFor("![...document.querySelectorAll('.sw-widget [style]')].some(e=>e.style.transform.includes('rotate3d'))",20000);
  assert.equal(await savedSource(),code);
  if(process.env.SCRIPTWIDGET_MATERIAL_REDUCED)fs.writeFileSync(process.env.SCRIPTWIDGET_MATERIAL_REDUCED,await page.screenshot());
  await click("document.getElementById('reduce-transparency')");await click("document.getElementById('reduce-motion')");
  await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material]:not([data-sw-material-fallback])')",20000);
  await choose("rendering-mode","Accented");
  await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material-fallback=system]')",20000);
  await choose("rendering-mode","Full color");
  await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material]:not([data-sw-material-fallback])')",20000);
  // CSS-disabled platforms get the same solid fallback, without rewriting code.
  await page.evaluate("window.__supports=CSS.supports;CSS.supports=(...args)=>['backdrop-filter','-webkit-backdrop-filter'].includes(args[0])?false:window.__supports.apply(CSS,args)");
  await choose("appearance","Dark");await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material-fallback=solid]')",20000);
  await page.evaluate("CSS.supports=window.__supports");await choose("appearance","Light");
  await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material]:not([data-sw-material-fallback])')",20000);
  if(process.env.SCRIPTWIDGET_MATERIAL_NORMAL)fs.writeFileSync(process.env.SCRIPTWIDGET_MATERIAL_NORMAL,await page.screenshot());
  // Shared Layout metadata exposes the new enum as a normal source-preserving edit.
  await click(button("Layout"));await click("[...document.querySelectorAll('.sw-layout-layer')].find(row=>row.textContent==='<vstack>')");
  await page.evaluate("const choose=document.querySelector('select[aria-label=\"Layout property\"]');choose.value='backgroundMaterial';choose.dispatchEvent(new Event('change',{bubbles:true}));document.querySelector('select[aria-label=\"Layout property value\"]').value='regular'");
  await click(button("Apply"));await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material=regular]')",20000);
  await click(button("Undo"));await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material=thin]')",20000);
  await click(button("Redo"));await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material=regular]')",20000);
  await page.call("Emulation.setDeviceMetricsOverride",{width:390,height:844,deviceScaleFactor:1,mobile:false});
  assert.equal(await page.evaluate("document.documentElement.scrollWidth<=innerWidth+1"),true);
  await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
  await page.goto(`${server.origin}/index.html`);await page.waitFor("!!document.querySelector('.sw-widget [data-sw-material=regular]')",20000);
  const errors=page.consoleMessages.filter(line=>line.startsWith("exception")||line.startsWith("error"));assert.deepEqual(errors,[]);
  console.log("✓ Material: Gallery install, CSS material, transparency/motion fallbacks, accented mode, missing-CSS fallback, source preservation, Layout enum/undo, phone and saved reload passed");
} catch(error) {
  console.log(await page.evaluate("({appearance:document.getElementById('appearance')?.textContent,mode:document.getElementById('rendering-mode')?.textContent,cssSupports:CSS.supports('backdrop-filter','blur(1px)'),materials:[...document.querySelectorAll('[data-sw-material]')].map(e=>({value:e.dataset.swMaterial,fallback:e.dataset.swMaterialFallback,filter:e.style.backdropFilter})),problems:document.getElementById('problems')?.textContent})"));
  throw error;
} finally {await chrome.close();server.close();}
