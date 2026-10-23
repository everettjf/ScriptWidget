import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { executePackageInNode, readPackageDirectory } from "../src/node.js";
import { corpusPackages, parityDirectory, readNativeTrees, repositoryRoot, runParity, usesLiveData } from "./parity/corpus.js";

test("web execution reproduces every native corpus tree byte for byte", async () => {
  const { results } = await runParity();
  const mismatches = results.filter((result) => result.status !== "match" && result.status !== "skipped");
  assert.deepEqual(mismatches.map((result) => `${result.name}: ${result.status}`), []);
  assert.ok(results.filter((result) => result.status === "match").length >= 100);
});

test("the native parity file covers exactly the shared corpus", () => {
  const native = readNativeTrees();
  assert.deepEqual(Object.keys(native.entries).sort(), corpusPackages().map((item) => item.name).sort());
  for (const { name, directory } of corpusPackages()) {
    const source = fs.readFileSync(path.join(directory, "main.jsx"), "utf8");
    assert.equal(Boolean(native.entries[name].skipped), usesLiveData(source), name);
  }
});

test("the comparison is sensitive to environment differences", async () => {
  const native = readNativeTrees();
  const prelude = fs.readFileSync(path.join(parityDirectory, "prelude.js"), "utf8");
  const files = readPackageDirectory(path.join(repositoryRoot, "Shared/ScriptWidgetRuntime/Resource/Script.bundle/component/date"));
  const hours = { "main.jsx": "$render(<text>{new Date().getHours()}</text>);" };
  const here = await executePackageInNode({ files: hours, prelude, timeZone: native.timeZone });
  const otherZone = native.timeZone === "Asia/Tokyo" ? "UTC" : "Asia/Tokyo";
  const shifted = await executePackageInNode({ files: hours, prelude, timeZone: otherZone });
  assert.notEqual(shifted.tree, here.tree);
  const withoutPrelude = await executePackageInNode({ files, timeZone: native.timeZone });
  assert.notEqual(withoutPrelude.tree, native.entries["component/date"].tree);
});

test("generic corpus prelude prevents imported helper calls from reaching live networking",async()=>{
  const prelude=fs.readFileSync(path.join(parityDirectory,"prelude.js"),"utf8");
  const files={"main.jsx":"$import('lib/network.js');const result=await hiddenRequest();$render(<text>{result}</text>);","lib/network.js":"async function hiddenRequest(){try{await $http.getResponse('https://api.example.com/data');return 'live';}catch{return 'offline';}}"};
  const result=await executePackageInNode({files,prelude,fixtures:{fetch:[{url:"https://api.example.com/data",status:200,body:"live"}]}});
  assert.equal(result.error,null);assert.ok(result.tree.includes("offline"));
});
