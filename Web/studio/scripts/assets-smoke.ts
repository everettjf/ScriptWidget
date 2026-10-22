import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "../../preview-engine/scripts/lib/chrome.mjs";

const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dist");
const sample = fs.readFileSync(new URL("../../preview-engine/test/parity/assets/Sample.png",import.meta.url));
const fixture = JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/asset-edit-trees.json",import.meta.url),"utf8"));
const server = await serveDirectory(dist,{"/__sample.png":{type:"image/png",body:sample}}), chrome = await launchChrome({width:1440,height:1000,scale:1});
try {
  const page = await chrome.newPage();
  await page.call("Emulation.setEmulatedMedia",{features:[{name:"prefers-color-scheme",value:"light"}]});
  await page.goto(`${server.origin}/index.html`); await page.waitFor("!!document.querySelector('.sw-widget')",20000);
  const button = (name: string) => `[...document.querySelectorAll('.sw-layout button')].find(button=>button.textContent===${JSON.stringify(name)})`;
  const click = async (expression: string) => {
    await page.evaluate(`(${expression}).scrollIntoView({block:'center'})`);
    const position = await page.evaluate<{x:number;y:number}>(`(() => {const r=(${expression}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
    await page.call("Input.dispatchMouseEvent",{type:"mousePressed",...position,button:"left",clickCount:1});
    await page.call("Input.dispatchMouseEvent",{type:"mouseReleased",...position,button:"left",clickCount:1});
  };
  const code = () => page.evaluate<string>("document.querySelector('.cm-content').textContent");
  await page.evaluate("document.querySelector('.cm-content').focus();document.execCommand('selectAll')");
  await page.call("Input.insertText",{text:fixture.original});
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Make it yours')",20000);
  if (process.env.SCRIPTWIDGET_ASSETS_BEFORE) fs.writeFileSync(process.env.SCRIPTWIDGET_ASSETS_BEFORE,await page.screenshot());
  await click(button("Theme")); await click(button("Connect layout to Meadow theme")); await click(button("Assets"));
  await click(button("Insert Pebble friend")); await page.waitFor("document.querySelector('.cm-content').textContent.includes('64,38')");
  const withPet = await code(); assert.ok(withPet.includes("SPDX-License-Identifier: MIT"));
  assert.ok(withPet.includes("widgetTheme.accent"));
  await click(button("Undo")); assert.ok(!(await code()).includes("64,38"));
  await click(button("Redo")); assert.equal(await code(),withPet);
  // Import through the actual image input; React updates the resource list
  // without replacing the source or its undo history.
  await page.evaluate(`(async () => {const bytes=await(await fetch('/__sample.png')).arrayBuffer();const files=new DataTransfer();files.items.add(new File([bytes],'Sample.png',{type:'image/png'}));const input=document.getElementById('image-input');input.files=files.files;input.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  await page.waitFor("document.querySelector('select[aria-label=\"Package image\"]')?.value==='image/sample.png'");
  assert.equal(await code(),withPet);
  await click(button("Insert package image")); await page.waitFor("!!document.querySelector('.sw-widget img')",20000);
  assert.equal(await page.evaluate("document.querySelector('.sw-widget img').complete && document.querySelector('.sw-widget img').naturalWidth>0"),true);
  const withPhoto = await code(); assert.ok(withPhoto.includes('name={"sample.png"}'));
  await click(button("Undo")); await page.waitFor("!document.querySelector('.sw-widget img')",20000);
  await click(button("Redo")); await page.waitFor("!!document.querySelector('.sw-widget img')",20000);
  await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
  if (process.env.SCRIPTWIDGET_ASSETS_AFTER) fs.writeFileSync(process.env.SCRIPTWIDGET_ASSETS_AFTER,await page.screenshot());
  await page.goto(`${server.origin}/index.html`); await page.waitFor("!!document.querySelector('.sw-widget img')",20000);
  assert.equal(await code(),withPhoto);
  await click(button("Assets"));
  assert.equal(await page.evaluate("document.querySelector('select[aria-label=\"Package image\"]').value"),'image/sample.png');
  // Additional original marks use the same insertion/save path.
  for (const name of ["Bloom mark","Leaf mark"]) { await click(button(`Insert ${name}`)); await click(button("Undo")); assert.equal(await code(),withPhoto); }
  await page.call("Emulation.setDeviceMetricsOverride",{width:390,height:844,deviceScaleFactor:1,mobile:false});
  assert.equal(await page.evaluate("document.documentElement.scrollWidth<=innerWidth+1"),true);
  assert.equal(await page.evaluate("document.querySelector('.sw-layout-body').scrollWidth<=document.querySelector('.sw-layout-body').clientWidth+1"),true);
  assert.equal(await page.evaluate("document.querySelector('select[aria-label=\"Package image\"]').value"),'image/sample.png');
  const errors = page.consoleMessages.filter(line=>line.startsWith("exception")||line.startsWith("error")); assert.deepEqual(errors,[]);
  console.log("✓ Assets: originals, theme binding, image input/resource updates, decoded preview, undo/redo, save/reload, retained license and phone sizing passed");
} finally { await chrome.close(); server.close(); }
