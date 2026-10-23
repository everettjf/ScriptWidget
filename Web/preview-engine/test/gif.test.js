import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { gifLimits, inspectGif, readGifBytes } from "../src/render/gif.js";

function fixture({ width = 1, height = 1, count = 2 } = {}) {
  const bytes = [...Buffer.from("GIF89a"), width & 255, width >> 8, height & 255, height >> 8, 128, 0, 0, 255, 0, 0, 0, 0, 255];
  for (let i = 0; i < count; i++) bytes.push(33, 249, 4, 0, i + 1, 0, 0, 0, 44, 0, 0, 0, 0, width & 255, width >> 8, height & 255, height >> 8, 0, 2, 2, 68, 1, 0);
  bytes.push(59); return new Uint8Array(bytes);
}
test("GIF preflight accepts actual bundled GIFs and bounded variable delays", () => {
  const root = new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/", import.meta.url);
  for (const path of ["component/gif/image/test.gif", "template/Nyan Cat/image/cat.gif"]) {
    const value = inspectGif(new Uint8Array(fs.readFileSync(new URL(path, root))));
    assert.ok(value.count > 0); assert.ok(value.width * value.height <= gifLimits.canvasPixels);
  }
  const value = inspectGif(fixture()); assert.deepEqual(value.delays, [0.1, 0.02]); assert.equal(value.frameLimit, false);
});
test("GIF frame limits select static fallback without retaining unbounded delay arrays", () => {
  const value = inspectGif(fixture({ count: 80 })); assert.equal(value.frameLimit, true); assert.equal(value.count, 80); assert.equal(value.delays.length, 60);
});
test("GIF byte, canvas and malformed-block limits fail before image decode", () => {
  assert.throws(() => inspectGif(new Uint8Array(gifLimits.inputBytes + 1)), /limit/);
  assert.throws(() => inspectGif(fixture({ width: 65535, height: 65535 })), /canvas/);
  const valid = fixture();
  for (let index = 0; index < valid.length; index++) assert.throws(() => inspectGif(valid.slice(0, index)), /GIF/);
  const invalid = valid.slice(); invalid[0] = 0; assert.throws(() => inspectGif(invalid), /signature/);
});
test("GIF response headers and actual stream bytes are independently bounded", async () => {
  await assert.rejects(readGifBytes("sample", async () => new Response("x", { headers: { "content-length": String(gifLimits.inputBytes + 1) } })), /limit/);
  let cancelled = false;
  const stream = new ReadableStream({ start(controller) { controller.enqueue(new Uint8Array(gifLimits.inputBytes)); controller.enqueue(new Uint8Array(1)); }, cancel() { cancelled = true; } });
  await assert.rejects(readGifBytes("sample", async () => new Response(stream)), /limit/); assert.equal(cancelled, true);
  const bytes = fixture(); assert.deepEqual(await readGifBytes("sample", async () => new Response(bytes)), bytes);
  await assert.rejects(readGifBytes("sample", async () => new Response(null)), /limit/);
});
test("GIF data URLs decode locally within limits without widening Studio CSP", async () => {
  const bytes = fixture(), url = "data:image/gif;base64," + Buffer.from(bytes).toString("base64");
  const noFetch = () => { throw new Error("Data URLs must never perform a request"); };
  assert.deepEqual(await readGifBytes(url, noFetch), bytes);
  for (const suffix of ["%00", "!!!!", "A==="]) await assert.rejects(readGifBytes("data:image/gif;base64," + suffix, noFetch), /GIF/);
  await assert.rejects(readGifBytes("data:image/png;base64,AAAA", noFetch), /GIF/);
  await assert.rejects(readGifBytes("data:image/gif;base64," + "A".repeat(Math.ceil(gifLimits.inputBytes / 3) * 4 + 4), noFetch), /limit/);
});
