// Source of the long-lived compiler Worker inside the sandboxed preview frame.
// It holds the Babel bundle; user code never executes here. `prepare` is the
// build-time bundle of contract.js, compiler.js, packageFiles.js, prepare.js.
export function compilerBootstrap(prepare) {
  "use strict";
  const scope = self;
  let compiler = null;
  scope.onmessage = (event) => {
    const message = event.data;
    if (!message || typeof message !== "object") return;
    if (message.type === "init" && compiler === null && typeof message.babel === "string") {
      const url = URL.createObjectURL(new Blob([message.babel], { type: "text/javascript" }));
      try { scope.importScripts(url); } finally { URL.revokeObjectURL(url); }
      const Babel = scope.Babel;
      delete scope.Babel;
      compiler = prepare.createCompiler((source) => Babel.transform(source, { presets: ["scriptwidget"] }).code);
      scope.postMessage({ type: "ready" });
      return;
    }
    if (message.type === "prepare" && compiler !== null) {
      let prepared;
      try {
        prepared = prepare.preparePackage(compiler, { files: message.files, entry: message.entry, prelude: message.prelude ?? "", manifest: message.manifest ?? null });
      } catch (error) {
        prepared = { ok: false, error: { kind: "internalError", message: String(error) } };
      }
      scope.postMessage({ type: "prepared", id: message.id, prepared });
    }
  };
}
