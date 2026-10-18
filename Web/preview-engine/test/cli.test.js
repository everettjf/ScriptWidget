import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { DeviceSession } from "../src/cli/deviceSync.js";
import { findChrome } from "../scripts/lib/chrome.mjs";
import { newProjectFiles } from "../src/package/index.js";

const engine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const hasChrome = Boolean(findChrome());

function temporaryPackage(source) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "sw-cli-"));
  for (const [name, content] of Object.entries(newProjectFiles("CLI Test", source))) fs.writeFileSync(path.join(directory, name), content);
  return directory;
}

function run(args) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [path.join(engine, "bin/scriptwidget-preview.mjs"), ...args]);
    let stdout = ""; let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("exit", (code) => resolve({ code, stdout, stderr }));
  });
}

test("the CLI renders a PNG with source-hash diagnostics", { skip: !hasChrome && "Chrome not found" }, async () => {
  const directory = temporaryPackage("$render(<vstack><text font=\"title\">CLI</text></vstack>);\n");
  const first = await run([directory, "--family", "small"]);
  assert.equal(first.code, 0, first.stderr);
  const result = JSON.parse(first.stdout);
  assert.equal(result.status, "ok");
  assert.deepEqual(result.size, { width: 158, height: 158 });
  assert.match(result.sourceHash, /^[0-9a-f]{64}$/);
  assert.equal(result.compilerFingerprint, "scriptwidget-babel-v2");
  assert.ok(fs.statSync(path.join(directory, "preview.png")).size > 1000);

  fs.writeFileSync(path.join(directory, "main.jsx"), "throw new Error('broken');\n");
  const second = await run([directory, "--family", "small"]);
  assert.equal(second.code, 1);
  const failed = JSON.parse(second.stdout);
  assert.equal(failed.error.kind, "scriptException");
  assert.notEqual(failed.sourceHash, result.sourceHash);
  assert.equal(fs.existsSync(path.join(directory, "preview.png")), false, "a stale preview must not survive a failed render");
});

test("device sync pairs, uploads changed files entry last, and fetches the native PNG", async () => {
  const documents = { "main.jsx": "old", "lib.js": "same" };
  const puts = []; let snapshotSequence = 0;
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, "http://x");
    const json = (value, status = 200) => { response.writeHead(status, { "content-type": "application/json" }); response.end(JSON.stringify(value)); };
    let body = "";
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      if (url.pathname === "/api/v1/pair") return JSON.parse(body).code === "123456" ? json({ token: "t" }) : json({ message: "Wrong code" }, 401);
      if (request.headers["x-studio-token"] !== "t") return json({ message: "Unauthorized" }, 401);
      if (url.pathname === "/api/v1/session" && request.method === "GET") return json({ device: { name: "Test iPhone" }, preview: { snapshotSequence } });
      if (url.pathname === "/api/v1/session") return json({ disconnected: true });
      if (url.pathname === "/api/v1/packages") return json({ packages: [{ id: "CLI Test", name: "CLI Test", entry: "main.jsx", files: Object.keys(documents) }] });
      if (url.pathname === "/api/v1/document" && request.method === "GET") {
        // Mirror older device servers, which read "+" literally.
        if (request.url.includes("+")) return json({ message: "Document not found" }, 404);
        const name = url.searchParams.get("path"); return json({ content: documents[name], revision: `r-${documents[name]}`, readOnly: false });
      }
      if (url.pathname === "/api/v1/document" && request.method === "POST") { documents[JSON.parse(body).path] = ""; return json({}, 201); }
      if (url.pathname === "/api/v1/document" && request.method === "PUT") {
        const update = JSON.parse(body);
        if (update.baseRevision !== `r-${documents[update.path]}`) return json({ message: "conflict" }, 409);
        documents[update.path] = update.content; puts.push(update.path);
        if (update.path === "main.jsx") setTimeout(() => { snapshotSequence += 1; }, 50);
        return json({ revision: "next" });
      }
      if (url.pathname === "/api/v1/preview") { response.writeHead(200, { "content-type": "image/png" }); return response.end(Buffer.from([137, 80, 78, 71])); }
      return json({ message: "unknown" }, 404);
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  try {
    const device = new DeviceSession(`http://127.0.0.1:${server.address().port}`);
    await assert.rejects(device.pair("000000"), /Wrong code/);
    const session = await device.pair("123456");
    assert.equal(session.device.name, "Test iPhone");
    const synced = await device.pushAndCapture({ files: { "main.jsx": "new", "lib.js": "same", "util/new.js": "x", "image/a.png": new Uint8Array([1]) }, manifestName: "CLI Test", entry: "main.jsx", poll: 20 });
    assert.deepEqual(puts, ["util/new.js", "main.jsx"]);
    assert.deepEqual([...synced.snapshot], [137, 80, 78, 71]);
    assert.equal(synced.skipped[0].path, "image/a.png");
    await device.disconnect();
  } finally { server.close(); }
});

test("the MCP server lists tools and confines paths", { skip: !hasChrome && "Chrome not found" }, async () => {
  const child = spawn(process.execPath, [path.join(engine, "bin/scriptwidget-mcp.mjs")], { cwd: engine });
  const lines = [];
  child.stdout.on("data", (chunk) => lines.push(...chunk.toString().trim().split("\n")));
  const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
  send({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18" } });
  send({ jsonrpc: "2.0", id: 2, method: "tools/list" });
  send({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "validate_widget_package", arguments: { path: "/etc" } } });
  const deadline = Date.now() + 10000;
  while (lines.length < 3 && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 50));
  child.stdin.end();
  const messages = lines.map((line) => JSON.parse(line));
  assert.equal(messages.find((m) => m.id === 1).result.serverInfo.name, "scriptwidget-preview");
  assert.deepEqual(messages.find((m) => m.id === 2).result.tools.map((tool) => tool.name), ["render_widget_preview", "validate_widget_package", "export_widget_package"]);
  assert.equal(messages.find((m) => m.id === 3).result.isError, true);
});
