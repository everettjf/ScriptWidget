import assert from "node:assert/strict";
import test from "node:test";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { decodeManifest, newManifest } from "../../preview-engine/src/package/index.js";
import { defaultFixtures, parseMocks, permissionScenario } from "../src/mockData.ts";
import type { WidgetManifest } from "../../preview-engine/src/types.js";

const manifest: WidgetManifest = { ...newManifest("Reminders"), permissions: ["reminders"] };
const execute = (source: string, declared = true, fixtures = parseMocks(defaultFixtures)) => executePackageInNode({ files: { "main.jsx": source }, manifest: declared ? manifest : { ...manifest, permissions: [] }, fixtures });
const output = (tree: string) => JSON.parse(JSON.parse(tree).children[0]);

test("reminders declaration round-trips but unknown permissions still fail closed", () => {
  assert.equal(decodeManifest(JSON.stringify(manifest)).error, undefined);
  assert.match(decodeManifest(JSON.stringify({ ...manifest, permissions: ["remindersWrite"] })).error!, /unknown permission/);
});

test("best-state reminders mocks cannot bypass package permission", async () => {
  const result = await execute(`
    let denied = 0;
    for (const call of [() => $reminders.items(), () => $reminders.lists(), () => $reminders.requestAuthorization()]) {
      try { await call(); } catch(error) { if(String(error).includes('[permission_denied]')) denied++; }
    }
    $render(<text>{JSON.stringify({status: $reminders.authorizationStatus(), denied})}</text>);
  `, false);
  assert.equal(result.error, null);
  assert.deepEqual(output(result.tree!), { status: "undeclared", denied: 3 });
});

test("reminder queries reject invalid ranges, options and identifier budgets before returning mocks", async () => {
  const cases = [
    { unknown: true }, { limit: true }, { limit: 0 }, { limit: 51 }, { limit: 1.5 },
    { maxAgeSeconds: -1 }, { maxAgeSeconds: true }, { listIDs: [] }, { listIDs: ["same", "same"] },
    { listIDs: [1] }, { listIDs: ["日".repeat(86)] }, { listIDs: Array.from({ length: 17 }, (_, index) => String(index)) },
    { start: "bad" }, { start: "2026-01-01" }, { start: 123 },
    { start: "2026-01-02T00:00:00Z", end: "2026-01-01T00:00:00Z" },
    { start: "2026-01-01T00:00:00Z", end: "2026-03-01T00:00:00Z" },
  ];
  const result = await execute(`
    let invalid = 0;
    for (const options of ${JSON.stringify(cases)}) {
      try { await $reminders.items(options); } catch(error) { if (String(error).includes('[invalid_options]')) invalid++; }
    }
    $render(<text>{JSON.stringify({invalid})}</text>);
  `);
  assert.equal(result.error, null);
  assert.equal(output(result.tree!).invalid, cases.length);
});

test("reminder query budget is shared across read methods and resets per execution", async () => {
  const source = `
    let allowed = 0, denied = 0;
    for(let index = 0; index < 10; index++) {
      try { if(index % 2) await $reminders.items(); else await $reminders.lists(); allowed++; }
      catch(error) { if(String(error).includes('[query_limit]')) denied++; }
    }
    $render(<text>{JSON.stringify({allowed, denied})}</text>);
  `;
  for (let run = 0; run < 2; run++) {
    const result = await execute(source);
    assert.equal(result.error, null);
    assert.deepEqual(output(result.tree!), { allowed: 8, denied: 2 });
  }
});

test("reminders denial and unavailable scenarios return no event data", async () => {
  for (const scenario of ["denied", "unavailable"] as const) {
    const result = await execute(`
      let message; try { await $reminders.items(); } catch(error) { message = String(error); }
      $render(<text>{JSON.stringify({available: $reminders.isAvailable(), authorized: await $reminders.requestAuthorization(), status: $reminders.authorizationStatus(), message})}</text>);
    `, true, parseMocks(permissionScenario(defaultFixtures, "reminders", scenario)));
    assert.equal(result.error, null);
    const value = output(result.tree!);
    assert.equal(value.available, scenario === "denied");
    assert.equal(value.authorized, false);
    assert.equal(value.status, scenario);
    assert.match(value.message, scenario === "denied" ? /permission_denied/ : /unavailable/);
  }
});

