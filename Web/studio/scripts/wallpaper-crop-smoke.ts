import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { stripTypeScriptTypes } from "node:module";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "../../preview-engine/scripts/lib/chrome.mjs";

// Exercise the actual browser codec/canvas path without a mock Canvas API.
const directory = fs.mkdtempSync(path.join(os.tmpdir(), "scriptwidget-wallpaper-"));
const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../src/wallpaperCrop.ts");
fs.writeFileSync(path.join(directory, "crop.mjs"), stripTypeScriptTypes(fs.readFileSync(source, "utf8")));
fs.writeFileSync(path.join(directory, "index.html"), '<!doctype html><title>Wallpaper crop verification</title>');
const server = await serveDirectory(directory);
const chrome = await launchChrome({ width: 800, height: 600, scale: 1 });
try {
  const page = await chrome.newPage();
  await page.goto(`${server.origin}/index.html`);
  const result = await page.evaluate<{ selectedPixel: number[]; working: number[]; output: number[]; oriented: number[]; chunks: string[]; rejects: number }>(`(async () => {
    const api = await import('./crop.mjs');
    const canvas = document.createElement('canvas'); canvas.width=4000; canvas.height=40;
    const context=canvas.getContext('2d');context.fillStyle='#ff0000';context.fillRect(0,0,2000,40);context.fillStyle='#00ff00';context.fillRect(2000,0,2000,40);
    const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));
    const image=await api.prepareWallpaper(blob);
    const exported=await api.exportWallpaperCrop(image,{x:1600,y:0,width:1400,height:30});
    const output=await createImageBitmap(exported), sample=document.createElement('canvas');sample.width=output.width;sample.height=output.height;
    const sampleContext=sample.getContext('2d');sampleContext.drawImage(output,0,0);
    const selectedPixel=Array.from(sampleContext.getImageData(100,10,1,1).data);
    const bytes=new Uint8Array(await exported.arrayBuffer()),view=new DataView(bytes.buffer),chunks=[];
    for(let offset=8;offset<bytes.length;){const length=view.getUint32(offset);chunks.push(String.fromCharCode(...bytes.slice(offset+4,offset+8)));offset+=12+length;}
    // Inject a standard EXIF orientation=6 into a real browser-encoded JPEG.
    canvas.width=8;canvas.height=4;
    const jpeg=new Uint8Array(await (await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg'))).arrayBuffer());
    const exif=Uint8Array.from([255,225,0,34,69,120,105,102,0,0,73,73,42,0,8,0,0,0,1,0,18,1,3,0,1,0,0,0,6,0,0,0,0,0,0,0]);
    const orientedBytes=new Uint8Array(jpeg.length+exif.length);orientedBytes.set(jpeg.slice(0,2));orientedBytes.set(exif,2);orientedBytes.set(jpeg.slice(2),2+exif.length);
    const oriented=await api.prepareWallpaper(new Blob([orientedBytes],{type:'application/octet-stream'}));
    let rejects=0;
    for(const invalid of [new Blob(),new Blob(['not an image']),new Blob([bytes.slice(0,24)])]){try{await api.prepareWallpaper(invalid);}catch{rejects++;}}
    try{await api.exportWallpaperCrop(image,{x:3000,y:0,width:100,height:30});}catch{rejects++;}
    const result={selectedPixel,working:[image.width,image.height],output:[output.width,output.height],oriented:[oriented.width,oriented.height],chunks,rejects};output.close();return result;
  })()`);
  assert.deepEqual(result.selectedPixel, [0, 255, 0, 255]);
  assert.deepEqual(result.working, [3072, 31]);
  assert.deepEqual(result.output, [1024, 22]);
  assert.deepEqual(result.oriented, [4, 8]);
  assert.equal(result.rejects, 4);
  for (const metadata of ["eXIf", "tEXt", "zTXt", "iTXt"]) assert.ok(!result.chunks.includes(metadata));
  assert.deepEqual(page.consoleMessages.filter((line: string) => line.startsWith("exception") || line.startsWith("error")), []);
  console.log("✓ Wallpaper codec: dimension preflight, EXIF orientation, 3072px normalization, pixel crop, 1024px PNG, metadata removal and invalid input passed");
} finally {
  await chrome.close(); server.close(); fs.rmSync(directory, { recursive: true, force: true });
}
