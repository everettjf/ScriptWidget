import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {executePackageInNode} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Control Switch/",import.meta.url);
const filesFor=()=>Object.fromEntries(["main.jsx","widget.json"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
async function run({action="",value="",storage={},atomic=true,size="medium"}={}){
 const files=filesFor();files["main.jsx"]="const finalRender=$render;$render=()=>{};"+files["main.jsx"];if(action)files["main.jsx"]+=`\n${action}();`;
 files["main.jsx"]+='\nconst captured=$storage.getString("switch.enabled");finalRender(<text>{captured}</text>);';
 return executePackageInNode({files,fixtures:{storage,storageAtomicAvailable:atomic},environments:{"widget-size":action?"action":size,"action-value":value}});
}
const stored=result=>{assert.equal(result.error,null,result.error?.message);return JSON.parse(result.tree).children.join("");};
test("rendering does not save a fake switch state; named actions share the same persisted value",async()=>{
 assert.equal(stored(await run()),"");assert.equal(stored(await run({action:"setFlag"})),"true");
 assert.equal(stored(await run({action:"setFlag",storage:{"switch.enabled":"true"}})),"false");
 assert.equal(stored(await run({action:"enableFlag",storage:{"switch.enabled":"true"}})),"true");
 assert.equal(stored(await run({action:"disableFlag"})),"false");
});
test("explicit control values are idempotent and do not become a second toggle",async()=>{
 assert.equal(stored(await run({action:"setFlag",value:"true",storage:{"switch.enabled":"true"}})),"true");
 assert.equal(stored(await run({action:"setFlag",value:"false",storage:{"switch.enabled":"false"}})),"false");
 assert.ok((await run({action:"setFlag",value:"invalid"})).error);assert.ok((await run({storage:{"switch.enabled":"corrupt"}})).error);assert.ok((await run({action:"setFlag",atomic:false})).error);
});

test("local switch state trees match native output across every family",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("parity/launcher-controls-trees.json",import.meta.url),"utf8"));
 for(const variant of ["off","on"])for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]){
  const result=await executePackageInNode({files:filesFor(),prelude:'$device.isdarkmode=()=>false;',fixtures:{storage:{"switch.enabled":variant==="on"?"true":""}},environments:{"widget-size":size}});
  assert.equal(result.error,null,result.error?.message);assert.equal(result.tree,fixture.trees[`Control Switch/${variant}/${size}`]);
 }
});
