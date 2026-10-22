import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { executePackageInNode } from "../src/node.js";
const base = new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/", import.meta.url);
const names = ["Hydration Goal", "Mood Check-in", "Packing Checklist", "Habit Streak Tracker"];
const keys = ["hydration.v1", "mood.v1", "checklist.v1", "habitStreak.v2"];
const actions = ["addGlass", "moodOne", "toggleOne", "checkIn"];
const filesFor = (name) => Object.fromEntries(["main.jsx", "widget.json", "lib/records.js"].map((path) => [path, fs.readFileSync(new URL(`${name}/${path}`, base), "utf8")]));
const clock = (day = 8, month = 3, year = 2026) => `const OriginalDate=Date; Date=class extends OriginalDate { constructor(...args) { super(...(args.length ? args : [${year},${month - 1},${day},12])); } };`;
async function run(name, code = "", {storage = {}, parameter = "", day = 8, month = 3, year = 2026, size = "function", atomic = true} = {}) {
  const files = filesFor(name);
  files["main.jsx"] += `\n${code.replaceAll("$render", "$testRender")}`;
  return executePackageInNode({files, prelude:clock(day,month,year)+"const $testRender=$render; $render=()=>{};", environments:{"widget-size":size,"widget-param":parameter}, fixtures:{storage,storageAtomicAvailable:atomic},timeZone:"America/Los_Angeles"});
}
const capture = (key) => `$render(<text>{JSON.stringify({raw:$storage.getString('${key}')})}</text>);`;
const read = (result) => { assert.equal(result.error,null); return JSON.parse(JSON.parse(result.tree).children.join("")); };
const saved = (result) => JSON.parse(read(result).raw);

test("record helpers stay identical, and rendering never creates fake records", async () => {
  const helpers = names.map((name) => filesFor(name)["lib/records.js"]);
  assert.ok(helpers.every((helper) => helper === helpers[0]));
  for (const [index,name] of names.entries()) {
    const key = keys[index];
    const result = await run(name,capture(key),{size:"large"});
    assert.equal(read(result).raw,"");
  }
});

test("hydration persists measured volume, supports reset/undo and keeps prior days", async () => {
  let state = saved(await run(names[0],`addGlass();addGlass();${capture("hydration.v1")}`,{day:7,parameter:'{"goal":8,"glassML":200}'}));
  assert.equal(state.entries[0].value,400);
  const storage = {"hydration.v1":JSON.stringify(state)};
  state = saved(await run(names[0],`addGlass();resetToday();undoRecord();${capture("hydration.v1")}`,{storage,parameter:'{"goal":10,"glassML":300}'}));
  assert.deepEqual(state.entries,[{date:"2026-03-07",value:400},{date:"2026-03-08",value:300}]);
  assert.equal(state.undo,null);
  assert.equal(state.revision,5);
});

test("mood reselection is idempotent and undo cannot repeat or toggle old snapshots", async () => {
  const state = saved(await run(names[1],`moodFour();moodFour();moodTwo();undoRecord();undoRecord();${capture("mood.v1")}`));
  assert.deepEqual(state.entries,[{date:"2026-03-08",value:4}]);
  assert.equal(state.revision,3);
  assert.equal(state.undo,null);
});

test("checklist uses configured labels and preserves checks across reordering", async () => {
  let state = saved(await run(names[2],`toggleOne();toggleThree();${capture("checklist.v1")}`,{parameter:"Tickets,Water,Keys"}));
  assert.deepEqual(state.entries[0].value,["Keys","Tickets"]);
  state = saved(await run(names[2],`toggleTwo();${capture("checklist.v1")}`,{parameter:"Water,Keys,Tickets",storage:{"checklist.v1":JSON.stringify(state)}}));
  assert.deepEqual(state.entries[0].value,["Tickets"]);
});

