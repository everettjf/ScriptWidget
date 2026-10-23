import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { newManifest } from "../../preview-engine/src/package/manifest.js";
import { defaultFixtures, parseMocks, permissionScenario, setResponse } from "../src/mockData.ts";
const manifest = {...newManifest("Photos"), permissions:["photos"]};
const run = (code = "const r=await $photos.items();$render(<text>{JSON.stringify(r)}</text>);", fixtures:any = parseMocks(defaultFixtures), environments:any = {}, selected:any=manifest) => executePackageInNode({files:{"main.jsx":code},manifest:selected,fixtures,environments});
const value = (r:any) => JSON.parse(JSON.parse(r.tree).children[0]);

test("photo previews expose bounded sample JPEGs without system library access",async()=>{
 const result=await run();assert.equal(result.error,null);const data=value(result);
 assert.equal(data.items.length,4);assert.match(data.items[0].image,/^data:image\/jpeg;base64,/);assert.equal(data.items[0].id,"sample.photo");
});
test("photo samples cannot bypass manifest permission, system denial or native selection",async()=>{
 const undeclared=await run(undefined,parseMocks(defaultFixtures),{}, {...manifest,permissions:[]});assert.match(undeclared.error!.message,/permission_denied/);
 for(const photosSelection of [[],null,["other"],["sample.photo","sample.photo"]]) {
  const result=await run(undefined,{...parseMocks(defaultFixtures),photosSelection});
  if(Array.isArray(photosSelection) && photosSelection[0]==="other") {assert.equal(result.error,null);assert.equal(value(result).items.length,0);} else assert.match(result.error!.message,/permission_denied/);
 }
 const denied=await run(undefined,parseMocks(permissionScenario(defaultFixtures,"photos","denied")));assert.match(denied.error!.message,/permission_denied/);
});
test("limited access, empty sources and cloud-only photos have distinct results",async()=>{
 const limited=parseMocks(setResponse(defaultFixtures,"$photos.authorizationStatus",{value:"limited"}));assert.equal((await run(undefined,limited)).error,null);
 const empty=await run(undefined,parseMocks(permissionScenario(defaultFixtures,"photos","empty")));assert.equal(empty.error,null);assert.equal(value(empty).items.length,0);
 const fixtures=parseMocks(defaultFixtures), snapshot=(fixtures.api as any)["$photos.items"].value;
 const cloud=await run(undefined,{...fixtures,api:{...(fixtures.api as any),"$photos.items":{value:{...snapshot,items:[],status:"unavailable",unavailableCount:1}}}});
 assert.equal(cloud.error,null);assert.equal(value(cloud).status,"unavailable");assert.equal(value(cloud).unavailableCount,1);
});
test("photo queries reject invalid options before returning mock values",async()=>{
 for(const options of [{limit:5},{limit:true},{limit:null},{offset:64},{offset:1.5},{maxAgeSeconds:-1},{maxAgeSeconds:null},{albumID:"forged"}]) {
  const result=await run(`await $photos.items(${JSON.stringify(options)});$render(<text>bad</text>);`);assert.match(result.error!.message,/invalid_options/);
 }
});
test("future and Live Activity photo presentations require prepared bounded snapshots",async()=>{
 for(const env of [{"timeline-is-projection":"true"},{"widget-size":"live-activity"}]) {
  const cached=await run(undefined,parseMocks(defaultFixtures),env);assert.equal(cached.error,null);assert.equal(value(cached).source,"cache");
  const missing=await run(undefined,{...parseMocks(defaultFixtures),photosSnapshotPrepared:false},env);assert.match(missing.error!.message,/cache_miss/);
 }
 const fixtures=parseMocks(defaultFixtures), snapshot=(fixtures.api as any)["$photos.items"].value;
 for(const fetchedAt of ["bad",new Date(Date.now()-86401*1000).toISOString(),new Date(Date.now()+60000).toISOString()]) {
  const stale=await run(undefined,{...fixtures,api:{...(fixtures.api as any),"$photos.items":{value:{...snapshot,fetchedAt}}}});assert.match(stale.error!.message,/cache_miss/);
 }
});
test("photo query budget is shared and corrupt image payloads fail closed",async()=>{
 const exhausted=await run("for(let i=0;i<9;i++)await $photos.items();$render(<text>bad</text>);");assert.match(exhausted.error!.message,/query_limit/);
 const fixtures=parseMocks(defaultFixtures), snapshot=(fixtures.api as any)["$photos.items"].value;
 const invalid=await run(undefined,{...fixtures,api:{...(fixtures.api as any),"$photos.items":{value:{...snapshot,items:[{...snapshot.items[0],image:"file:///private/photo.jpg"}]}}}});assert.match(invalid.error!.message,/mock_invalid/);
 assert.throws(()=>parseMocks(JSON.stringify({...fixtures,photosSelection:null})),/Photo selection/);
});
test("photo rotator has honest setup, cloud and snapshot states in all families",async()=>{
 const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Photo Album Rotator/",import.meta.url);
 const files=Object.fromEntries(["main.jsx","widget.json"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
 for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]) {
  for(const fixtures of [parseMocks(defaultFixtures),{...parseMocks(defaultFixtures),photosSelection:[]}]) {
   const result=await executePackageInNode({files,fixtures,environments:{"widget-size":size}});assert.equal(result.error,null,`${size}: ${result.error?.message}`);assert.ok(result.tree);
  }
 }
});


test("rotator selects different photos across local six-hour phases",async()=>{
 const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Photo Album Rotator/",import.meta.url);
 const files=Object.fromEntries(["main.jsx","widget.json"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
 const urls=new Set<string>();
 for(const hour of [0,6,12,18]) {
  const date=new Date();date.setHours(hour,0,0,0);
  const fixtures=parseMocks(defaultFixtures);
  const result=await executePackageInNode({files,fixtures,environments:{"widget-size":"medium","timeline-date":date.toISOString()}});assert.equal(result.error,null);
  const find=(element:any):string|undefined=>element?.$element==="image"?element.props.url:Array.isArray(element)?element.map(find).find(Boolean):element?.children?find(element.children):undefined;
  urls.add(find(JSON.parse(result.tree!))!);
 }
 assert.equal(urls.size,4);
});
