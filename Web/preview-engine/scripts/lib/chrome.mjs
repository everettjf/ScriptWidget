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

/// Chrome starts helper processes; kill the whole process group so none of
/// them keeps pipes (and this Node process) alive.
function killTree(chrome, signal = "SIGKILL") {
  if (process.platform !== "win32" && chrome.pid) {
    try { process.kill(-chrome.pid, signal); return; } catch { /* group already gone */ }
  }
  chrome.kill(signal);
}

export function startChrome(chromePath, args, timeoutMilliseconds) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "sw-chrome-"));
  const chrome = spawn(chromePath, [...args, `--user-data-dir=${profile}`, "about:blank"], { stdio: ["ignore", "ignore", "pipe"], detached: process.platform !== "win32" });
  return new Promise((resolve, reject) => {
    let buffer = "";
    let settled = false;
    let timer;
    let endpointPoll;
    const ready = (wsURL) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearInterval(endpointPoll);
      resolve({ chrome, profile, wsURL });
    };
    const fail = (message) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearInterval(endpointPoll);
      killTree(chrome);
      chrome.stderr.destroy();
      fs.rmSync(profile, { recursive: true, force: true });
      reject(new Error(`${message}\n${buffer.trim().split("\n").slice(-5).join("\n")}`));
    };
    // Never wait forever: a Chrome that cannot start its sandbox may neither
    // exit nor print the DevTools endpoint.
    timer = setTimeout(() => fail(`Chrome did not start within ${timeoutMilliseconds} ms`), timeoutMilliseconds);
    // GUI Chrome builds can omit stderr even though DevTools is ready. With
    // port=0 Chrome also publishes the endpoint inside this unique profile.
    // Do not extend the deadline or start another browser on an observation timeout.
    endpointPoll = setInterval(() => {
      try {
        const text = fs.readFileSync(path.join(profile, "DevToolsActivePort"), "utf8");
        if (text.length > 1024) return;
        const [port, endpoint] = text.trim().split(/\r?\n/);
        if (/^[1-9]\d{0,4}$/.test(port) && Number(port) <= 65535 && /^\/devtools\/browser\/[A-Za-z0-9_-]+$/.test(endpoint)) {
          ready(`ws://127.0.0.1:${port}${endpoint}`);
        }
      } catch { /* The browser has not published a complete endpoint yet. */ }
    }, 50);
    chrome.stderr.on("data", (chunk) => {
      buffer = (buffer + chunk).slice(-8000);
      const match = /DevTools listening on (ws:\S+)/.exec(buffer);
      if (match) ready(match[1]);
    });
    chrome.on("exit", (code) => fail(`Chrome exited (${code}) before DevTools was ready`));
    chrome.on("error", (error) => fail(`Chrome could not be launched: ${error.message}`));
  });
}

export async function launchChrome({ width = 800, height = 800, scale = 2, startupTimeoutMilliseconds = 30000, callTimeoutMilliseconds = 120000 } = {}) {
  const chromePath = findChrome();
  if (!chromePath) throw new Error("Chrome was not found. Set CHROME_PATH.");
  const args = ["--headless=new", "--remote-debugging-port=0", `--force-device-scale-factor=${scale}`, `--window-size=${width},${height}`,
    "--hide-scrollbars", "--font-render-hinting=none", "--no-first-run", "--no-default-browser-check", "--disable-dev-shm-usage"];
  // Chrome's OS sandbox needs unprivileged user namespaces, which recent
  // Ubuntu releases (including GitHub's runners) restrict with AppArmor.
  // Widget code is isolated by the sandboxed frame and its CSP, not by this
  // OS sandbox, so on Linux the launch falls back to --no-sandbox.
  let started;
  if (process.env.SCRIPTWIDGET_CHROME_NO_SANDBOX === "1") started = await startChrome(chromePath, [...args, "--no-sandbox"], startupTimeoutMilliseconds);
  else {
    try { started = await startChrome(chromePath, args, startupTimeoutMilliseconds); }
    catch (error) {
      if (process.platform !== "linux") throw error;
      console.error(`Chrome failed to start with its sandbox; retrying with --no-sandbox. ${error.message.split("\n")[0]}`);
      started = await startChrome(chromePath, [...args, "--no-sandbox"], startupTimeoutMilliseconds);
    }
  }
  const { chrome, profile, wsURL } = started;
  const socket = new WebSocket(wsURL);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { killTree(chrome); reject(new Error("Could not connect to Chrome DevTools")); }, startupTimeoutMilliseconds);
    socket.addEventListener("open", () => { clearTimeout(timer); resolve(); }, { once: true });
    socket.addEventListener("error", () => { clearTimeout(timer); killTree(chrome); reject(new Error("Could not connect to Chrome DevTools")); }, { once: true });
  });
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
    const timer = setTimeout(() => { waiting.delete(id); reject(new Error(`${method} timed out after ${callTimeoutMilliseconds} ms`)); }, callTimeoutMilliseconds);
    waiting.set(id, (message) => { clearTimeout(timer); if (message.error) reject(new Error(`${method}: ${message.error.message}`)); else resolve(message.result); });
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
        /// Calls `handler(params)` for each CDP event `method` of this page.
        onEvent(method, handler) {
          listeners.add((message) => { if (message.sessionId === sessionId && message.method === method) handler(message.params); });
        },
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
      await new Promise((resolve) => {
        if (chrome.exitCode !== null) { resolve(); return; }
        chrome.once("exit", resolve);
        killTree(chrome, "SIGTERM");
        setTimeout(() => killTree(chrome), 3000).unref();
      });
      fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    },
  };
}

// A rendered preview can be ready while the Gallery dialog is still animating
// closed. Hit-test the actual pointer target instead of clicking through it.
export async function clickReady(page, expression) {
  await page.evaluate(`(${expression}).scrollIntoView({block:'center',inline:'center',behavior:'instant'})`);
  const hitTest = `(async () => {const target=(${expression});if(!target)return false;target.scrollIntoView({block:'center',inline:'center',behavior:'instant'});const before=target.getBoundingClientRect();await new Promise(requestAnimationFrame);const r=target.getBoundingClientRect();const stable=['x','y','width','height'].every(key=>Math.abs(before[key]-r[key])<0.5);const hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return stable&&r.width>0&&r.height>0&&!target.disabled&&!!hit&&target.contains(hit);})()`;
  if (!(await page.evaluate(hitTest))) {
    console.log("pointer target waiting:", await page.evaluate(`(() => {const target=(${expression}),r=target.getBoundingClientRect(),hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return JSON.stringify({target:target.textContent,hit:hit?.tagName,slot:hit?.getAttribute('data-slot'),state:hit?.getAttribute('data-state')});})()`));
  }
  await page.waitFor(hitTest);
  const point = await page.evaluate(`(() => {const r=(${expression}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
  await page.call("Input.dispatchMouseEvent",{type:"mousePressed",...point,button:"left",clickCount:1});
  await page.call("Input.dispatchMouseEvent",{type:"mouseReleased",...point,button:"left",clickCount:1});
}