test("corruption and unavailable atomic storage preserve existing records", async () => {
  for (const [index,name] of names.entries()) {
    const key = keys[index], action = actions[index];
    for (const raw of ["broken",JSON.stringify({version:2,entries:[]})]) {
      const result=await run(name,`${action}();`,{storage:{[key]:raw}});
      assert.match(result.error.message,/Saved history is invalid/);
    }
    const result=await run(name,`try{${action}();}catch(error){$render(<text>{error.message+'|'+$storage.getString('${key}')}</text>);}`,{atomic:false});
    assert.equal(result.error,null);
    assert.match(JSON.parse(result.tree).children.join(""),/Could not save.*\|$/);
  }
});

test("CAS conflicts reread records and retain another writer's update", async () => {
  const name=names[0],files=filesFor(name);
  const prefix=`const originalCAS=$storage.compareAndSetString;let conflict=true;
  $storage.compareAndSetString=(key,expected,value)=>{if(conflict){conflict=false;const incoming={version:1,revision:1,entries:[{date:'2026-03-07',value:500}],undo:null};$storage.setString(key,JSON.stringify(incoming));return false;}return originalCAS(key,expected,value);};`;
  files["main.jsx"]="const $testRender=$render; $render=()=>{};"+prefix+files["main.jsx"]+`\naddGlass();${capture("hydration.v1").replaceAll("$render", "$testRender")}`;
  const result=await executePackageInNode({files,prelude:clock(),environments:{"widget-size":"function","widget-param":""}});
  assert.deepEqual(saved(result).entries,[{date:"2026-03-07",value:500},{date:"2026-03-08",value:250}]);
});

test("invalid configuration fails visibly rather than replacing saved values", async () => {
  for (const [name,parameter] of [[names[0],'{"glassML":0}'],[names[0],"NaN"],[names[1],'{"intention":5}'],[names[2],"Keys,Keys"],[names[2],"Keys,,Water"]]) {
    const result=await run(name,"",{parameter,size:"medium"});
    assert.ok(result.error,`${name}: ${parameter}`);
  }
});

test("all declared families render offline with both appearances", async () => {
  for (const name of names) {
    for (const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryCircular","accessoryRectangular","accessoryInline"]) {
      for (const appearance of ["light","dark"]) {
        const result=await executePackageInNode({files:filesFor(name),environments:{"widget-size":size,"widget-param":""},preview:{appearance}});
        assert.equal(result.error,null,`${name}/${size}/${appearance}`);
        assert.ok(result.tree);
      }
    }
  }
});

const recordState = (entries, undo = null, revision = 1) => JSON.stringify({version:1,revision,entries,undo});
const dateAt = (offset) => new Date(Date.UTC(2026,2,8+offset)).toISOString().slice(0,10);
const captureFailure = (key, action) => `let failure='';try{${action}();}catch(error){failure=error.message;}$render(<text>{JSON.stringify({failure,raw:$storage.getString('${key}')})}</text>);`;

test("hydration rejects an overflowing glass without truncating the saved measurement", async () => {
  for (const amount of [63900,64000]) {
    const raw=recordState([{date:"2026-03-08",value:amount}]);
    const result=read(await run(names[0],captureFailure(keys[0],"addGlass"),{storage:{[keys[0]]:raw}}));
    assert.match(result.failure,/record limit would be exceeded/);
    assert.equal(result.raw,raw);
  }
});

test("retention keeps the inclusive 366-day window and prunes only after an explicit edit", async () => {
  const entries=Array.from({length:366},(_,i)=>({date:dateAt(-i-1),value:250}));
  const raw=recordState(entries), storage={[keys[0]]:raw};
  assert.equal(read(await run(names[0],capture(keys[0]),{storage,size:"large"})).raw,raw);
  const state=saved(await run(names[0],`addGlass();${capture(keys[0])}`,{storage}));
  assert.equal(state.entries.length,366);
  assert.equal(state.entries[0].date,dateAt(-365));
  assert.equal(state.entries.at(-1).date,dateAt(0));
  assert.equal(state.entries.some((item)=>item.date===dateAt(-366)),false);
});

test("clock rollback cannot discard future records to make room for a new day", async () => {
  const entries=Array.from({length:366},(_,i)=>({date:dateAt(i+1),value:250}));
  const raw=recordState(entries);
  const result=read(await run(names[0],captureFailure(keys[0],"addGlass"),{storage:{[keys[0]]:raw}}));
  assert.match(result.failure,/History is full/);
  assert.equal(result.raw,raw);
});

