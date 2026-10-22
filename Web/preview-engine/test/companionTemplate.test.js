import assert from "node:assert/strict";
import fs from "node:fs";
import {fileURLToPath} from "node:url";
import test from "node:test";
import {executePackageInNode,readPackageDirectory} from "../src/node.js";
const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/",import.meta.url);
const kinds={"Plant Care":"plantCare","Pocket Pet":"pocketPet"};
async function run(name,{storage={},actions="",inspect=false,size="medium",dark=false,now="2026-03-08T12:00:00-07:00",parameter="",atomic=true,timeline=null,projection=false}={}){
 const files=readPackageDirectory(fileURLToPath(new URL(name+"/",root))),kind=kinds[name];
 if(actions||inspect)files["main.jsx"]='const finalRender=$render;$render=()=>{};'+files["main.jsx"]+'\n'+actions+'\nfinalRender(<text>{JSON.stringify({raw:$storage.getString("'+kind+'.v1"),config:localRecords.configuration("'+kind+'")})}</text>);';
 const prelude=`const RealDate=Date;const fixed=RealDate.parse(${JSON.stringify(now)});Date=class extends RealDate{constructor(...args){super(...(args.length?args:[fixed]));}static now(){return fixed;}};$device.isdarkmode=()=>${dark};`;
 const result=await executePackageInNode({files,prelude,timeZone:"America/Los_Angeles",fixtures:{storage,storageAtomicAvailable:atomic},environments:{"widget-size":size,"widget-param":parameter,"timeline-date":timeline||now,"timeline-is-projection":String(projection)}});
 if(inspect){assert.equal(result.error,null,result.error?.message);result.data=JSON.parse(JSON.parse(result.tree).children.join(""));}
 return result;
}
test("companions render empty, without inventing or saving care",async()=>{
 for(const name of Object.keys(kinds)){
  const result=await run(name,{inspect:true});assert.equal(result.data.raw,"");
  const view=await run(name);assert.equal(view.error,null);assert.ok(view.tree.includes(name==="Plant Care"?"No care recorded":"Ready for care"));
 }
});
test("explicit care is idempotent, undoable, retained on reopen and resettable",async()=>{
 for(const [name,kind] of Object.entries(kinds)){
  const action=name==="Plant Care"?"waterPlant()":"feedPet()";
  const result=await run(name,{actions:action+";"+action+";",inspect:true});const state=JSON.parse(result.data.raw);assert.equal(state.revision,1);assert.equal(state.entries.length,1);
  const storage={[kind+".v1"]:result.data.raw},reopened=await run(name,{storage,inspect:true});assert.equal(reopened.data.raw,result.data.raw);
  const cleared=await run(name,{storage,actions:"resetToday();",inspect:true});assert.equal(JSON.parse(cleared.data.raw).entries.length,0);
  const undone=await run(name,{storage:{[kind+".v1"]:cleared.data.raw},actions:"undoRecord();",inspect:true});assert.deepEqual(JSON.parse(undone.data.raw).entries,state.entries);
 }
 const pet=await run("Pocket Pet",{actions:"feedPet();playPet();restPet();restPet();",inspect:true});assert.deepEqual(JSON.parse(pet.data.raw).entries[0].value,["feed","play","rest"]);assert.equal(JSON.parse(pet.data.raw).revision,3);
});
test("care schedule counts calendar days across DST and never imports the old fake countdown",async()=>{
 const saved=await run("Plant Care",{now:"2026-03-07T12:00:00-08:00",actions:"waterPlant();",inspect:true});
 const view=await run("Plant Care",{storage:{"plantCare.v1":saved.data.raw},now:"2026-03-08T12:00:00-07:00"});assert.ok(view.tree.includes("Next care in 2 days"));
 const due=await run("Plant Care",{storage:{"plantCare.v1":saved.data.raw},now:"2026-03-10T12:00:00-07:00"});assert.ok(due.tree.includes("Care due"));
 const legacy=await run("Plant Care",{parameter:"Monstera,2"});assert.ok(legacy.tree.includes("Monstera"));assert.ok(legacy.tree.includes("No care recorded"));assert.ok(!legacy.tree.includes("Next care in 2 days"));
});
test("every supported family renders in both appearances with saved care",async()=>{
 for(const name of Object.keys(kinds)){
  const first=await run(name,{actions:name==="Plant Care"?"waterPlant();":"feedPet();playPet();restPet();",inspect:true});
  for(const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"])for(const dark of [false,true]){
   const view=await run(name,{storage:{[kinds[name]+".v1"]:first.data.raw},size,dark});assert.equal(view.error,null,`${name}/${size}: ${view.error?.message}`);
  }
 }
});
test("malformed history, invalid configuration and failed atomic writes remain visible",async()=>{
 for(const name of Object.keys(kinds)){
  assert.ok((await run(name,{storage:{[kinds[name]+".v1"]:"broken"}})).error);
  assert.ok((await run(name,{storage:{"recordTemplate.config.v1":JSON.stringify({version:1,kind:kinds[name],values:{title:"",intervalDays:99}})}})).error);
  const failed=await run(name,{actions:name==="Plant Care"?"waterPlant();":"feedPet();",atomic:false});assert.ok(failed.error);assert.ok(failed.error.message.includes("Could not save"));
 }
});

test("saved companion states match native JavaScriptCore across families and appearances",async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL("parity/companion-trees.json",import.meta.url),"utf8"));
 const prelude=fs.readFileSync(new URL("parity/prelude.js",import.meta.url),"utf8");
 assert.equal(Object.keys(fixture.trees).length,96);
 for(const name of Object.keys(kinds))for(const variant of ["empty","today","older"])for(const dark of [false,true])for(const family of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]){
  const files=readPackageDirectory(fileURLToPath(new URL(name+"/",root))),raw=fixture.states[`${name}/${variant}`],kind=kinds[name];
  const prefix=`\n$device.isdarkmode=()=>${dark};$storage={getString:key=>key==='${kind}.v1'?${JSON.stringify(raw)}:''};\n`;
  const result=await executePackageInNode({files,prelude:prelude+prefix,timeZone:fixture.timeZone,environments:{"widget-size":family,"widget-param":"","timeline-date":"2026-01-01T12:00:00Z","timeline-is-projection":"false"}});
  assert.equal(result.error,null,result.error?.message);assert.equal(result.tree,fixture.trees[`${name}/${variant}/${family}/${dark?"dark":"light"}`]);
 }
});

test("future timeline dates update care status without recording or resetting anything",async()=>{
 for(const name of Object.keys(kinds)){
  const first=await run(name,{actions:name==="Plant Care"?"waterPlant();":"feedPet();playPet();restPet();",inspect:true});
  const storage={[kinds[name]+".v1"]:first.data.raw};
  const next=await run(name,{storage,timeline:"2026-03-11T12:00:00-07:00",projection:true});
  assert.equal(next.error,null,next.error?.message);assert.ok(next.tree.includes(name==="Plant Care"?"Care due":"Ready to reconnect"));
  const inspected=await run(name,{storage,timeline:"2026-03-11T12:00:00-07:00",projection:true,inspect:true});assert.equal(inspected.data.raw,first.data.raw);
  const attempted=await run(name,{storage,timeline:"2026-03-11T12:00:00-07:00",projection:true,actions:name==="Plant Care"?"waterPlant();":"feedPet();"});assert.ok(attempted.error);assert.ok(attempted.error.message.includes("Could not save"));
 }
});
