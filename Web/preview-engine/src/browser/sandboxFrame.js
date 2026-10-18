// Inline script of the sandboxed preview frame (opaque origin, no network).
// It accepts messages only from its parent, owns the compiler Worker, starts
// one executor Worker per run, and enforces the execution deadline.
export function sandboxFrame(compilerWorkerSource, executorWorkerSource) {
  "use strict";
  const maximumResultBytes = 4 * 1024 * 1024;
  let parentOrigin = null;
  let compiler = null;
  let compilerReady = null;
  const pending = new Map();
  const executorURL = URL.createObjectURL(new Blob([executorWorkerSource], { type: "text/javascript" }));

  const reply = (message) => window.parent.postMessage(message, parentOrigin);
  const errorResult = (kind, message) => JSON.stringify({ tree: null, error: { kind, message }, logs: [], diagnostics: [] });

  function startCompiler(babel) {
    const url = URL.createObjectURL(new Blob([compilerWorkerSource], { type: "text/javascript" }));
    compiler = new Worker(url);
    URL.revokeObjectURL(url);
    compilerReady = new Promise((resolve, reject) => {
      compiler.onmessage = (event) => {
        const message = event.data;
        if (message?.type === "ready") { resolve(); return; }
        if (message?.type === "prepared" && pending.has(message.id)) {
          pending.get(message.id)(message.prepared);
          pending.delete(message.id);
        }
      };
      compiler.onerror = (event) => reject(new Error(event.message || "Compiler failed to start"));
    });
    compiler.postMessage({ type: "init", babel });
  }

  function prepare(id, job) {
    return new Promise((resolve) => {
      pending.set(id, resolve);
      compiler.postMessage({ type: "prepare", id, files: job.files, entry: job.entry, prelude: job.prelude });
    });
  }

  function execute(job, prepared) {
    return new Promise((resolve) => {
      const worker = new Worker(executorURL);
      let settled = false;
      const settle = (value) => {
        if (settled) return;
        settled = true;
        clearTimeout(deadline);
        worker.terminate();
        resolve(value);
      };
      const deadline = setTimeout(() => settle(errorResult("resourceLimit", "Script exceeded the 5-second execution limit")), job.timeoutMilliseconds + 50);
      worker.onmessage = (event) => settle(typeof event.data === "string" && event.data.length <= maximumResultBytes
        ? event.data : errorResult("internalError", "Invalid execution result"));
      worker.onerror = (event) => { event.preventDefault(); settle(errorResult("internalError", event.message || "Execution worker failed")); };
      worker.postMessage({
        config: job.config,
        code: prepared.code,
        imports: prepared.imports,
        files: prepared.files,
        supportScripts: job.supportScripts,
        timeoutMilliseconds: job.timeoutMilliseconds,
      });
    });
  }

  function validResult(text) {
    try {
      const value = JSON.parse(text);
      const ok = value && typeof value === "object" && (value.tree === null || typeof value.tree === "string") &&
        (value.error === null || (typeof value.error === "object" && typeof value.error.kind === "string")) &&
        Array.isArray(value.logs) && Array.isArray(value.diagnostics);
      return ok ? value : null;
    } catch { return null; }
  }

  window.addEventListener("message", async (event) => {
    if (event.source !== window.parent) return;
    const message = event.data;
    if (!message || typeof message !== "object" || typeof message.type !== "string") return;
    if (message.type === "init" && parentOrigin === null && typeof message.babel === "string") {
      parentOrigin = event.origin === "null" ? "*" : event.origin;
      startCompiler(message.babel);
      try { await compilerReady; reply({ type: "ready" }); } catch (error) { reply({ type: "failed", message: String(error) }); }
      return;
    }
    if (message.type !== "execute" || parentOrigin === null || typeof message.id !== "string") return;
    const job = message.job;
    if (!job || typeof job !== "object" || typeof job.config !== "string" || !job.files || typeof job.files !== "object") return;
    await compilerReady;
    const started = performance.now();
    const prepared = await prepare(message.id, job);
    const compiledAt = performance.now();
    const resultText = prepared.ok ? await execute(job, prepared) : JSON.stringify({ tree: null, error: prepared.error, logs: [], diagnostics: [] });
    const result = validResult(resultText) ?? validResult(errorResult("internalError", "Invalid execution result"));
    result.timing = { compileMilliseconds: compiledAt - started, executeMilliseconds: performance.now() - compiledAt };
    reply({ type: "result", id: message.id, result });
  });
}