test("expired undo and exhausted revision counters preserve the complete original state", async () => {
  const raw=recordState([{date:dateAt(0),value:250}],{date:dateAt(-366),value:500});
  const expired=read(await run(names[0],captureFailure(keys[0],"undoRecord"),{storage:{[keys[0]]:raw}}));
  assert.match(expired.failure,/outside the retained history window/);
  assert.equal(expired.raw,raw);
  const exhausted=recordState([{date:dateAt(0),value:250}],null,Number.MAX_SAFE_INTEGER);
  const result=read(await run(names[0],captureFailure(keys[0],"addGlass"),{storage:{[keys[0]]:exhausted}}));
  assert.match(result.failure,/Saved history is invalid/);
  assert.equal(result.raw,exhausted);
});

test("invalid dates, duplicate entries and malformed undo snapshots never get overwritten", async () => {
  const samples=[
    recordState([{date:"2026-02-30",value:250}]),
    recordState([{date:dateAt(0),value:250},{date:dateAt(0),value:500}]),
    recordState([{date:dateAt(0),value:250}],{date:dateAt(0),value:-1}),
    recordState([{date:dateAt(0),value:250,extra:true}]),
    recordState([{date:dateAt(0),value:64001}]),
  ];
  for(const raw of samples) {
    // Install the storage read fixture before loading the template; its initial
    // validation must fail before an action can attempt a write.
    const files=filesFor(names[0]);
    const result=await executePackageInNode({files,fixtures:{storage:{[keys[0]]:raw}}});
    assert.match(result.error.message,/Saved history is invalid/);
  }
});

test("habit migration preserves unverified automatic counters and requires explicit check-in", async () => {
  const old={"habit.lastDate":"2026-03-07","habit.streak":"912"};
  const rendered=await executePackageInNode({files:filesFor(names[3]),fixtures:{storage:old},environments:{"widget-size":"medium","widget-param":"Read"}});
  assert.equal(rendered.error,null);
  assert.match(rendered.tree,/Earlier automatic count: 912/);
  assert.match(rendered.tree,/0 days/);
  const inspect=`$render(<text>{JSON.stringify({raw:$storage.getString('habitStreak.v2'),oldDate:$storage.getString('habit.lastDate'),oldStreak:$storage.getString('habit.streak')})}</text>);`;
  assert.deepEqual(read(await run(names[3],inspect,{storage:old,size:"large"})),{raw:"",oldDate:old["habit.lastDate"],oldStreak:"912"});
  const result=read(await run(names[3],`checkIn();checkIn();resetToday();undoRecord();${inspect}`,{storage:old}));
  assert.equal(result.oldDate,old["habit.lastDate"]);
  assert.equal(result.oldStreak,"912");
  const state=JSON.parse(result.raw);
  assert.deepEqual(state.entries,[{date:dateAt(0),value:1}]);
  assert.equal(state.revision,3);
});

test("habit streak follows local calendar days across DST and resets after a missed day", async () => {
  let state=saved(await run(names[3],`checkIn();${capture(keys[3])}`,{day:7}));
  const inspect=`$render(<text>{JSON.stringify({streak,done})}</text>);`;
  assert.deepEqual(read(await run(names[3],inspect,{day:8,storage:{[keys[3]]:JSON.stringify(state)}})),{streak:1,done:false});
  state=saved(await run(names[3],`checkIn();${capture(keys[3])}`,{day:8,storage:{[keys[3]]:JSON.stringify(state)}}));
  assert.deepEqual(read(await run(names[3],inspect,{day:8,storage:{[keys[3]]:JSON.stringify(state)}})),{streak:2,done:true});
  assert.deepEqual(read(await run(names[3],inspect,{day:10,storage:{[keys[3]]:JSON.stringify(state)}})),{streak:0,done:false});
  state=saved(await run(names[3],`checkIn();${capture(keys[3])}`,{day:31,month:12,year:2025}));
  state=saved(await run(names[3],`checkIn();${capture(keys[3])}`,{day:1,month:1,storage:{[keys[3]]:JSON.stringify(state)}}));
  assert.equal(read(await run(names[3],inspect,{day:1,month:1,storage:{[keys[3]]:JSON.stringify(state)}})).streak,2);
});

