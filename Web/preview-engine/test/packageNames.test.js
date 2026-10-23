import assert from "node:assert/strict";
import test from "node:test";
import { validPackageName, newManifest, validateManifest, importPackage, writeArchive } from "../src/package/index.js";
import { executePackageInNode } from "../src/node.js";

test("package display names cannot become directory traversal or reserved cache paths", () => {
  for(const name of ["", " ", ".", "..", "../outside", "/outside", "folder/child", "folder\\child", "__Build", "__BUILD", ".hidden", "name\0bad", "name\nbad", "C:relative", "a".repeat(81), "😀".repeat(61)]) {
    assert.equal(validPackageName(name),false,name);
    assert.equal(validateManifest({...newManifest("Safe"),name},["main.jsx"]).valid,false,name);
  }
  for(const name of ["My Widget", "阅读记录", "👩‍💻 Focus", "e\u0301".repeat(80), "😀".repeat(60)]) {
    assert.equal(validPackageName(name),true,name);
    assert.equal(validateManifest({...newManifest("Safe"),name},["main.jsx"]).valid,true,name);
  }
});

test("wrong-case manifest files fail before any legacy code executes", async () => {
  for(const name of ["Widget.json", "WIDGET.JSON"]) {
    const result = await executePackageInNode({files:{[name]:JSON.stringify(newManifest("Safe")),"main.jsx":"$render(<text>must not run</text>);"}});
    assert.equal(result.tree,null);
    assert.match(result.error.message,/invalid_manifest_case/);
  }
});


test("archive import rejects a wrongly cased manifest instead of creating legacy permissions", async () => {
  const bytes = writeArchive("WrongCase", {"Widget.json":JSON.stringify(newManifest("WrongCase")),"main.jsx":"$render(<text>legacy</text>);"});
  const result = await importPackage(bytes);
  assert.match(result.error,/invalid_manifest_case/);
  assert.equal(result.manifest,undefined);
});
