import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "../../preview-engine/scripts/lib/chrome.mjs";

const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dist");
const server = await serveDirectory(dist), chrome = await launchChrome({width:1440,height:1000,scale:1});
const source = '// Keep this JavaScript and comment.\nconst day = "Monday";\n$render(<vstack alignment="leading" spacing="10" padding="18" background="#f2f5fc"><text font="caption" color="#677799">A fresh start</text><text font="title2" color="#24375d">Calm morning</text><hstack spacing="8"><icon systemName="sun.max.fill" size="20" color="#b48b38"/><text color="#677799">{day}</text></hstack></vstack>);\n';
try {
  const page = await chrome.newPage();
  await page.call("Emulation.setEmulatedMedia",{features:[{name:"prefers-color-scheme",value:"light"}]});
  await page.goto(`${server.origin}/index.html`); await page.waitFor("!!document.querySelector('.sw-widget')",20000);
  const pointer = async (expression: string) => page.evaluate<{x:number;y:number}>(`(() => {const r=(${expression}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
  const click = async (expression: string) => {
    const position = await pointer(expression);
    await page.call("Input.dispatchMouseEvent",{type:"mousePressed",...position,button:"left",clickCount:1});
    await page.call("Input.dispatchMouseEvent",{type:"mouseReleased",...position,button:"left",clickCount:1});
  };
  const choose = async (label: string, value: string) => page.evaluate(`(() => {const input=document.querySelector('select[aria-label=${JSON.stringify(label)}]');input.value=${JSON.stringify(value)};input.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  const fill = async (label: string, value: string) => page.evaluate(`document.querySelector('input[aria-label=${JSON.stringify(label)}]').value=${JSON.stringify(value)}`);
  const button = (label: string) => `[...document.querySelectorAll('.sw-layout button')].find(button=>button.textContent===${JSON.stringify(label)})`;
  const layer = (text: string) => `[...document.querySelectorAll('.sw-layout-layer')].find(button=>button.textContent.includes(${JSON.stringify(text)}))`;
  await page.evaluate("document.querySelector('.cm-content').focus();document.execCommand('selectAll')");
  await page.call("Input.insertText",{text:source}); await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Calm morning')",20000);
  if (process.env.SCRIPTWIDGET_LAYOUT_BEFORE) fs.writeFileSync(process.env.SCRIPTWIDGET_LAYOUT_BEFORE,await page.screenshot());
  await click("document.querySelector('.sw-layout-toggle')");
  await page.waitFor("document.querySelector('.sw-layout-toggle').getAttribute('aria-expanded')==='true' && document.querySelectorAll('.sw-layout-layer').length===6");
  await click(layer("Calm morning")); await fill("Layer text","Make today yours"); await click(button("Apply text"));
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Make today yours')",20000);
  await click(button("Undo")); await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Calm morning')",20000);
  await click(button("Redo")); await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Make today yours')",20000);
  // A real browser drag: capture Chrome's drag payload after pointer movement,
  // then deliver it to the target. No source is put on the system clipboard.
  let resolveDrag: (value: unknown) => void = () => {};
  const intercepted = new Promise(resolve => { resolveDrag=resolve; });
  page.onEvent("Input.dragIntercepted",params=>resolveDrag((params as {data:unknown}).data));
  await page.call("Input.setInterceptDrags",{enabled:true});
  const from = await pointer(layer("Make today yours")), to = await pointer(layer("A fresh start"));
  await page.call("Input.dispatchMouseEvent",{type:"mouseMoved",...from});
  await page.call("Input.dispatchMouseEvent",{type:"mousePressed",...from,button:"left",buttons:1,clickCount:1});
  await page.call("Input.dispatchMouseEvent",{type:"mouseMoved",x:from.x+12,y:from.y-10,button:"left",buttons:1});
  const timer = setTimeout(()=>resolveDrag(null),5000);
  const data = await intercepted; clearTimeout(timer); assert.ok(data,"Browser pointer drag should produce an intercepted HTML drag");
  for (const type of ["dragEnter","dragOver","drop"]) await page.call("Input.dispatchDragEvent",{type,...to,data});
  await page.call("Input.dispatchMouseEvent",{type:"mouseReleased",...to,button:"left",clickCount:1});
  await page.call("Input.setInterceptDrags",{enabled:false});
  await page.waitFor("[...document.querySelectorAll('.sw-layout-layer')][1]?.textContent.includes('Make today yours')");
  assert.equal(await page.evaluate("document.querySelector('.cm-content').textContent.includes('Keep this JavaScript and comment.')"),true);
  assert.equal(await page.evaluate("document.querySelector('.sw-widget').textContent.includes('Monday')"),true);
  // Alignment and color are edited on the actual source, then reflected by the
  // sandboxed renderer. Multiple element changes remain separate undo steps.
  await click(layer("<vstack>")); await choose("Layout property","alignment"); await choose("Layout property value","trailing"); await click(button("Apply"));
  await page.waitFor("document.querySelector('.cm-content').textContent.includes('alignment={\"trailing\"}')");
  await choose("Layout property","background"); await fill("Layout property value","#e9f5ef"); await click(button("Apply"));
  await page.waitFor("document.querySelector('.cm-content').textContent.includes('#e9f5ef')");
  await click(button("Add text")); await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('New text')",20000);
  await click(button("Delete layer")); await page.waitFor("!document.querySelector('.sw-widget')?.textContent.includes('New text')",20000);
  await click(layer("Make today yours"));
  await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
  if (process.env.SCRIPTWIDGET_LAYOUT_AFTER) fs.writeFileSync(process.env.SCRIPTWIDGET_LAYOUT_AFTER,await page.screenshot());
  const savedCode = await page.evaluate<string>("document.querySelector('.cm-content').textContent");
  await page.goto(`${server.origin}/index.html`);
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Make today yours')",20000);
  assert.equal(await page.evaluate("document.querySelector('.cm-content').textContent"),savedCode);
  // Source constructs outside the model remain untouched when Layout opens.
  await page.evaluate("document.querySelector('.cm-content').focus();document.execCommand('selectAll')");
  await page.call("Input.insertText",{text:'const widget=<text>Keep code</text>;$render(widget);'});
  await click("document.querySelector('.sw-layout-toggle')");
  await page.waitFor("document.querySelector('.sw-layout-body').textContent.includes('direct $render')");
  assert.equal(await page.evaluate("document.querySelector('.cm-content').textContent"),'const widget=<text>Keep code</text>;$render(widget);');
  await page.call("Emulation.setDeviceMetricsOverride",{width:390,height:844,deviceScaleFactor:1,mobile:false});
  await page.evaluate("document.querySelector('.cm-content').focus();document.execCommand('selectAll')");
  await page.call("Input.insertText",{text:source});
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('Calm morning')",20000);
  assert.equal(await page.evaluate("document.documentElement.scrollWidth<=innerWidth+1"),true,"Phone Layout must not cause page overflow");
  assert.equal(await page.evaluate("document.querySelector('.sw-layout-body').scrollWidth<=document.querySelector('.sw-layout-body').clientWidth+1"),true,"Phone property controls must fit the inspector");
  await page.evaluate(`${layer("Calm morning")}.click()`);
  await fill("Layer text","A little room"); await page.evaluate(`${button("Apply text")}.click()`);
  await page.waitFor("document.querySelector('.sw-widget')?.textContent.includes('A little room')",20000);
  if (process.env.SCRIPTWIDGET_LAYOUT_PHONE) fs.writeFileSync(process.env.SCRIPTWIDGET_LAYOUT_PHONE,await page.screenshot());
  const failures = page.consoleMessages.filter(line=>line.startsWith("exception")||line.startsWith("error")); assert.deepEqual(failures,[]);
  console.log("✓ Layout: select, text, undo/redo, real pointer drag, alignment, color, add/delete, preview, saved reload, unsupported source preservation and phone editing without overflow passed");
} finally { await chrome.close(); server.close(); }
