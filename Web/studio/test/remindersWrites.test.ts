import assert from "node:assert/strict";
import test from "node:test";
import { createHash } from "node:crypto";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { newManifest } from "../../preview-engine/src/package/manifest.js";
import { defaultFixtures, parseMocks } from "../src/mockData.ts";
import type { WidgetManifest } from "../../preview-engine/src/types.js";

const requestID = "550e8400-e29b-41d4-a716-446655440000";
const base = { requestID, listID: "sample.reminders", title: "Read" };
const manifest: WidgetManifest = { ...newManifest("Reminder writes"), permissions: ["reminders", "remindersWrite", "storage"],
  actions: [{ id: "test", title: "Test action", systemImage: "checkmark", function: "perform" }] };
const run = (body: string, fixtures: unknown = parseMocks(defaultFixtures), selected = manifest, environments: Record<string,string> = {}) =>
  executePackageInNode({ files: { "main.jsx": `$render(<text>Entry feedback</text>); async function perform(){${body}}` }, manifest: selected, fixtures, actionID: "test", environments });
const create = `const r=await $reminders.create(${JSON.stringify(base)});$storage.setString('receipt',JSON.stringify(r));`;

test("declared preview actions await async writes and export preview state only", async () => {
  const result = await run(create);
  assert.equal(result.error, null); assert.match(result.tree!, /Action completed/);
  const state = result.mockState!;
  assert.equal(state.remindersState.items.length, 2);
  assert.deepEqual(JSON.parse(state.storage.receipt as string), { id: `mock.reminder.${requestID}`, listID: base.listID, status: "applied", replayed: false });
  assert.equal(state.remindersState.receipts.length, 1);
  assert.equal(state.remindersState.receipts[0]!.fingerprint, createHash("sha256").update(JSON.stringify({kind:"create",listID:base.listID,priority:0,title:"Read"})).digest("hex"));
});

test("request receipts survive worker restarts and reject changed payloads", async () => {
  const first = await run(create); assert.equal(first.error,null);
  const fixtures = { ...parseMocks(defaultFixtures), ...first.mockState };
  const replay = await run(create, fixtures);
  assert.equal(replay.error,null);assert.equal(replay.mockState!.remindersState.items.length,2);
  assert.equal(JSON.parse(replay.mockState!.storage.receipt as string).replayed,true);
  const conflict = await run(create.replace('"Read"','"Changed"'),fixtures);
  assert.match(conflict.error!.message,/request_conflict/);
  assert.equal(conflict.mockState!.remindersState.items.length,2);
});

test("creation, update and desired completion mutate the modeled items", async () => {
  const first = await run(create);assert.equal(first.error,null);
  const id=`mock.reminder.${requestID}`;
  const change={...base,requestID:"550e8400-e29b-41d4-a716-446655440001",id,title:"Updated",due:null,priority:2};
  const update=await run(`await $reminders.update(${JSON.stringify(change)});`,{...parseMocks(defaultFixtures),...first.mockState});assert.equal(update.error,null);
  const done=await run(`await $reminders.setCompleted(${JSON.stringify({requestID:"550e8400-e29b-41d4-a716-446655440002",id,listID:base.listID,completed:true})});`,{...parseMocks(defaultFixtures),...update.mockState});assert.equal(done.error,null);
  const item=done.mockState!.remindersState.items.find((row)=>row.id===id)!;
  assert.equal(item.title,"Updated");assert.equal(item.due,null);assert.equal(item.priority,2);assert.equal(item.completed,true);assert.equal(typeof item.completedAt,"string");
});

test("mock response errors do not mutate items or reserve receipts", async () => {
  const fixtures=parseMocks(defaultFixtures);(fixtures.api as any)["$reminders.create"]={error:"[write_failed] unavailable"};
  const result=await run(create,fixtures);
  assert.match(result.error!.message,/write_failed/);assert.equal(result.mockState!.remindersState.items.length,1);assert.equal(result.mockState!.remindersState.receipts.length,0);
});

test("uncertain commit remains visible and is never blindly repeated", async () => {
  const first=await run(create,{...parseMocks(defaultFixtures),remindersCommitUncertain:true});
  assert.match(first.error!.message,/outcome_unknown/);assert.equal(first.mockState!.remindersState.items.length,2);
  const second=await run(create,{...parseMocks(defaultFixtures),...first.mockState});
  assert.match(second.error!.message,/outcome_unknown/);assert.equal(second.mockState!.remindersState.items.length,2);
});

test("write permission, native-style action authority and source scope cannot be mocked away", async () => {
  for(const permissions of [[],["reminders"],["remindersWrite"]] as WidgetManifest['permissions'][]) {
    const result=await run(create,parseMocks(defaultFixtures),{...manifest,permissions});assert.match(result.error!.message,/permission_denied/);
  }
  for(const remindersSelection of [[],["other"]]) {
    const result=await run(create,{...parseMocks(defaultFixtures),remindersSelection});assert.match(result.error!.message,/permission_denied/);
  }
  const ordinary=await executePackageInNode({files:{"main.jsx":`let e;try{await $reminders.create(${JSON.stringify(base)});}catch(error){e=String(error);}$render(<text>{e}</text>);`},manifest,fixtures:parseMocks(defaultFixtures),environments:{"widget-size":"action","action-id":"test"}});
  assert.equal(ordinary.error,null);assert.match(ordinary.tree!,/permission_denied/);assert.equal(ordinary.mockState,undefined);
  const projection=await run(create,parseMocks(defaultFixtures),manifest,{"timeline-is-projection":"true"});assert.match(projection.error!.message,/permission_denied/);
  const activity=await run(create,parseMocks(defaultFixtures),manifest,{"widget-size":"live-activity"});assert.match(activity.error!.message,/permission_denied/);
});

test("invalid declarations are rejected before action code runs",async()=>{
  const result=await executePackageInNode({files:{"main.jsx":"throw new Error('must not run');"},manifest,actionID:"not-declared"});
  assert.match(result.error!.message,/action:not_declared/);assert.doesNotMatch(result.error!.message,/must not run/);
});

test("mutations validate fields, precise types, dates and UUIDs",async()=>{
  for(const change of [{title:" "},{title:"x\ny"},{priority:true},{priority:10},{due:"2026-02-29"},{due:"2026-02-29T12:00:00Z"},{due:"2026-03-01T24:00:00Z"},{due:"bad"},{requestID:"bad"},{completed:true},{id:"not-for-create"}]) {
    const result=await run(`await $reminders.create(${JSON.stringify({...base,...change})});`);assert.match(result.error!.message,/invalid_options/);
    assert.equal(result.mockState!.remindersState.receipts.length,0);
  }
});

test("failed action preserves earlier successful mock side effects",async()=>{
  const result=await run(create+"throw new Error('later failure');");assert.match(result.error!.message,/later failure/);
  assert.equal(result.mockState!.remindersState.items.length,2);assert.equal(result.mockState!.remindersState.receipts.length,1);
});

test("corrupt replay history fails closed instead of resetting",async()=>{
  const result=await run(create,{...parseMocks(defaultFixtures),remindersState:{formatVersion:99,items:[],receipts:[]}});
  assert.match(result.error!.message,/write_history_invalid/);
});