test("a full retained habit history reports an honest lower bound instead of inventing older days", async () => {
  const entries=Array.from({length:366},(_,i)=>({date:dateAt(-i),value:1}));
  const raw=recordState(entries);
  const result=read(await run(names[3],`$render(<text>{JSON.stringify({streak,streakLabel,raw:$storage.getString('habitStreak.v2')})}</text>);`,{storage:{[keys[3]]:raw}}));
  assert.equal(result.streak,366);
  assert.equal(result.streakLabel,"366+ days");
  assert.equal(result.raw,raw);
});

const configured = (kind, values) => JSON.stringify({version:1,kind,values});
test("native-managed defaults configure all record templates without changing their history", async () => {
  const cases=[
    [names[0],"hydration",{goal:10,glassML:200},"({target,glassML})",{target:2000,glassML:200}],
    [names[1],"mood",{intention:"Take a pause"},"({intention})",{intention:"Take a pause"}],
    [names[2],"checklist",{items:["Tickets, please","Keys"]},"({items})",{items:["Tickets, please","Keys"]}],
    [names[3],"habitStreak",{title:"阅读"},"({title})",{title:"阅读"}],
    ["Habit Heatmap","habitHeatmap",{readName:"阅读",runName:"Move",meditateName:"Pause"},"({names:habits.map(item=>item.name)})",{names:["阅读","Move","Pause"]}],
  ];
  for(const [name,kind,values,inspect,expected] of cases) {
    const raw=configured(kind,values);
    const result=read(await run(name,`$render(<text>{JSON.stringify(${inspect})}</text>);`,{storage:{"recordTemplate.config.v1":raw}}));
    assert.deepEqual(result,expected,name);
    assert.equal(filesFor(name)["lib/records.js"],filesFor(names[0])["lib/records.js"]);
  }
});

test("instance parameters override defaults while retaining a configured glass size", async () => {
  const storage={"recordTemplate.config.v1":configured("hydration",{goal:12,glassML:300})};
  const result=read(await run(names[0],`addGlass();$render(<text>{JSON.stringify({target,glassML,saved:JSON.parse($storage.getString('hydration.v1')).entries[0].value})}</text>);`,{storage,parameter:'{"goal":5}'}));
  assert.deepEqual(result,{target:1500,glassML:300,saved:300});
  const checklist=read(await run(names[2],`$render(<text>{JSON.stringify({items})}</text>);`,{storage:{"recordTemplate.config.v1":configured("checklist",{items:["Defaults"]})},parameter:"Tickets,Water"}));
  assert.deepEqual(checklist,{items:["Tickets","Water"]});
});

test("malformed saved configuration fails visibly instead of falling back to a plausible default", async () => {
  for(const raw of ["broken",configured("hydration",{goal:true,glassML:250}),configured("hydration",{goal:8,glassML:250,extra:true}),configured("mood",{intention:"wrong kind"})]) {
    const result=await run(names[0],"",{storage:{"recordTemplate.config.v1":raw},size:"medium"});
    assert.match(result.error.message,/Saved template configuration is invalid/);
  }
  const result=await run(names[2],"",{storage:{"recordTemplate.config.v1":configured("checklist",{items:["Keys","Keys"]})},size:"medium"});
  assert.match(result.error.message,/Saved template configuration is invalid/);
});

test("record-template descriptors match their helpers and declared storage permission", () => {
  for(const [name,kind] of [...names.map((name,index)=>[name,["hydration","mood","checklist","habitStreak"][index]]),["Habit Heatmap","habitHeatmap"]]) {
    const descriptor=JSON.parse(fs.readFileSync(new URL(`${name}/record-template.json`,base),"utf8"));
    assert.deepEqual(descriptor,{formatVersion:1,kind});
    const manifest=JSON.parse(filesFor(name)["widget.json"]);
    assert.ok(manifest.permissions.includes("storage"));
    assert.equal(manifest.minimumRuntimeVersion,"1.3");
  }
});
