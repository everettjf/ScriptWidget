import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { storageAPICatalog } from "../src/storageAPICatalog.js";
import { scriptWidgetAPI } from "../src/scriptWidgetAPI.js";

test("storage completions exactly cover the native export protocol", async () => {
  const source = await readFile(new URL("../../../Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetRuntimeStorage.swift", import.meta.url), "utf8");
  const body = source.match(/protocol ScriptWidgetRuntimeStorageExports: JSExport \{([\s\S]*?)\n\}/)[1];
  const methods = [...body.matchAll(/static func (\w+)\(([^\n]*)\) -> ([^\n]+)/g)];
  assert.deepEqual(storageAPICatalog.map((item) => item.id).sort(), methods.map((item) => `$storage.${item[1]}`).sort());
  for (const [, name, args, result] of methods) {
    const api = storageAPICatalog.find((item) => item.id === `$storage.${name}`);
    assert.equal(api.arguments.length, args ? args.split(",").length : 0, name);
    assert.equal(api.preview, "initialState");
    assert.equal(scriptWidgetAPI.functions[api.id].returns, api.returns);
    if (result === "Bool") assert.equal(api.returns, "boolean");
  }
});
