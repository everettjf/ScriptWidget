import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {executePackageInNode} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Photo Card/",import.meta.url);
const filesFor=()=>Object.fromEntries(["main.jsx","widget.json","lib/configuration.js"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
const names=[1,2,3,4].map(number=>`photo-00000000-0000-4000-8000-${String(number).padStart(12,"0")}`);
const values={title:"My moments",caption:"A little collection",layout:"grid",photos:names};
const storage=config=>({"recordTemplate.config.v1":JSON.stringify({version:1,kind:"photoCard",values:config})});
async function run({parameter="",config=null,size="large",inspect=false}={}) {
 const files=filesFor();
 if(inspect)files["main.jsx"]='const $testRender=$render;$render=()=>{};\n'+files["main.jsx"]+'\n$testRender(<text>{JSON.stringify(options)}</text>);';
 return executePackageInNode({files,environments:{"widget-size":size,"widget-param":parameter},fixtures:{storage:config?storage(config):{}}});
}
const text=tree=>typeof tree==="string"?tree:Array.isArray(tree)?tree.map(text).join(""):tree?.children?text(tree.children):"";
function images(tree) {if(!tree||typeof tree!=="object")return[];if(Array.isArray(tree))return tree.flatMap(images);return[...(tree.$element==="image"?[tree.props.name]:[]),...images(tree.children)];}

test("photo card starts with an honest empty state and no fake personal pictures",async()=>{
 const result=await run();assert.equal(result.error,null);assert.match(text(JSON.parse(result.tree)),/Add your photos/);assert.deepEqual(images(JSON.parse(result.tree)),[]);
});
test("saved photo order and layout drive single, duo and grid without writing settings",async()=>{
 for(const [layout,count] of [["single",1],["duo",2],["grid",4]]){
  const config={...values,layout,photos:[...names].reverse()},result=await run({config});assert.equal(result.error,null);
  assert.deepEqual(images(JSON.parse(result.tree)),config.photos.slice(0,count));
 }
 const result=await run({config:values,parameter:'{"title":"A day out","layout":"duo"}',inspect:true});assert.equal(result.error,null);
 const options=JSON.parse(text(JSON.parse(result.tree)));assert.equal(options.title,"A day out");assert.equal(options.layout,"duo");assert.deepEqual(options.photos,names);
});
test("photo names and configuration are closed, bounded and package relative",async()=>{
 for(const bad of [{photos:["../other"]},{photos:[names[0],names[0]]},{photos:[...names,names[0]]},{photos:["https://example.com/photo.png"]},{layout:"remote"},{title:" "},{caption:"x".repeat(81)}]){
  assert.ok((await run({config:{...values,...bad}})).error,JSON.stringify(bad));
 }
 for(const parameter of ['{"networkDomains":["example.com"]}',"not json","[]"]){assert.ok((await run({parameter})).error);}
});
test("all eight families render offline in both appearances with empty and configured data",async()=>{
 for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryCircular","accessoryRectangular","accessoryInline"]){
  for(const appearance of ["light","dark"]){for(const config of [null,values]){
   const result=await executePackageInNode({files:filesFor(),environments:{"widget-size":size,"widget-param":""},fixtures:{storage:config?storage(config):{}},preview:{appearance}});
   assert.equal(result.error,null,`${size}/${appearance}/${!!config}`);assert.ok(result.tree);
  }}
 }
});

test("all photo layouts and families match actual native trees",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("./parity/photo-card-trees.json",import.meta.url),"utf8"));
 for(const [key,expected]of Object.entries(fixture.trees)){
  const [layout,size]=key.split("/");const result=await run({parameter:JSON.stringify({...values,layout}),size});
  assert.equal(result.error,null,key);assert.equal(result.tree,expected,key);
 }
});
