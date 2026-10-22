// Source of the per-execution Worker, created from a blob URL inside the
// sandboxed preview frame. Self-contained: the build stringifies it together
// with scriptWidgetKernel. The frame terminates the Worker at the deadline.
export function executorBootstrap(kernel) {
  "use strict";
  const scope = self;
  const post = scope.postMessage.bind(scope);
  const importScriptsNative = scope.importScripts.bind(scope);
  const setTimeoutNative = scope.setTimeout.bind(scope);
  const BlobNative = Blob;
  const createObjectURL = URL.createObjectURL.bind(URL);
  const revokeObjectURL = URL.revokeObjectURL.bind(URL);
  const MessageChannelNative = MessageChannel;
  const deferChannel = new MessageChannelNative();
  const deferred = [];
  deferChannel.port1.onmessage = () => { const callback = deferred.shift(); if (callback) callback(); };

  // Globals that JavaScriptCore does not provide, or that would let user code
  // reach the network, storage, timers, or the frame's message channel.
  const hidden = [
    "postMessage", "importScripts", "fetch", "XMLHttpRequest", "WebSocket", "WebSocketStream", "WebTransport",
    "EventSource", "indexedDB", "caches", "cookieStore", "setTimeout", "setInterval", "clearTimeout",
    "clearInterval", "setImmediate", "queueMicrotask", "requestAnimationFrame", "cancelAnimationFrame",
    "structuredClone", "TextEncoder", "TextDecoder", "TextEncoderStream", "TextDecoderStream", "URL",
    "URLSearchParams", "URLPattern", "Blob", "File", "FileReader", "FileReaderSync", "FormData", "Headers", "Request", "Response",
    "MessageChannel", "MessagePort", "MessageEvent", "BroadcastChannel", "Worker", "SharedWorker",
    "navigator", "location", "crypto", "performance", "atob", "btoa", "close", "onmessage",
    "onmessageerror", "onerror", "onunhandledrejection", "onrejectionhandled", "self", "Notification",
    "OffscreenCanvas", "createImageBitmap", "ImageData", "reportError", "scheduler", "trustedTypes",
    "name", "origin", "isSecureContext", "crossOriginIsolated", "fonts", "addEventListener",
    "removeEventListener", "dispatchEvent", "Event", "EventTarget", "CustomEvent", "ReadableStream",
    "WritableStream", "TransformStream", "CompressionStream", "DecompressionStream", "StorageManager",
    "Lock", "LockManager", "FileSystemHandle", "FileSystemDirectoryHandle", "FileSystemFileHandle",
    "GPU", "WorkerGlobalScope", "DedicatedWorkerGlobalScope", "WorkerNavigator", "WorkerLocation",
  ];

  // The worker's own values, read before the kernel installs its APIs:
  // scrub() removes these and keeps the kernel's replacements (fetch).
  // Some getters throw instead of returning (Firefox: storage APIs such as
  // caches in an opaque-origin worker throw NS_ERROR_FAILURE).
  const unreadable = {};
  const read = (name) => { try { return scope[name]; } catch { return unreadable; } };
  const workerValues = new Map(hidden.map((name) => [name, read(name)]));

  function scrub() {
    for (const name of hidden) {
      if (read(name) !== workerValues.get(name)) continue;
      try {
        Object.defineProperty(scope, name, { value: undefined, writable: false, configurable: false, enumerable: false });
      } catch {
        try { scope[name] = undefined; } catch { /* non-configurable and read-only */ }
      }
    }
  }

  function evaluateScript(code) {
    const url = createObjectURL(new BlobNative([code], { type: "text/javascript" }));
    try { importScriptsNative(url); } finally { revokeObjectURL(url); }
  }

  scope.onmessage = (event) => {
    scope.onmessage = null;
    const job = event.data;
    if (!job || typeof job !== "object" || typeof job.code !== "string" || typeof job.config !== "string") {
      post(JSON.stringify({ tree: null, error: { kind: "internalError", message: "Invalid execution job" }, logs: [], diagnostics: [] }));
      return;
    }
    const files = job.files ?? {};
    const imports = job.imports ?? {};
    const supportScripts = job.supportScripts ?? {};
    const normalize = (value) => {
      if (typeof value !== "string" || value === "" || value.startsWith("/") || value.includes("\\") || value.includes("\0")) return null;
      const parts = [];
      for (const part of value.split("/")) {
        if (part === "" || part === ".") continue;
        if (part === "..") { if (parts.length === 0) return null; parts.pop(); continue; }
        parts.push(part);
      }
      return parts.length === 0 ? null : parts.join("/");
    };
    const has = (map, key) => Object.prototype.hasOwnProperty.call(map, key);
    let finished = false;
    const host = {
      evaluateScript,
      compiledImport(relativePath) {
        const path = normalize(relativePath);
        if (path === null || !has(files, path) || typeof files[path] !== "string") return null;
        return has(imports, path) ? imports[path] : JSON.stringify({ ok: false, kind: "transformError", message: "Not a script file" });
      },
      readFile(relativePath) {
        const path = normalize(relativePath);
        return path !== null && has(files, path) ? files[path] : null;
      },
      fileExists(relativePath) {
        const path = normalize(relativePath);
        return path !== null && has(files,path);
      },
      supportScript(name) { return has(supportScripts, name) ? supportScripts[name] : null; },
      parseXML() { return JSON.stringify({ ok: false, error: "$xml.parse is not available in the web preview yet" }); },
      log() {},
      defer(callback) { deferred.push(callback); deferChannel.port2.postMessage(0); },
      timeout(milliseconds, callback) { setTimeoutNative(callback, milliseconds); },
      finish(resultJSON) {
        if (finished) return;
        finished = true;
        post(resultJSON);
      },
    };
    const runtime = kernel(scope, host, job.config);
    scrub();
    runtime.run(job.code, job.timeoutMilliseconds);
  };
}
