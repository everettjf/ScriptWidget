import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { newManifest } from "../../preview-engine/src/package/manifest.js";
import { defaultFixtures, parseMocks, serviceScenario, setResponse } from "../src/mockData.ts";
const manifest = {...newManifest("GitHub"), minimumRuntimeVersion:"1.4", permissions:["services","network"],networkDomains:["api.github.com"]};
const code = "const r=await $services.profile('github');$render(<text>{JSON.stringify(r)}</text>);";
const run = (source=code, fixtures:any=parseMocks(defaultFixtures), selected:any=manifest, environments:any={}) => executePackageInNode({files:{"main.jsx":source},manifest:selected,fixtures,environments});
const profile = (result:any) => JSON.parse(JSON.parse(result.tree).children[0]);

test("services use typed editable healthy samples, with real zero and unshared counts",async()=>{
 const normal=await run();assert.equal(normal.error,null);assert.equal(profile(normal).username,"octocat");assert.equal(profile(normal).privateRepositories,8);
 const empty=await run(code,parseMocks(serviceScenario(defaultFixtures,"empty")));assert.equal(empty.error,null);assert.equal(profile(empty).publicRepositories,0);
 const unshared=await run(code,parseMocks(serviceScenario(defaultFixtures,"publicOnly")));assert.equal(unshared.error,null);assert.equal(profile(unshared).privateRepositories,null);
 const edited=parseMocks(setResponse(defaultFixtures,"$services.profile",{value:{...profile(normal),displayName:"My Account",username:"mona-cat_octo",publicRepositories:99}}));
 const managed=profile(await run(code,edited));assert.equal(managed.displayName,"My Account");assert.equal(managed.username,"mona-cat_octo");
});
test("service samples cannot override permissions, account grants, hosts or supported providers",async()=>{
 for(const selected of [{...manifest,permissions:[]},{...manifest,permissions:["network"]},{...manifest,permissions:["services"]},{...manifest,networkDomains:[]},{...manifest,networkDomains:["api.github.com.attacker.test"]}]) {
  const result=await run(code,undefined,selected);assert.match(result.error!.message,/(service_permission|package:undeclared_network|package:missing_network_domains)/);
 }
 for(const [scenario,pattern] of [["notConnected",/service_not_connected/],["notGranted",/service_permission/]] as const) assert.match((await run(code,parseMocks(serviceScenario(defaultFixtures,scenario)))).error!.message,pattern);
 for(const service of ["spotify","removed-provider","unknown","https://attacker.test"]) for(const method of ["status","profile"]) assert.match((await run(`await $services.${method}(${JSON.stringify(service)});$render(<text>bad</text>);`)).error!.message,/service_operation/);
 assert.match((await run("$render(<text>{typeof $services.playback}</text>);")).tree!,/undefined/);
});
test("service failures and data/query budgets are explicit",async()=>{
 for(const [scenario,pattern] of [["expired",/service_expired/],["rateLimited",/service_rate_limit/],["offline",/service_unavailable/]] as const) assert.match((await run(code,parseMocks(serviceScenario(defaultFixtures,scenario)))).error!.message,pattern);
 for(const env of [{"timeline-is-projection":"true"},{"widget-size":"live-activity"},{"widget-size":"dynamic-island"}]) assert.match((await run(code,undefined,manifest,env)).error!.message,/timeline_read_only/);
 const exhausted=await run("for(let i=0;i<9;i++)await $services.status('github');$render(<text>bad</text>);");assert.match(exhausted.error!.message,/query_limit/);
 const mixed=await run("for(let i=0;i<8;i++)try{await $health.stepCountToday();}catch{} await $services.profile('github');$render(<text>bad</text>);",undefined,{...manifest,permissions:[...manifest.permissions,"health"]});assert.match(mixed.error!.message,/query_limit/);
});
test("service mock validation rejects extra credential fields and malformed profile values",async()=>{
 const fixtures=parseMocks(defaultFixtures), sample=(fixtures.api as any)["$services.profile"].value;
 for(const patch of [{accessToken:"secret"},{url:"https://attacker.test"},{subject:"0"},{subject:"9007199254740992"},{username:"bad/name"},{displayName:"bad\nname"},{publicRepositories:-1},{publicRepositories:true},{followers:1.5},{following:"3"},{privateRepositories:undefined}]) {
  const invalid={...fixtures,api:{...(fixtures.api as any),"$services.profile":{value:{...sample,...patch}}}};
  assert.throws(()=>parseMocks(JSON.stringify(invalid)),/Service profile/);
  const result=await run(code,invalid);assert.match(result.error!.message,/mock_invalid/);
 }
 assert.throws(()=>parseMocks(setResponse(defaultFixtures,"$services.status",{value:"forged"})),/Service status/);
});
test("GitHub template renders all families and setup/failure states without inventing zero data",async()=>{
 const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/GitHub Profile/",import.meta.url);
 const files=Object.fromEntries(["main.jsx","widget.json"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
 for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]) {
  for(const scenario of ["connected","notConnected","notGranted","empty","publicOnly","expired","rateLimited","offline"] as const) {
   const result=await executePackageInNode({files,fixtures:parseMocks(serviceScenario(defaultFixtures,scenario)),environments:{"widget-size":size}});
   assert.equal(result.error,null,`${size}/${scenario}: ${result.error?.message}`);assert.ok(result.tree);
   if(size==="medium"&&scenario==="publicOnly")assert.match(result.tree!,/Private repository count not shared/);
   if(size==="small"&&scenario==="notConnected")assert.match(result.tree!,/Connect GitHub/);
  }
 }
});

test("GitHub profile states match actual native JavaScriptCore trees",async()=>{
 const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/GitHub Profile/",import.meta.url);
 const files=Object.fromEntries(["main.jsx","widget.json"].map(path=>[path,fs.readFileSync(new URL(path,root),"utf8")]));
 const expected=JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/github-profile-trees.json",import.meta.url),"utf8"));
 for(const scenario of ["connected","notConnected","notGranted","empty","publicOnly","expired","rateLimited","offline","unavailable"] as const)for(const family of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]) {
  const fixtures=parseMocks(scenario==="unavailable"?setResponse(defaultFixtures,"$services.status",{value:"unavailable"}):serviceScenario(defaultFixtures,scenario));
  const result=await executePackageInNode({files,fixtures,environments:{"widget-size":family}});assert.equal(result.error,null);
  assert.equal(result.tree,expected.trees[scenario+"/"+family],scenario+"/"+family);
 }
});
