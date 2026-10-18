import assert from "node:assert/strict";
import test from "node:test";
import { executePackageInNode } from "../src/node.js";
import { normalizePackagePath } from "../src/packageFiles.js";

const run = (source, { files = {}, ...options } = {}) =>
  executePackageInNode({ timeoutMilliseconds: 1000, ...options, files: { "main.jsx": source, ...files } });

test("props and children cross the bridge exactly like JavaScriptCore", async () => {
  // Same source and expectation as BrowserPreviewParityTests.testBridgeSemanticsProbe.
  const result = await run(`$render(<vstack a={1} b={1.5} c={true} d="x" e={null} f={undefined} g={() => 1} h={[1, undefined, null]} i={{ x: 1 }} j={new Date(0)}>
  {"s"}{1}{true}{null}{undefined}{[["n", [2]]]}
</vstack>);`);
  assert.equal(result.error, null);
  assert.equal(result.tree, '{"$element":"vstack","props":{"a":1,"b":1.5,"c":true,"d":"x","e":null,"g":{"$dict":{}},"h":[1,null,null],"i":{"$dict":{"x":1}},"j":{"$date":0}},"children":["s",1,true,null,null,[["n",[2]]]]}');
});

test("function components receive bridged props and lose function values", async () => {
  const result = await run(`const Card = (props) => <text>{typeof props.onTap}:{String(props.n)}:{props.children.length}</text>;
$render(<Card onTap={() => 1} n={2}><spacer /></Card>);`);
  assert.equal(result.error, null);
  assert.equal(result.tree, '{"$element":"text","props":null,"children":["object",":","2",":",1]}');
});

test("a single-child root fragment is unwrapped and nested fragments are kept", async () => {
  const root = await run("$render(<><text>a</text></>);");
  assert.equal(root.tree, '{"$element":"text","props":null,"children":["a"]}');
  const nested = await run("$render(<vstack><><text>a</text></></vstack>);");
  assert.match(nested.tree, /"\$element":"Fragment"/);
});

test("missing $render text yields the native placeholder element", async () => {
  const result = await run("const value = 1;");
  assert.equal(result.tree, '{"$element":"text","props":null,"children":["#UI Not Found#"]}');
});

test("errors use the native categories", async () => {
  assert.equal((await run('throw new Error("boom")')).error.kind, "scriptException");
  assert.equal((await run("$render(<text>)")).error.kind, "scriptException");
  assert.equal((await run("const C = () => { throw new Error('inner') }; $render(<C />);")).error.kind, "scriptException");
  assert.equal((await run("const C = () => 5; $render(<C />);")).error.kind, "scriptError");
  assert.equal((await run("$render('text')")).error.message, "Transform result is not Element : nil");
  assert.equal((await run("$render(<text a={...[]} />)")).error.kind, "scriptException");
  assert.equal((await run("$render(<text />, 1); x();")).error, null);
});

test("primitive props throw the JavaScriptCore conversion error", async () => {
  const result = await run('$render(ScriptWidget.createElement("text", "bad"))');
  assert.equal(result.error.kind, "scriptException");
  assert.match(result.error.message, /Cannot convert primitive to NSDictionary/);
});

test("runaway synchronous and asynchronous work is terminated", async () => {
  const loop = await run("while (true) {} $render(<text />);", { timeoutMilliseconds: 300 });
  assert.equal(loop.error.kind, "resourceLimit");
  const hang = await run("await new Promise(() => {}); $render(<text />);", { timeoutMilliseconds: 300 });
  assert.equal(hang.error.kind, "resourceLimit");
  const microtasks = await run("const spin = () => Promise.resolve().then(spin); spin(); $render(<text />);", { timeoutMilliseconds: 300 });
  assert.notEqual(microtasks.tree === null && microtasks.error === null, true);
});

