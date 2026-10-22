import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {executePackageInNode} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Quick Launcher/",import.meta.url);
const defaultItem={id:"one",title:"Website",icon:"globe",type:"web",target:"https://example.com",input:""};
const config={title:"My links",accent:"blue",items:[defaultItem]};
const filesFor=()=>Object.fromEntries(["main.jsx","widget.json","lib/launcher.js"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
async function run(settings=null,{raw="",inspect=true,size="medium",dark=false}={}){
 const files=filesFor();if(inspect)files["main.jsx"]='const finalRender=$render;$render=()=>{};'+files["main.jsx"]+'\nfinalRender(<text>{JSON.stringify({config,raw:$storage.getString("recordTemplate.config.v1")})}</text>);';
 const result=await executePackageInNode({files,prelude:`$device.isdarkmode=()=>${dark};`,fixtures:{storage:{"recordTemplate.config.v1":raw}},environments:{"widget-size":size,"widget-param":settings===null?"":JSON.stringify(settings)}});
 if(!inspect)return result;assert.equal(result.error,null,result.error?.message);return JSON.parse(JSON.parse(result.tree).children.join(""));
}
test("defaults and saved ordered links render without fetching or changing configuration",async()=>{
 const first=await run();assert.equal(first.config.items.length,3);assert.equal(first.raw,"");
 const saved=JSON.stringify({version:1,kind:"launcher",values:{...config,items:[{...defaultItem,id:"maps",type:"app",target:"maps://"},defaultItem]}});
 const next=await run({accent:"rose"},{raw:saved});assert.equal(next.config.items[0].url,"maps://");assert.equal(next.config.accent,"rose");assert.equal(next.raw,saved);
});
test("shortcut names and input are encoded as data without injecting extra URL parameters",async()=>{
 const item={...defaultItem,type:"shortcut",target:"阅读 + Plan & finish",input:"One+two & next=secret\n✓"};
 const result=await run({...config,items:[item]});const destination=new URL(result.config.items[0].url);
 assert.equal(destination.protocol,"shortcuts:");assert.equal(destination.hostname,"run-shortcut");assert.equal(destination.searchParams.get("name"),item.target);assert.equal(destination.searchParams.get("text"),item.input);assert.deepEqual([...destination.searchParams.keys()],["name","input","text"]);
});
test("invalid schemes, credentials, IDs, inputs and extra settings fail closed",async()=>{
 const bad=[{target:"javascript:alert(1)",type:"app"},{target:"file:///tmp/read",type:"app"},{target:"scriptwidget://import",type:"app"},{target:"app-prefs:root",type:"app"},{target:"https://user:pass@example.com"},{target:"https://example.com/%zz"},{target:"https://example.com:70000"},{target:"https://example.com/path with spaces"},{target:"https://example.com",type:"app"},{input:"unexpected"},{title:""},{title:"a\nb"},{icon:"unknown"},{id:"../one"},{type:"shortcut",target:"",input:""}];
 for(const patch of bad){const result=await run({...config,items:[{...defaultItem,...patch}]},{inspect:false});assert.ok(result.error,JSON.stringify(patch));}
 for(const settings of [{...config,items:[]},{...config,items:[defaultItem,defaultItem]},{...config,extra:true},{...config,items:Array.from({length:7},(_,i)=>({...defaultItem,id:String(i)}))}])assert.ok((await run(settings,{inspect:false})).error);
});
test("all families and both appearances respect available display capacity",async()=>{
 const settings={...config,items:Array.from({length:6},(_,i)=>({...defaultItem,id:String(i),title:`Link ${i+1}`}))};
 for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"])for(const dark of [false,true]){
  const result=await run(settings,{size,dark,inspect:false});assert.equal(result.error,null,result.error?.message);const tree=result.tree;
  if(["small","accessoryInline","accessoryCircular","accessoryRectangular"].includes(size)){assert.ok(tree.includes("Link 1"));assert.ok(!tree.includes("Link 2"));}
  if(size==="medium"){assert.ok(tree.includes("Link 3"));assert.ok(!tree.includes("Link 4"));}
 }
});

test("launcher layout trees match native output for each configuration and family",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("parity/launcher-controls-trees.json",import.meta.url),"utf8"));
 for(const variant of ["default","six","shortcut"])for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]){
  const settings=fixture.parameters[variant]?JSON.parse(fixture.parameters[variant]):null;
  const result=await run(settings,{size,inspect:false});assert.equal(result.error,null,result.error?.message);assert.equal(result.tree,fixture.trees[`Quick Launcher/${variant}/${size}`]);
 }
});
