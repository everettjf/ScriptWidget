import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";
import { executorBootstrap } from "../src/browser/executorBootstrap.js";
import { scriptWidgetKernel } from "../src/kernel.js";
import { runtimeContract } from "../src/contract.js";
import { preparePackage } from "../src/prepare.js";
import { nodeCompiler, supportBundleDirectory } from "../src/node.js";

/// Runs one job through the browser Worker bootstrap in a vm context that
/// stands in for a DedicatedWorkerGlobalScope.
function runInWorkerScope(source, fixtures) {
  const prepared = preparePackage(nodeCompiler(), { files: { "main.jsx": source }, entry: "main.jsx", prelude: "" });
  assert.ok(prepared.ok);
  const supportScripts = Object.fromEntries(["util.js", "moment.min.js"].map((name) => [name, fs.readFileSync(path.join(supportBundleDirectory, name), "utf8")]));
  return new Promise((resolve) => {
    const blobs = new Map();
    const context = vm.createContext({
      postMessage: (message) => resolve(JSON.parse(message)),
      setTimeout,
      // Worker stand-ins: blob URLs evaluate synchronously in the scope.
      Blob: class { constructor(parts) { this.text = parts.join(""); } },
      URL: { createObjectURL: (blob) => { const url = `blob:${blobs.size}`; blobs.set(url, blob.text); return url; }, revokeObjectURL: (url) => blobs.delete(url) },
      MessageChannel: class { constructor() { const port1 = {}; this.port1 = port1; this.port2 = { postMessage: () => setImmediate(() => port1.onmessage?.()) }; } },
      fetch: () => { throw new Error("the worker's own fetch must not be reachable"); },
    });
    context.self = context;
    // Firefox throws from some worker getters in an opaque origin.
    vm.runInContext(`Object.defineProperty(globalThis, "caches", { get() { throw new Error("NS_ERROR_FAILURE"); }, configurable: true });`, context);
    context.importScripts = (url) => vm.runInContext(blobs.get(url), context);
    vm.runInContext(`(${executorBootstrap.toString()})(${scriptWidgetKernel.toString()})`, context);
    const config = JSON.stringify({ contract: runtimeContract, environments: { "widget-size": "small", "widget-param": "" }, preview: { appearance: "light" }, fixtures, manifest: null, hasManifest: false });
    context.onmessage({ data: { config, code: prepared.code, imports: prepared.imports, files: prepared.files, supportScripts, timeoutMilliseconds: 1000 } });
  });
}

test("the browser worker keeps the runtime's fetch after hiding the worker's globals", async () => {
  // Regression: scrub() replaced the kernel's fetch with undefined, so
  // `await fetch(url)` threw "fetch is not a function" in the browser.
  const fixtures = { fetch: [{ url: "https://api.example.com/rates", body: "{\"CNY\":6.7}" }] };
  const result = await runInWorkerScope('const body = await fetch("https://api.example.com/rates"); $render(<text>{typeof XMLHttpRequest}:{JSON.parse(body).CNY}</text>);', fixtures);
  assert.equal(result.error, null);
  assert.equal(result.tree, '{"$element":"text","props":null,"children":["undefined",":",6.7]}');
});
