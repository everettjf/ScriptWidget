import { runtimeContract } from "../contract.js";

/// Parent-page API for the sandboxed preview runtime. User code runs only in
/// Workers owned by an `<iframe sandbox="allow-scripts">` (opaque origin,
/// `connect-src 'none'`), never in the editor page.
///
/// Pass `sandboxURL` (a static sandbox.html with its own CSP) on sites with a
/// strict Content-Security-Policy: a `srcdoc` frame inherits the parent's
/// policy, a URL-loaded sandboxed frame does not. `sandboxDocument` (srcdoc)
/// suits pages without a CSP.
export function createPreviewSandbox({ sandboxDocument, sandboxURL, assetBaseURL, container = document.body, onLog = () => {}, startupTimeoutMilliseconds = 30000, blockedFrameMilliseconds = 4000 }) {
  const iframe = document.createElement("iframe");
  iframe.setAttribute("sandbox", "allow-scripts");
  iframe.setAttribute("aria-hidden", "true");
  iframe.setAttribute("tabindex", "-1");
  iframe.setAttribute("title", "Widget runtime sandbox");
  iframe.style.cssText = "position:absolute;width:0;height:0;border:0;visibility:hidden";
  if (sandboxURL) iframe.src = sandboxURL;
  else iframe.srcdoc = sandboxDocument;

  const pending = new Map();
  let sequence = 0;
  let resolveReady;
  let rejectReady;
  const ready = new Promise((resolve, reject) => { resolveReady = resolve; rejectReady = reject; });
  const startupTimer = setTimeout(() => rejectReady(new Error("The preview runtime did not start")), startupTimeoutMilliseconds);
  ready.then(() => clearTimeout(startupTimer), () => clearTimeout(startupTimer));

  const loadText = async (name) => {
    const response = await fetch(new URL(name, assetBaseURL));
    if (!response.ok) throw new Error(`Unable to load ${name}`);
    return response.text();
  };
  const assets = Promise.all(["core.js", "util.js", "moment.min.js"].map(loadText))
    .then(([babel, util, moment]) => ({ babel, supportScripts: { "util.js": util, "moment.min.js": moment } }));

  // The frame says hello as soon as its script runs. A frame that loads but
  // never does was replaced by an error page: a content blocker or browser
  // policy blocked the sandbox document, which no retry will fix.
  let booted = false;
  const onMessage = (event) => {
    if (event.source !== iframe.contentWindow || event.origin !== "null") return;
    const message = event.data;
    if (!message || typeof message !== "object") return;
    booted = true;
    if (message.type === "booted") return;
    if (message.type === "log") onLog(String(message.message));
    else if (message.type === "ready") resolveReady();
    else if (message.type === "failed") rejectReady(new Error(message.message));
    else if (message.type === "result" && pending.has(message.id)) {
      pending.get(message.id)(message.result);
      pending.delete(message.id);
    }
  };
  window.addEventListener("message", onMessage);

  iframe.addEventListener("load", async () => {
    setTimeout(() => {
      if (!booted) rejectReady(new Error("The browser blocked the preview sandbox. A content blocker or browser setting may be stopping it; allow this site or try another browser."));
    }, blockedFrameMilliseconds);
    try {
      const { babel } = await assets;
      iframe.contentWindow.postMessage({ type: "init", babel }, "*");
    } catch (error) { rejectReady(error); }
  }, { once: true });
  container.appendChild(iframe);

  return {
    ready,
    async execute({
      files,
      entry = "main.jsx",
      manifest = null,
      environments = { "widget-size": "medium", "widget-param": "" },
      preview = { appearance: "light" },
      fixtures = {},
      prelude = "",
      timeoutMilliseconds = runtimeContract.executionTimeoutMilliseconds,
    }) {
      await ready;
      const { supportScripts } = await assets;
      const id = `run-${++sequence}`;
      const config = JSON.stringify({
        contract: runtimeContract, environments, preview, fixtures,
        manifest: manifest ?? null, hasManifest: manifest !== null && manifest !== undefined,
      });
      return new Promise((resolve) => {
        pending.set(id, resolve);
        // Messages to an opaque-origin frame cannot name a target origin.
        iframe.contentWindow.postMessage({
          type: "execute", id,
          job: { files, entry, prelude, config, supportScripts, timeoutMilliseconds },
        }, "*");
      });
    },
    destroy() {
      window.removeEventListener("message", onMessage);
      iframe.remove();
      for (const resolve of pending.values()) resolve({ tree: null, error: { kind: "internalError", message: "Preview sandbox closed" }, logs: [], diagnostics: [] });
      pending.clear();
    },
  };
}