test("reminder list selection constrains response overrides, metadata and explicit queries", async () => {
  const fixtures = parseMocks(defaultFixtures);
  const api = fixtures.api as Record<string, {value: any}>;
  api["$reminders.lists"]!.value = [{id:"sample.reminders",title:"Personal"},{id:"sample.work",title:"Private Work"}];
  const event = api["$reminders.items"]!.value.items[0];
  api["$reminders.items"]!.value.items = [event,{...event,id:"private",listID:"sample.work",title:"private-event"}];
  fixtures.remindersSelection = ["sample.reminders"];
  const result = await execute(`
    const sources=await $reminders.lists(),items=await $reminders.items();
    let blocked=false;try{await $reminders.items({listIDs:['sample.work']});}catch(e){blocked=String(e).includes('invalid_options');}
    $render(<text>{JSON.stringify({sources,items,blocked})}</text>);
  `, true, fixtures);
  assert.equal(result.error,null);
  const value=output(result.tree!);
  assert.deepEqual(value.sources,[{id:"sample.reminders",title:"Personal"}]);
  assert.equal(value.items.items.length,1);assert.equal(value.items.items[0].listID,"sample.reminders");
  assert.equal(value.blocked,true);assert.doesNotMatch(result.tree!,/private-event|Private Work/);
});

test("no selected lists blocks event reads despite healthy success mocks", async () => {
  const fixtures=parseMocks(defaultFixtures);fixtures.remindersSelection=[];
  const result=await execute(`
    const lists=await $reminders.lists();let denied=false;
    try{await $reminders.items();}catch(e){denied=String(e).includes('No Reminder lists');}
    $render(<text>{JSON.stringify({count:lists.length,denied,authorized:await $reminders.requestAuthorization()})}</text>);
  `,true,fixtures);
  assert.equal(result.error,null);assert.deepEqual(output(result.tree!),{count:0,denied:true,authorized:true});
});

test("reminder list selection validation rejects malformed scopes without granting all sources", async () => {
  for(const remindersSelection of [true,"all",{},[""],["a","a"],["日".repeat(86)],Array.from({length:65},(_,i)=>String(i))]) {
    const fixtures={...parseMocks(defaultFixtures),remindersSelection};
    assert.throws(()=>parseMocks(JSON.stringify(fixtures)),/Reminder selection/);
    const result=await execute(`let denied=false;try{await $reminders.items();}catch(e){denied=String(e).includes('permission_denied');}$render(<text>{JSON.stringify({denied})}</text>);`,true,fixtures as any);
    assert.equal(result.error,null);assert.equal(output(result.tree!).denied,true);
  }
});

test("reminder list scope persists through mock editing and explicit all remains the default", async () => {
  const fixtures=parseMocks(defaultFixtures);fixtures.remindersSelection=["sample.reminders"];
  const {addSampleMocks,setResponse}=await import("../src/mockData.ts");
  const edited=setResponse(addSampleMocks(JSON.stringify(fixtures)),"$device.name",{value:"My preview"});
  assert.deepEqual(parseMocks(edited).remindersSelection,["sample.reminders"]);
  for(const remindersSelection of [undefined,null]) {
    const result=await execute("$render(<text>{JSON.stringify((await $reminders.lists()).length)}</text>);",true,{...fixtures,remindersSelection} as any);
    assert.equal(result.error,null);assert.equal(output(result.tree!),1);
  }
});

