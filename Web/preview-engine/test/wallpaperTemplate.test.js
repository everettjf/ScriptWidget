import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {fileURLToPath} from "node:url";
import {executePackageInNode,readPackageDirectory} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Wallpaper Match/",import.meta.url);
const families=["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"];
const asset=(family="medium",appearance="light")=>({family,appearance,image:"background-00000000-0000-4000-8000-000000000001",label:"Top left"});
const base={title:"Quiet space",caption:"A little room to breathe",content:"text",ink:"light",backgrounds:[asset()]};
async function run(config=null,{family="medium",dark=false,missing=false,extraFiles={},inspect=false,now="2026-01-01T12:00:00Z"}={}){
 const files={...readPackageDirectory(fileURLToPath(root)),...extraFiles};
 if(config&&!missing)for(const item of config.backgrounds??[])files["image/"+item.image+".png"]=new Uint8Array([0,255,1]);
 if(inspect)files["main.jsx"]='const finalRender=$render;$render=()=>{};'+files["main.jsx"]+'\nfinalRender(<text>{$storage.getString("recordTemplate.config.v1")}</text>);';
 return executePackageInNode({files,preview:{appearance:dark?"dark":"light"},environments:{"widget-size":family,"widget-param":"","timeline-date":now},fixtures:{storage:config?{"recordTemplate.config.v1":JSON.stringify({version:1,kind:"wallpaper",values:config})}:{}}});
}
test("empty, opposite-appearance and missing-image states give accurate setup or restore guidance",async()=>{
 const empty=await run();assert.equal(empty.error,null);assert.ok(empty.tree.includes("Match your wallpaper"));
 const opposite=await run(base,{dark:true});assert.equal(opposite.error,null);assert.ok(opposite.tree.includes("Add a dark crop"));assert.ok(!opposite.tree.includes('"$element":"image"'));
 const missing=await run(base,{missing:true});assert.equal(missing.error,null);assert.ok(missing.tree.includes("Restore this crop"));
});
test("saved family and appearance select only their own local crop without changing settings",async()=>{
 const config={...base,backgrounds:[asset("small"),{...asset("medium","dark"),image:"background-00000000-0000-4000-8000-000000000002"}]};
 const result=await run(config,{family:"medium",dark:true});assert.equal(result.error,null);assert.ok(result.tree.includes(config.backgrounds[1].image));assert.ok(!result.tree.includes(config.backgrounds[0].image));
 const inspected=await run(config,{inspect:true});assert.equal(inspected.error,null);assert.equal(JSON.parse(inspected.tree).children[0],JSON.stringify({version:1,kind:"wallpaper",values:config}));
 for(const content of ["none","text","date"]){const view=await run({...base,content});assert.equal(view.error,null);assert.equal(view.tree.includes('"$element":"date"'),content==="date");assert.equal(view.tree.includes(base.caption),content!=="none");}
});
test("background references, duplicate slots, labels and unknown fields fail closed",async()=>{
 const variants=[{...base,extra:true},{...base,content:"clock"},{...base,ink:"remote"},{...base,backgrounds:[asset(),asset()]},{...base,backgrounds:[{...asset(),image:"../outside"}]},{...base,backgrounds:[{...asset(),image:"https://example.com/p.png"}]},{...base,backgrounds:[{...asset(),label:"hidden\u202e"}]},{...base,backgrounds:[{...asset(),family:"watch"}]},{...base,backgrounds:[{...asset(),appearance:"tinted"}]},{...base,title:"x".repeat(41)}];
 for(const config of variants)assert.ok((await run(config)).error,JSON.stringify(config));
});
test("all families render with no crop, valid crops and missing crops in both appearances",async()=>{
 for(const family of families)for(const dark of [false,true])for(const missing of [false,true]){
  const config={...base,content:"date",backgrounds:[asset(family,dark?"dark":"light")]};
  if(family.startsWith("accessory"))config.backgrounds=[];
  const result=await run(config,{family,dark,missing});assert.equal(result.error,null,result.error?.message);
 }
});
test("wallpaper trees match actual native output for each content and appearance",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("parity/wallpaper-trees.json",import.meta.url),"utf8"));assert.equal(Object.keys(fixture.trees).length,80);
 for(const variant of ["empty","none","text","date","missing"])for(const dark of [false,true])for(const family of families){
  const config=fixture.configurations[variant]===null?null:fixture.configurations[variant];
  const result=await run(config,{family,dark,missing:variant==="missing"});assert.equal(result.error,null,result.error?.message);
  assert.equal(result.tree,fixture.trees[`${variant}/${family}/${dark?"dark":"light"}`]);
 }
});
