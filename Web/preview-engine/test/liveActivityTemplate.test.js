import assert from "node:assert/strict";
import fs from "node:fs";
import {fileURLToPath} from "node:url";
import test from "node:test";
import {executePackageInNode,readPackageDirectory} from "../src/node.js";
const directory=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Live Activity Demo/",import.meta.url);
async function run(state="",{region=null,stale=false,parameter=""}={}){
  const files=readPackageDirectory(fileURLToPath(directory));
  const capture=region?'globalThis.capturedIsland=null;$dynamic_island=value=>{capturedIsland=value;};const originalRender=$render;$render=()=>{};':"";
  const select=region?`\noriginalRender(${["leading","trailing","center","bottom"].includes(region)?`capturedIsland.expanded.${region}`:`capturedIsland.${region}`});`:"";
  files["main.jsx"]=capture+files["main.jsx"]+select;
  return executePackageInNode({files,prelude:"Date.now=()=>1767268800000;",environments:{"widget-size":region?"dynamic-island":"live-activity","live-activity-state":state,"live-activity-is-stale":String(stale),"widget-param":parameter}});
}
test("local activity defaults are empty and explicit progress, deadlines and stale status update",async()=>{
  const empty=await run();assert.equal(empty.error,null);assert.ok(empty.tree.includes("Ready to start"));assert.ok(!empty.tree.includes("Morning Run"));
  const progress=await run(JSON.stringify({title:"Reading",progress:3,total:8}));assert.equal(progress.error,null);assert.ok(progress.tree.includes("3 / 8"));
  const future=await run(JSON.stringify({title:"Focus",endsAt:"2026-01-01T12:25:00Z"}));assert.equal(future.error,null);assert.ok(future.tree.includes('"$element":"date"'));assert.ok(future.tree.includes('"style":"timer"'));
  const expired=await run(JSON.stringify({endsAt:"2026-01-01T11:00:00Z"}));assert.ok(expired.tree.includes("Time is up"));assert.ok(!expired.tree.includes('"$element":"date"'));
  assert.ok((await run('{"title":"Focus"}',{stale:true})).tree.includes("Data needs an update"));
  assert.ok((await run("",{parameter:'{"title":"Parameter fallback"}'})).tree.includes("Parameter fallback"));
});
test("invalid activity input renders a helpful state without exposing source data",async()=>{
  for(const value of ["{private-secret",'[]','null','{"secret":"private-secret"}','{"progress":9,"total":8}','{"progress":1}','{"endsAt":"tomorrow"}','{"title":42}','{"detail":false}']){
    const result=await run(value);assert.equal(result.error,null,result.error?.message);assert.ok(result.tree.includes("Invalid activity state"),value);assert.ok(!result.tree.includes("private-secret"));assert.ok(result.tree.includes("Check state"));assert.ok(!result.tree.includes("Active"));
  }
});
test("lock screen and seven Island region trees match real JavaScriptCore output",async()=>{
  const fixture=JSON.parse(fs.readFileSync(new URL("parity/live-activity-trees.json",import.meta.url),"utf8"));
  assert.equal(Object.keys(fixture.trees).length,64);
  for(const [variant,state] of Object.entries(fixture.states))for(const region of ["lockScreen","leading","trailing","center","bottom","compactLeading","compactTrailing","minimal"]){
    const result=await run(state,{region:region==="lockScreen"?null:region,stale:variant==="stale"});
    assert.equal(result.error,null,result.error?.message);assert.equal(result.tree,fixture.trees[`${variant}/${region}`],`${variant}/${region}`);
  }
});
