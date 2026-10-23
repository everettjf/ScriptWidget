// One execution per worker thread. The parent terminates the thread at the
// deadline, which stops synchronous loops and microtask storms alike. User
// code runs in a fresh vm context so Node globals stay out of reach; this is
// isolation for correctness, not a security boundary.
import vm from "node:vm";
import { parentPort, workerData } from "node:worker_threads";
import { normalizePackagePath } from "./packageFiles.js";

const { kernelSource, config, code, imports, files, supportScripts, timeoutMilliseconds } = workerData;
const context = vm.createContext({});

const host = {
  evaluateScript(source) { new vm.Script(source, { filename: "script.js" }).runInContext(context); },
  compiledImport(relativePath) {
    const path = normalizePackagePath(relativePath);
    if (path === null || !Object.prototype.hasOwnProperty.call(files,path) || typeof files[path] !== "string") return null;
    return imports[path] ?? JSON.stringify({ ok: false, kind: "transformError", message: "Not a script file" });
  },
  readFile(relativePath) {
    const path = normalizePackagePath(relativePath);
    return path === null || !Object.prototype.hasOwnProperty.call(files,path) ? null : files[path] ?? null;
  },
  fileExists(relativePath) {
    const path=normalizePackagePath(relativePath);
    return path !== null && Object.prototype.hasOwnProperty.call(files,path);
  },
  supportScript(name) { return supportScripts[name] ?? null; },
  parseXML() { return JSON.stringify({ ok: false, error: "$xml.parse is not available in the web preview yet" }); },
  log() {},
  defer(callback) { setImmediate(callback); },
  timeout(milliseconds, callback) { setTimeout(callback, milliseconds); },
  finish(resultJSON) { parentPort.postMessage(resultJSON); },
};

context.__swHost = host;
context.__swConfig = config;
context.__swCode = code;
context.__swTimeout = timeoutMilliseconds;
vm.runInContext(`(function () {
  const host = globalThis.__swHost, config = globalThis.__swConfig, code = globalThis.__swCode, timeout = globalThis.__swTimeout;
  delete globalThis.__swHost; delete globalThis.__swConfig; delete globalThis.__swCode; delete globalThis.__swTimeout;
  (${kernelSource})(globalThis, host, config).run(code, timeout);
})()`, context, { filename: "kernel.js" });
