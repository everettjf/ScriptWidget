import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "./lib/chrome.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const server = await serveDirectory(root, { "/gif-smoke.html": { type:"text/html",body:'<!doctype html><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src &apos;self&apos;; script-src &apos;self&apos;; style-src &apos;self&apos; &apos;unsafe-inline&apos;; img-src &apos;self&apos; data: blob:; connect-src &apos;self&apos;; object-src &apos;none&apos;"><title>GIF verification</title><body></body>' }, "/favicon.ico":{type:"image/png",body:Buffer.alloc(0)} });
const chrome = await launchChrome({width:800,height:600,scale:1});
try {
  const page = await chrome.newPage(); await page.goto(`${server.origin}/gif-smoke.html`);
  await page.evaluate(`(async()=>{
    window.renderWidget=(await import('/Web/preview-engine/src/render/renderer.js')).renderWidget;
    window.ActualDecoder=window.ImageDecoder;
    window.decodeIndices=[];
    if(window.ActualDecoder)window.ImageDecoder=class{constructor(options){this.decoder=new window.ActualDecoder(options)}get tracks(){return this.decoder.tracks}decode(options){window.decodeIndices.push(options.frameIndex);return this.decoder.decode(options)}close(){this.decoder.close()}};
    window.renderGif=async(options={},file='sample.gif',tag='gif')=>{
      window.decodeIndices=[];
      const tree={tag,props:tag==='gif'?{file}:{name:file},children:[]};
      const result=await window.renderWidget(JSON.stringify(tree),{resources:{['image/'+file]:'/Web/preview-engine/test/fixtures/gif/'+file},...options});
      document.body.replaceChildren(result.element);
      const image=result.element.querySelector('img');let pixel=null;
      if(image){await image.decode();const canvas=document.createElement('canvas');canvas.width=canvas.height=1;const context=canvas.getContext('2d');context.drawImage(image,0,0,1,1);pixel=[...context.getImageData(0,0,1,1).data]}
      return{src:image?.src??null,pixel,text:result.element.textContent,diagnostics:result.diagnostics,indices:window.decodeIndices};
    };
  })()`);
  const reduced = await page.evaluate("window.renderGif({reduceMotion:true})");
  assert.match(reduced.src,/^data:image\/png/); assert.ok(reduced.pixel[0]>200&&reduced.pixel[2]<40);
  if (await page.evaluate("!!window.ActualDecoder")) {
    const legacy = await page.evaluate("window.renderGif({animations:'firstFrame'})");
    assert.ok(legacy.pixel[0]>200&&legacy.pixel[2]<40,"ordinary snapshot retains the same first frame as native");
  }
  await page.evaluate("window.gifDataURL="+JSON.stringify("data:image/gif;base64,"+fs.readFileSync(path.join(root,"Web/preview-engine/test/fixtures/gif/sample.gif")).toString("base64")));
  const local = await page.evaluate("window.renderGif({reduceMotion:true,resources:{'image/sample.gif':window.gifDataURL}})");
  assert.match(local.src,/^data:image\/png/); assert.ok(local.pixel[0]>200);
  const live = await page.evaluate("window.renderGif()"); assert.match(live.src,/^data:image\/gif/);
  const mac = await page.evaluate("window.renderGif({profile:'macos'})"); assert.match(mac.src,/^data:image\/png/); assert.ok(mac.pixel[0]>200);
  const image = await page.evaluate("window.renderGif({},'sample.gif','image')"); assert.match(image.src,/^data:image\/png/); assert.ok(image.pixel[0]>200);
  const limited = await page.evaluate("window.renderGif({},'many-frames.gif')"); assert.match(limited.src,/^data:image\/png/); assert.ok(limited.pixel[0]>200);
  assert.ok(limited.diagnostics.some(item=>item.code==='gif.static_fallback')); assert.ok(limited.indices.every(index=>index===0));
  const unavailable = await page.evaluate("(async()=>{const current=window.ImageDecoder;window.ImageDecoder=class{constructor(){throw new Error('decoder unavailable')}};try{return await window.renderGif({reduceMotion:true})}finally{window.ImageDecoder=current}})()");
  assert.equal(unavailable.src,null); assert.match(unavailable.text,/GIF unavailable/); assert.ok(unavailable.diagnostics.some(item=>item.code==='gif.unavailable'));
  const fallback = await page.evaluate("(async()=>{const current=window.ImageDecoder;window.ImageDecoder=undefined;try{return await window.renderGif({reduceMotion:true})}finally{window.ImageDecoder=current}})()");
  assert.match(fallback.src,/^data:image\/png/); assert.ok(fallback.pixel[0]>200);
  await page.evaluate("window.renderGif({reduceMotion:true})");
  if(process.env.SCRIPTWIDGET_GIF_WEB)fs.writeFileSync(process.env.SCRIPTWIDGET_GIF_WEB,await page.screenshot());
  assert.deepEqual(page.consoleMessages.filter(line=>line.startsWith('exception')||line.startsWith('error')),[]);
  console.log("✓ GIF: bounded browser decoding under Studio CSP, local data URLs, first-frame Reduce Motion/Mac/image fallback, public first-frame snapshot, live playback, frame cap, decoder failure and no-ImageDecoder fallback passed");
} finally { await chrome.close(); server.close(); }
