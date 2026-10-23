import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { newManifest } from "../../preview-engine/src/package/index.js";
import { defaultFixtures, musicScenario, parseMocks, setResponse, type MockObject } from "../src/mockData.ts";

const code = "try{$render(<text>{JSON.stringify(await $music.current())}</text>);}catch(e){$render(<text>{String(e)}</text>);} ";
async function run(fixtures = parseMocks(defaultFixtures), source = code, permission = true, environments: Record<string,string> = {}) {
  const manifest = {...newManifest("Music"), permissions: permission ? ["music" as const] : []};
  const result = await executePackageInNode({files:{"main.jsx":source,"widget.json":JSON.stringify(manifest)},manifest,fixtures,environments});
  assert.equal(result.error,null);
  return JSON.parse(result.tree!).children[0] as string;
}
test("Music scenarios preserve playing with withheld details and distinguish denied and unavailable", async () => {
  for (const state of ["playing","paused","stopped","withheld","denied","unavailable"] as const) {
    const fixtures = parseMocks(musicScenario(defaultFixtures,state));
    const output = await run(fixtures);
    if (state === "denied" || state === "unavailable") assert.match(output,new RegExp(`music_${state === "denied" ? "permission" : "unavailable"}`));
    else {
      const value = JSON.parse(output);
      assert.equal(value.state,state === "withheld" ? "playing" : state);
      assert.equal(value.hasItem,!["withheld","stopped"].includes(state));
      if (state === "withheld") { assert.equal(value.title,null); assert.equal(value.duration,null); }
    }
  }
});
test("Music mocks cannot bypass package permission, future-entry rules or the shared query budget", async () => {
  assert.match(await run(undefined,code,false),/music_permission/);
  const budget = "try{for(let i=0;i<9;i++)await $music.current();$render(<text>bad</text>);}catch(e){$render(<text>{String(e)}</text>);}";
  assert.match(await run(undefined,budget),/query_limit/);
  const copy = "const a=await $music.current();a.title='changed';const b=await $music.current();$render(<text>{b.title}</text>);";
  assert.equal(await run(undefined,copy),"Morning Light");
  assert.match(await run(undefined,code,true,{"timeline-is-projection":"true"}),/timeline_read_only/);
  assert.match(await run(undefined,code,true,{"widget-size":"live-activity"}),/timeline_read_only/);
});
test("Music validates closed fields, nullable metadata and finite bounded seconds in the panel and executor", async () => {
  const sample = ((parseMocks(defaultFixtures).api as MockObject)["$music.current"] as MockObject).value as MockObject;
  const invalid: MockObject[] = [{duration:0},{position:-1},{title:"bad\n"},{provider:"spotify"},{token:"private"},{capturedAt:"bad"},{hasItem:false}];
  for (const change of invalid) {
    const text = setResponse(defaultFixtures,"$music.current",{value:{...sample,...change}});
    assert.throws(()=>parseMocks(text));
    assert.match(await run(JSON.parse(text)),/music_snapshot/);
  }
  const valid = parseMocks(setResponse(defaultFixtures,"$music.current",{value:{...sample,position:0,duration:null,title:null}}));
  const value = JSON.parse(await run(valid)); assert.equal(value.position,0); assert.equal(value.duration,null);
});

test("Music template matches actual native JavaScriptCore trees in six states and eight families", async () => {
  const root = new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Music Playback/", import.meta.url);
  const files = Object.fromEntries(["main.jsx", "widget.json"].map(path => [path, fs.readFileSync(new URL(path, root), "utf8")]));
  const expected = JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/music-playback-trees.json", import.meta.url), "utf8"));
  for (const state of ["playing", "paused", "stopped", "withheld", "denied", "unavailable"] as const) {
    for (const family of ["small", "medium", "large", "extraLarge", "extraLargePortrait", "accessoryInline", "accessoryCircular", "accessoryRectangular"]) {
      const fixtures = parseMocks(musicScenario(defaultFixtures, state));
      const result = await executePackageInNode({files, fixtures, environments:{"widget-size":family}});
      assert.equal(result.error, null, state + "/" + family);
      assert.equal(result.tree, expected.trees[state + "/" + family], state + "/" + family);
    }
  }
});