test("element tree limits match the native contract", async () => {
  const wide = await run("$render(<vstack>{Array.from({ length: 1000 }, (_, i) => <text>{i}</text>)}</vstack>);");
  assert.equal(wide.error.kind, "resourceLimit");
  const props = await run("const p = {}; for (let i = 0; i < 129; i++) p['k' + i] = i; $render(ScriptWidget.createElement('text', p));");
  assert.equal(props.error.kind, "resourceLimit");
  const deep = await run("let e = <text />; for (let i = 0; i < 64; i++) e = <vstack>{e}</vstack>; $render(e);");
  assert.equal(deep.error.kind, "resourceLimit");
});

test("$import shares one global lexical scope and reports missing files", async () => {
  const shared = await run('$import("lib.jsx"); $render(<text>{label}</text>);', { files: { "lib.jsx": "const label = 'from lib';" } });
  assert.equal(shared.tree, '{"$element":"text","props":null,"children":["from lib"]}');
  const missing = await run('const ok = $import("missing.js"); $render(<text>{String(ok)}</text>);');
  assert.equal(missing.tree, '{"$element":"text","props":null,"children":["false"]}');
  assert.equal(missing.diagnostics[0].code, "import.missing");
  const escape = await run('$render(<text>{String($import("../outside.js"))}</text>);');
  assert.match(escape.tree, /"false"/);
});

test("the user realm does not see host or browser-only globals", async () => {
  const result = await run("$render(<text>{[typeof Babel, typeof setTimeout, typeof process, typeof require, typeof TextEncoder, typeof console.warn].join(',')}</text>);");
  assert.equal(result.tree, '{"$element":"text","props":null,"children":["undefined,undefined,undefined,undefined,undefined,undefined"]}');
});

test("fetch is fixture-only and enforces native network policy", async () => {
  const fixtures = { fetch: [{ url: "https://api.example.com/v1", body: "{\"ok\":1}" }] };
  const allowed = await run('const body = await fetch("https://api.example.com/v1"); $render(<text>{body}</text>);', { fixtures });
  assert.equal(allowed.tree, '{"$element":"text","props":null,"children":["{\\"ok\\":1}"]}');

  const policy = (url, manifest) => run(`let r; try { r = await fetch(${JSON.stringify(url)}); } catch (e) { r = "rejected:" + e; } $render(<text>{r}</text>);`, { fixtures, manifest });
  assert.match((await policy("https://127.0.0.1/x")).tree, /Local and private network hosts are not allowed/);
  assert.match((await policy("file:///etc/passwd")).tree, /Only HTTP and HTTPS URLs are allowed/);
  const manifest = { permissions: [], networkDomains: [] };
  assert.match((await policy("https://api.example.com/v1", manifest)).tree, /Network host is not declared in widget.json/);
  const declared = { permissions: ["network"], networkDomains: ["*.example.com"] };
  assert.match((await policy("https://api.example.com/v1", declared)).tree, /ok/);

  const missing = await policy("https://other.example.org/");
  assert.equal(missing.diagnostics[0].code, "fixture.fetch.missing");
});

test("fetch returns the native then-only promise shim", async () => {
  const result = await run('const p = fetch("https://a.example.com/"); $render(<text>{[typeof p.then, typeof p.catch, String(p.then(() => {}, () => {}))].join(",")}</text>);');
  assert.equal(result.tree, '{"$element":"text","props":null,"children":["function,undefined,undefined"]}');
});

test("environment, appearance, and storage come from the preview context", async () => {
  const result = await run('$storage.setString("k", "v"); $render(<text>{$getenv("widget-size")}|{String($device.isdarkmode())}|{$storage.getString("k")}|{$getenv("nope")}</text>);', {
    environments: { "widget-size": "large" }, preview: { appearance: "dark" },
  });
  assert.equal(result.tree, '{"$element":"text","props":null,"children":["large","|","true","|","v","|",""]}');
});

test("package paths are normalized inside the package root", () => {
  assert.equal(normalizePackagePath("lib/../util.js"), "util.js");
  assert.equal(normalizePackagePath("./a/b.js"), "a/b.js");
  assert.equal(normalizePackagePath("../a.js"), null);
  assert.equal(normalizePackagePath("/etc/passwd"), null);
  assert.equal(normalizePackagePath("a\\b.js"), null);
  assert.equal(normalizePackagePath(""), null);
});
