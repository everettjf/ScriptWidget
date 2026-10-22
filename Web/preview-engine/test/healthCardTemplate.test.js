import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {executePackageInNode} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Health Steps Ring/",import.meta.url);
const time=Date.parse("2026-01-01T12:15:00Z");
const config={metric:"steps",stepsGoal:8000,energyGoal:500};
const reading={value:6840,hasSamples:true,unit:"count",start:"2026-01-01T08:00:00Z",end:"2026-01-01T12:15:00Z"};
async function run({settings=config,value=reading,mode="normal",family="medium",inspect=true,prefix="",projection=false,raw=""}={}) {
 const files=Object.fromEntries(["main.jsx","widget.json","lib/health.js"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
 const selected=settings?.metric ?? (raw ? JSON.parse(raw).values.metric : "steps");
 const capture='const calls=[];$health.requestAuthorization=()=>{throw new Error("must not prompt");};const query=$health.'+(selected==="energy"?"activeEnergyToday":selected==="heart"?"heartRateLatest":"stepCountToday")+';';
 const method=selected==="energy"?"activeEnergyToday":selected==="heart"?"heartRateLatest":"stepCountToday";
 files["main.jsx"]=capture+`$health.${method}=()=>{calls.push("${method}");return query();};`+prefix+files["main.jsx"];
 if(inspect)files["main.jsx"]='const savedRender=$render;$render=()=>{};'+files["main.jsx"]+'\nsavedRender(<text>{JSON.stringify({health,calls,raw:$storage.getString("recordTemplate.config.v1")})}</text>);';
 const fixtures={storage:{"recordTemplate.config.v1":raw},api:{"$health.isAvailable":{value:mode!=="unavailable"},"$health.authorizationStatus":{value:mode==="undeclared"?"undeclared":"notDisclosed"},[`$health.${method}`]:mode==="failure"?{error:"locked"}:{value}}};
 const result=await executePackageInNode({files,prelude:`Date.now=()=>${time};`,fixtures,environments:{"widget-size":family,"widget-param":settings===null?"":JSON.stringify(settings),"timeline-is-projection":String(projection)}});
 if(!inspect)return result;
 assert.equal(result.error,null,result.error?.message);return JSON.parse(JSON.parse(result.tree).children.join(""));
}
test("healthy metrics query once, show units/goals and never prompt or persist readings",async()=>{
 for(const [metric,value,unit] of [["steps",reading,"steps"],["energy",{...reading,value:420,unit:"kcal"},"kcal"],["heart",{...reading,value:72,unit:"bpm"},"bpm"]]) {
  const result=await run({settings:{...config,metric},value});assert.equal(result.health.available,true);assert.equal(result.calls.length,1);assert.equal(result.health.unit,unit);assert.equal(result.raw,"");
  assert.equal(result.health.goal,metric==="heart"?null:metric==="steps"?8000:500);
 }
});
test("empty queries do not fabricate zero or infer denied access; explicit readable zero is valid",async()=>{
 for(const value of [{...reading,value:0,hasSamples:false},{...reading,value:0,hasSamples:undefined},null]) {
  const result=await run({value});assert.equal(result.health.available,false);assert.match(result.health.detail,/not disclosed/);
 }
 assert.equal((await run({value:{...reading,value:0}})).health.value,0);
});
test("unavailable, undeclared and projected entries never query; failures remain visible",async()=>{
 for(const options of [{mode:"unavailable"},{mode:"undeclared"},{projection:true}]) {const result=await run(options);assert.equal(result.calls.length,0);assert.equal(result.health.available,false);}
 assert.match((await run({mode:"failure"})).health.heading,/unavailable/);
});
test("invalid units, dates, future, old and prior-day totals never masquerade as current readings",async()=>{
 for(const patch of [{unit:"cal"},{hasSamples:"true"},{value:-1},{value:"6840"},{value:1000001},{end:"invalid"},{end:"2026-01-01T13:15:00Z"},{end:"2026-01-01T11:00:00Z"},{start:"2025-12-31T08:00:00Z"}]) assert.equal((await run({value:{...reading,...patch}})).health.available,false,JSON.stringify(patch));
 const result=await run({settings:{...config,metric:"heart"},value:{...reading,value:72,unit:"bpm",start:"2025-12-31T10:00:00Z",end:"2025-12-31T10:01:00Z"}});assert.equal(result.health.available,false);
});
test("saved configuration and explicit partial overrides validate strictly",async()=>{
 const saved=JSON.stringify({version:1,kind:"healthCard",values:{...config,metric:"energy"}});
 const result=await run({settings:null,raw:saved,value:{...reading,value:420,unit:"kcal"}});
 assert.equal(result.health.available,true);assert.equal(result.health.value,420);
 for(const settings of [{...config,stepsGoal:true},{...config,metric:"sleep"},{...config,energyGoal:0},{...config,extra:1}]) {const result=await run({settings,inspect:false});assert.ok(result.error);}
 const result2=await run({settings:{stepsGoal:9000},raw:JSON.stringify({version:1,kind:"healthCard",values:config})});assert.equal(result2.health.goal,9000);
});
test("all eight sizes render meaningful health and empty states in both appearances",async()=>{
 for(const family of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"])for(const mode of ["normal","unavailable"])for(const dark of [false,true]) {const result=await run({family,mode,inspect:false,prefix:`$device.isdarkmode=()=>${dark};`});assert.equal(result.error,null,result.error?.message);assert.ok(result.tree);}
});

test("health states match actual native canonical trees for every metric and size",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("parity/health-card-trees.json",import.meta.url),"utf8"));
 for(const metric of ["steps","energy","heart"])for(const mode of ["normal","empty","unavailable","failure"])for(const family of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]) {
  const value={...reading,value:mode==="empty"?0:metric==="steps"?6840:metric==="energy"?420:72,hasSamples:mode!=="empty",unit:metric==="steps"?"count":metric==="energy"?"kcal":"bpm"};
  const result=await run({settings:{...config,metric},value,mode,family,inspect:false,prefix:'$device.isdarkmode=()=>false;'});
  assert.equal(result.error,null,result.error?.message);
  assert.equal(result.tree,fixture.trees[metric+"/"+mode+"/"+family]);
 }
});
