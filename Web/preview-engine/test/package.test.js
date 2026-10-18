import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";
import { decodeManifest, exportPackage, importPackage, newProjectFiles, preflightArchive, validateManifest, writeArchive } from "../src/package/index.js";

const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), "fixtures");
const inflate = async (data) => new Uint8Array(zlib.inflateRawSync(data));
const valid = () => JSON.parse(newProjectFiles("Web Widget")["widget.json"]);

test("manifest decoding fails closed like readManifest", () => {
  assert.ok(decodeManifest(JSON.stringify(valid())).manifest);
  assert.match(decodeManifest(JSON.stringify({ ...valid(), permissionz: [] })).error, /unknown fields/);
  assert.match(decodeManifest(JSON.stringify({ ...valid(), supportedFamilies: ["systemHuge"] })).error, /unknown family/);
  assert.match(decodeManifest(JSON.stringify({ ...valid(), author: { name: "a", email: "x" } })).error, /author/);
  assert.match(decodeManifest("[]").error, /object/);
  assert.match(decodeManifest(JSON.stringify({ ...valid(), formatVersion: "2" })).error, /integer/);
});

test("manifest validation matches WidgetPackageManifestValidator", () => {
  const codes = (manifest, paths = ["main.jsx"]) => validateManifest(manifest, paths).issues.map((issue) => issue.code);
  assert.deepEqual(codes(valid()), []);
  assert.deepEqual(codes(valid(), []), ["missing_entry"]);
  assert.ok(codes({ ...valid(), networkDomains: ["api.example.com"] }).includes("undeclared_network"));
  assert.ok(codes({ ...valid(), permissions: ["network"] }).includes("missing_network_domains"));
  assert.ok(codes({ ...valid(), permissions: ["network"], networkDomains: ["API.example.com"] }).includes("invalid_network_domain"));
  assert.ok(codes({ ...valid(), entry: "../main.jsx" }).includes("invalid_entry"));
  assert.ok(codes({ ...valid(), entry: "main.ts" }, ["main.ts"]).includes("invalid_entry_type"));
  assert.ok(codes({ ...valid(), runtimeVersion: "2.0" }).includes("unsupported_runtime"));
  assert.ok(codes({ ...valid(), controls: [{ id: "t", type: "toggle", title: "T", systemImage: "power", actionID: "a", stateKey: "on" }], actions: [{ id: "a", title: "A", systemImage: "bolt", function: "run" }] }).includes("control_storage"));
  assert.ok(codes({ ...valid(), pushUpdates: { registrationURL: "https://127.0.0.1/x", channel: "c" }, permissions: ["network"], networkDomains: ["127.0.0.1"] }).includes("invalid_push_url"));
});

test("archive preflight rejects unsafe archives", () => {
  const ok = writeArchive("Widget", { "main.jsx": "$render(<text/>)" });
  assert.ok(preflightArchive(ok).entries);
  const traversal = writeArchive("..", { "main.jsx": "x" });
  assert.match(preflightArchive(traversal).error, /unsafe/);
  const duplicate = writeArchive("W", { "a.js": "1", "A.js": "2" });
  assert.match(preflightArchive(duplicate).error, /duplicate or case-colliding/);
  assert.match(preflightArchive(new Uint8Array(10)).error, /central directory/);
  const symlink = writeArchive("W", { "main.jsx": "x" });
  const view = new DataView(symlink.buffer);
  const central = symlink.length - 22 - (46 + "W/main.jsx".length);
  view.setUint32(central + 38, (0o120777 << 16) >>> 0, true);
  assert.match(preflightArchive(symlink).error, /Symbolic links/);
});

test("export and import round-trip with binary resources", async () => {
  const files = { ...newProjectFiles("Round Trip"), "image/dot.png": new Uint8Array([137, 80, 78, 71, 1, 2, 3]), "lib/util.js": "const a = 1;" };
  const exported = exportPackage(files);
  assert.equal(exported.fileName, "Round Trip.swt");
  const imported = await importPackage(exported.bytes, { inflate });
  assert.equal(imported.error, undefined);
  assert.deepEqual(Object.keys(imported.files).sort(), Object.keys(files).sort());
  assert.deepEqual([...imported.files["image/dot.png"]], [137, 80, 78, 71, 1, 2, 3]);
  assert.equal(imported.files["lib/util.js"], "const a = 1;");
});

test("imports deflated archives and legacy packages", async () => {
  const name = new TextEncoder().encode("Legacy/main.jsx");
  const data = new TextEncoder().encode("$render(<text>legacy</text>)");
  const compressed = zlib.deflateRawSync(data);
  const stored = writeArchive("Legacy", { "main.jsx": data });
  // Rewrite the single entry as deflate (method 8) to exercise inflation.
  const local = new Uint8Array(30 + name.length); local.set(stored.subarray(0, 30 + name.length));
  const localView = new DataView(local.buffer); localView.setUint16(8, 8, true); localView.setUint32(18, compressed.length, true);
  const central = new Uint8Array(46 + name.length); central.set(stored.subarray(30 + name.length + data.length, 30 + name.length + data.length + 46 + name.length));
  const centralView = new DataView(central.buffer); centralView.setUint16(10, 8, true); centralView.setUint32(20, compressed.length, true);
  const end = new Uint8Array(22); end.set(stored.subarray(stored.length - 22));
  const endView = new DataView(end.buffer); endView.setUint32(16, local.length + compressed.length, true);
  const archive = new Uint8Array([...local, ...compressed, ...central, ...end]);
  const imported = await importPackage(archive, { inflate });
  assert.equal(imported.error, undefined);
  assert.equal(imported.manifest.id, "legacy.legacy");
  assert.equal(imported.files["main.jsx"], "$render(<text>legacy</text>)");
});

test("a present but malformed widget.json fails closed", async () => {
  const archive = writeArchive("Bad", { "main.jsx": "x", "widget.json": "{\"formatVersion\":2,\"extra\":true}" });
  assert.match((await importPackage(archive, { inflate })).error, /unknown fields/);
});

test("the checked-in web export fixture is current", () => {
  // BrowserPreviewParityTests.testWebExportedPackageImportsNatively imports
  // this file with the native preflight, extraction, and validator.
  const files = { ...newProjectFiles("Web Export Fixture", "$render(<vstack><text>From the web</text><image id=\"dot\" frame=\"10,10\"/></vstack>);\n"), "image/dot.png": fs.readFileSync(path.join(fixtures, "dot.png")) };
  const manifest = JSON.parse(files["widget.json"]); manifest.id = "web.export.fixture"; files["widget.json"] = `${JSON.stringify(manifest, null, 2)}\n`;
  const exported = exportPackage(files);
  const target = path.join(fixtures, "web-export.swt");
  if (process.env.SCRIPTWIDGET_UPDATE_FIXTURES === "1" || !fs.existsSync(target)) fs.writeFileSync(target, writeArchive("Web Export Fixture", files, { date: new Date(2026, 0, 1) }));
  assert.equal(exported.error, undefined);
  assert.ok(preflightArchive(new Uint8Array(fs.readFileSync(target))).entries.length === 3);
});
