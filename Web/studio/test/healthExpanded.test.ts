import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import {executePackageInNode} from "../../preview-engine/src/node.js";
import {newManifest} from "../../preview-engine/src/package/manifest.js";
import {defaultFixtures,parseMocks,permissionScenario,setResponse} from "../src/mockData.ts";
const manifest={...newManifest("Expanded Health"),permissions:["health"]};
const run=(source:string,fixtures:any=parseMocks(defaultFixtures),environments:any={},selected:any=manifest)=>executePackageInNode({files:{"main.jsx":source},manifest:selected,fixtures,environments});
const value=(result:any)=>JSON.parse(JSON.parse(result.tree).children[0]);
test("healthy summaries expose sleep stages, three rings and optional workout statistics",async()=>{
 const result=await run("const s=await $health.sleepSummary(),a=await $health.activitySummary(),w=await $health.workouts();$render(<text>{JSON.stringify({s,a,w})}</text>);");assert.equal(result.error,null);
 const data=value(result);assert.equal(data.s.totalSleepSeconds,27000);assert.equal(data.a.move.goal,600);assert.equal(data.w.items[0].distanceMeters,5200);
});
test("Health mocks never grant manifest permission or live-presentation access",async()=>{
 for(const method of ["requestAuthorization","stepCountToday","activeEnergyToday","heartRateLatest","sleepSummary","activitySummary","workouts"]) {
  const denied=await run(`await $health.${method}();$render(<text>bad</text>);`,parseMocks(defaultFixtures),{},{...manifest,permissions:[]});assert.match(denied.error!.message,/permission_denied/);
  for(const env of [{"timeline-is-projection":"true"},{"widget-size":"live-activity"}]) {
   const projected=await run(`await $health.${method}();$render(<text>bad</text>);`,parseMocks(defaultFixtures),env);assert.match(projected.error!.message,/timeline_read_only/);
  }
 }
});
test("new Health reads validate bounded ranges, Gregorian days and strict numeric limits",async()=>{
 for(const [method,options] of [["sleepSummary",{limit:1}],["sleepSummary",{start:"2026-02-29T00:00:00Z"}],["sleepSummary",{end:"2026-03-01T24:00:00Z"}],["sleepSummary",{start:"2026-01-01T00:00:00Z",end:"2026-02-01T00:00:00Z"}],["activitySummary",{date:"9999-01-01"}],["activitySummary",{date:"2026-02-29"}],["workouts",{limit:true}],["workouts",{limit:51}],["workouts",{limit:1.5}],["workouts",{start:null}]]) {
  const result=await run(`await $health.${method}(${JSON.stringify(options)});$render(<text>bad</text>);`);assert.match(result.error!.message,/invalid_options/);
 }
});
test("no shared Health data keeps read authorization private and does not invent goals",async()=>{
 const fixtures=parseMocks(permissionScenario(defaultFixtures,"health","empty"));
 const result=await run("$render(<text>{JSON.stringify({s:await $health.sleepSummary(),a:await $health.activitySummary(),w:await $health.workouts(),status:$health.authorizationStatus()})}</text>);",fixtures);
 assert.equal(result.error,null);const data=value(result);assert.equal(data.status,"notDisclosed");assert.equal(data.s.hasSamples,false);assert.equal(data.a.move.goal,null);assert.deepEqual(data.w.items,[]);
});
test("Health supports move-time rings, missing workout stats and source query filtering",async()=>{
 let fixtures=parseMocks(defaultFixtures);const api=fixtures.api as any;
 api["$health.activitySummary"].value={...api["$health.activitySummary"].value,moveMode:"moveTime",move:{value:45,goal:60,unit:"min"}};
 api["$health.workouts"].value.items[0].energyKcal=null;api["$health.workouts"].value.items[0].distanceMeters=null;
 const result=await run("$render(<text>{JSON.stringify({a:await $health.activitySummary(),w:await $health.workouts()})}</text>);",fixtures);assert.equal(result.error,null);assert.equal(value(result).a.move.unit,"min");assert.equal(value(result).w.items[0].energyKcal,null);
 const filtered=await run(`$render(<text>{JSON.stringify(await $health.workouts({start:${JSON.stringify(new Date(Date.now()-60000).toISOString())}}))}</text>);`,fixtures);assert.equal(filtered.error,null);assert.deepEqual(value(filtered).items,[]);
});
test("Health shares budget across legacy and expanded reads, without exporting saved samples",async()=>{
 const result=await run("for(let i=0;i<4;i++){await $health.stepCountToday();await $health.activitySummary();}await $health.sleepSummary();$render(<text>bad</text>);");assert.match(result.error!.message,/query_limit/);
});
test("invalid aggregate mocks fail visibly instead of manufacturing valid health results",async()=>{
 const data=(parseMocks(defaultFixtures).api as any)["$health.sleepSummary"].value;
 for(const change of [{totalSleepSeconds:999999},{hasSamples:false},{sourceCount:-1},{stages:{core:27000}},{aggregation:"pretend"}]) {
  const result=await run("await $health.sleepSummary();$render(<text>bad</text>);",parseMocks(setResponse(defaultFixtures,"$health.sleepSummary",{value:{...data,...change}})));assert.match(result.error!.message,/mock_invalid/);
 }
});

test("Health Overview matches 128 native trees across modes, states and widget families",async()=>{
 const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Health Overview/",import.meta.url);
 const files=Object.fromEntries(["main.jsx","widget.json"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
 const native=JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/health-overview-trees.json",import.meta.url),"utf8"));
 for(const [key,tree] of Object.entries(native.trees)) {
  const [state,mode,family]=key.split("/") as [string,string,string];
  let mocks=defaultFixtures;
  if(state==="empty")mocks=permissionScenario(mocks,"health","empty");
  if(state==="unavailable")mocks=setResponse(mocks,"$health.isAvailable",{value:false});
  if(state==="error")for(const method of ["sleepSummary","activitySummary","workouts"])mocks=setResponse(mocks,`$health.${method}`,{error:"query_failed"});
  const result=await executePackageInNode({files,fixtures:parseMocks(mocks),environments:{"widget-size":family,"widget-param":mode},prelude:"$device.isdarkmode=()=>false;"});
  assert.equal(result.error,null,key+": "+result.error?.message);
  assert.equal(result.tree,tree,key);
 }
});