test("opaque source identifiers remain byte exact rather than Unicode normalized",async()=>{
  const fixtures=parseMocks(defaultFixtures),selected="caf\u00e9",outside="cafe\u0301";
  const api=fixtures.api as Record<string,{value:any}>;
  api["$reminders.lists"]!.value=[{id:selected,title:"Personal"},{id:outside,title:"private-source"}];
  const event=api["$reminders.items"]!.value.items[0];
  api["$reminders.items"]!.value.items=[{...event,listID:selected},{...event,id:"outside",listID:outside,title:"private-event"}];
  fixtures.remindersSelection=[selected];
  const result=await execute("$render(<text>{JSON.stringify({sources:await $reminders.lists(),items:await $reminders.items()})}</text>);",true,fixtures);
  assert.equal(result.error,null);assert.doesNotMatch(result.tree!,/private-source|private-event/);
  assert.equal(output(result.tree!).items.items.length,1);
});


test("reminder queries filter due/completion windows and distinguish undated and all-day items", async () => {
  const fixtures = parseMocks(defaultFixtures), api = fixtures.api as Record<string, {value:any}>;
  const base = api["$reminders.items"]!.value.items[0];
  api["$reminders.items"]!.value.items = [
    {...base,id:"timed",due:"2026-02-03T12:00:00Z"},
    {...base,id:"outside",due:"2026-02-05T12:00:00Z"},
    {...base,id:"undated",due:null,hasTime:false},
    {...base,id:"floating",due:"2026-02-03",hasTime:false},
    {...base,id:"invalid-day",due:"2026-02-30",hasTime:false},
    {...base,id:"done",due:null,hasTime:false,completed:true,completedAt:"2026-02-03T13:00:00Z"},
    {...base,id:"unplaced",completed:true,completedAt:null},
  ];
  const result = await execute(`
    const options={start:'2026-02-03T00:00:00Z',end:'2026-02-04T23:00:00Z'};
    const pending=await $reminders.items(options),done=await $reminders.items({...options,completed:true});
    let invalid=0;for(const completed of [1,'true',null]) {try{await $reminders.items({completed});}catch(e){if(String(e).includes('invalid_options'))invalid++;}}
    $render(<text>{JSON.stringify({pending:pending.items.map(i=>i.id),done:done.items.map(i=>i.id),invalid})}</text>);
  `,true,fixtures);
  assert.equal(result.error,null);
  assert.deepEqual(output(result.tree!),{pending:["timed","floating"],done:["done"],invalid:3});
});

test("reminder reads share the eight-query budget with Calendar",async()=>{
  const result=await executePackageInNode({files:{"main.jsx":`let count=0;for(let i=0;i<8;i++)await $calendar.calendars();try{await $reminders.lists();}catch(e){if(String(e).includes('query_limit'))count++;}$render(<text>{JSON.stringify(count)}</text>);`},manifest:{...manifest,permissions:["calendar","reminders"]},fixtures:parseMocks(defaultFixtures)});
  assert.equal(result.error,null);assert.equal(output(result.tree!),1);
});

test("bundled reminder template renders sample, empty, denied and no-list states in every family",async()=>{
  const {readFile}=await import("node:fs/promises");
  const source=await readFile(new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Reminders Agenda/main.jsx",import.meta.url),"utf8");
  for(const mode of ["granted","empty","denied","selection"] as const) {
    const fixtures=parseMocks(permissionScenario(defaultFixtures,"reminders",mode==="selection"?"granted":mode));
    if(mode==="selection")fixtures.remindersSelection=[];
    for(const family of ["small","medium","large","extraLarge","extraLargePortrait","accessoryCircular","accessoryRectangular","accessoryInline"] as const) {
      const result=await executePackageInNode({files:{"main.jsx":source},manifest,fixtures,environments:{"widget-size":family,"widget-param":""}});
      assert.equal(result.error,null,`${mode} ${family}`);assert.ok(result.tree);
      if(mode==="granted"&&family!=="accessoryCircular")assert.match(result.tree!,/Read a chapter/);
      if(mode==="selection") {assert.match(result.tree!,/Choose|Check|Review list access/);assert.doesNotMatch(result.tree!,/Nothing due today|No reminders due today|0 items/);}
      if(mode==="denied")assert.doesNotMatch(result.tree!,/Read a chapter/);
    }
  }
});
