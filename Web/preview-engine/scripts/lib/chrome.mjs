// Minimal headless Chrome driver over the DevTools protocol (Node 24
// WebSocket). Shared by snapshot comparison, the Studio smoke test, and the
// preview CLI.
import { spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";

export function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium", "/usr/bin/chromium-browser",
    "C:\\\\Program Files\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe",
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate)) ?? null;
}

const types = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".css": "text/css", ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml" };

/// Serves `directory` on 127.0.0.1 with an optional `routes` override map.
export async function serveDirectory(directory, routes = {}) {
  const root = path.resolve(directory);
  const server = http.createServer((request, response) => {
    const pathname = decodeURIComponent(new URL(request.url, "http://x").pathname);
    if (routes[pathname]) { response.writeHead(200, { "content-type": routes[pathname].type }); response.end(routes[pathname].body); return; }
    let target = path.join(root, pathname);
    if (target.endsWith(path.sep)) target = path.join(target, "index.html");
    if (!target.startsWith(root) || !fs.existsSync(target) || fs.statSync(target).isDirectory()) { response.writeHead(404).end(); return; }
    response.writeHead(200, { "content-type": types[path.extname(target)] ?? "application/octet-stream" });
    fs.createReadStream(target).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return { origin: `http://127.0.0.1:${server.address().port}`, close: () => server.close() };
}

export async function launchChrome({ width = 800, height = 800, scale = 2 } = {}) {
  const chromePath = findChrome();
  if (!chromePath) throw new Error("Chrome was not found. Set CHROME_PATH.");
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "sw-chrome-"));
  const chrome = spawn(chromePath, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`, `--force-device-scale-factor=${scale}`,
    `--window-size=${width},${height}`, "--hide-scrollbars", "--font-render-hinting=none", "--no-first-run", "--no-default-browser-check", "about:blank"], { stdio: ["ignore", "ignore", "pipe"] });
  const wsURL = await new Promise((resolve, reject) => {
    let buffer = "";
    chrome.stderr.on("data", (chunk) => { buffer += chunk; const match = /DevTools listening on (ws:\S+)/.exec(buffer); if (match) resolve(match[1]); });
    chrome.on("exit", () => reject(new Error("Chrome exited before DevTools was ready")));
  });
  const socket = new WebSocket(wsURL);
  await new Promise((resolve) => socket.addEventListener("open", resolve, { once: true }));
  let sequence = 0;
  const waiting = new Map();
  const listeners = new Set();
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && waiting.has(message.id)) { waiting.get(message.id)(message); waiting.delete(message.id); }
    else for (const listener of listeners) listener(message);
  });
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++sequence;
    waiting.set(id, (message) => (message.error ? reject(new Error(`${method}: ${message.error.message}`)) : resolve(message.result)));
    socket.send(JSON.stringify({ id, method, params, sessionId }));
  });
  return {
    async newPage() {
      const { targetId } = await send("Target.createTarget", { url: "about:blank" });
      const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
      const call = (method, params) => send(method, params, sessionId);
      await call("Page.enable");
      await call("Runtime.enable");
      await call("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: scale, mobile: false });
      const consoleMessages = [];
      listeners.add((message) => {
        if (message.sessionId !== sessionId) return;
        if (message.method === "Runtime.consoleAPICalled") consoleMessages.push(`${message.params.type}: ${message.params.args.map((arg) => arg.value ?? arg.description).join(" ")}`);
        if (message.method === "Runtime.exceptionThrown") consoleMessages.push(`exception: ${message.params.exceptionDetails?.exception?.description ?? message.params.exceptionDetails?.text}`);
      });
      const evaluate = async (expression) => {
        const result = await call("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
        if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
        return result.result.value;
      };
      return {
        call, evaluate, consoleMessages,
        async goto(url) { await call("Page.navigate", { url }); },
        async waitFor(expression, timeout = 15000) {
          const deadline = Date.now() + timeout;
          while (Date.now() < deadline) {
            if (await evaluate(expression).catch(() => false)) return true;
            await new Promise((resolve) => setTimeout(resolve, 100));
          }
          throw new Error(`Timed out waiting for ${expression}`);
        },
        async screenshot(clip) { return Buffer.from((await call("Page.captureScreenshot", { format: "png", ...(clip ? { clip: { ...clip, scale: 1 } } : {}) })).data, "base64"); },
      };
    },
    async close() {
      socket.close();
      await new Promise((resolve) => { chrome.once("exit", resolve); chrome.kill(); });
      fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    },
  };
}
