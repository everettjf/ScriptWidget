import assert from "node:assert/strict";
import test from "node:test";
import { buildTimelinePlan, validTimelineSchedule } from "../src/timeline.js";
import { decodeManifest, newManifest, validateManifest } from "../src/package/index.js";
import { executePackageInNode } from "../src/node.js";
const plan = (dailyTimes, now, timeZone = "UTC") => buildTimelinePlan({ dailyTimes, timeZone }, new Date(now), new Date(new Date(now).getTime() + 86_400_000));

test("timeline always starts now and retains the configured reload for legacy packages", () => {
  const now = new Date("2026-01-01T05:00:00Z");
  const legacy = buildTimelinePlan(null, now, new Date("2026-01-01T06:00:00Z"), "UTC");
  assert.equal(legacy.entries.length, 1);
  assert.equal(legacy.entries[0].date, now.toISOString());
  assert.equal(legacy.entries[0].environments["timeline-is-projection"], "false");
  assert.equal(legacy.reloadAfter, "2026-01-01T06:00:00.000Z");
  const result = plan(["06:00", "12:00", "18:00", "22:00"], now.toISOString());
  assert.deepEqual(result.entries.map((entry) => entry.slot), [3, 0, 1, 2, 3]);
  assert.equal(result.entries.length, 5);
  assert.equal(result.entries[1].date, "2026-01-01T06:00:00.000Z");
});

test("timeline handles year boundaries, device zone and non-hour offsets", () => {
  assert.equal(plan(["00:00", "12:00"], "2026-12-31T23:59:00Z").entries[1].date, "2027-01-01T00:00:00.000Z");
  assert.equal(plan(["06:00", "18:00"], "2026-01-01T00:00:00Z", "Asia/Kathmandu").entries[1].date, "2026-01-01T00:15:00.000Z");
  assert.equal(buildTimelinePlan({dailyTimes:["06:00"]}, new Date("2026-01-01T00:00:00Z"), new Date("2026-01-02T00:00:00Z"), "Asia/Tokyo").entries[1].date, "2026-01-01T21:00:00.000Z");
});

test("DST gaps collapse to the next valid time and repeated hours use their first occurrence", () => {
  const gap = plan(["02:00", "02:30", "06:00"], "2026-03-08T09:00:00Z", "America/Los_Angeles");
  assert.equal(gap.entries[1].date, "2026-03-08T10:00:00.000Z");
  assert.equal(gap.entries[1].slot, 1);
  assert.equal(new Set(gap.entries.map((entry) => entry.date)).size, gap.entries.length);
  const repeated = plan(["01:30", "02:30"], "2026-11-01T08:00:00Z", "America/Los_Angeles");
  assert.equal(repeated.entries[1].date, "2026-11-01T08:30:00.000Z");
  assert.ok(!repeated.entries.some((entry) => entry.date === "2026-11-01T09:30:00.000Z"));
  assert.equal(plan(["01:30", "02:30"], "2026-11-01T09:10:00Z", "America/Los_Angeles").entries[0].slot, 0);
  const capacity = plan(["06:00", "06:10", "06:20", "06:30"], "2026-03-07T13:59:00Z", "America/Los_Angeles");
  assert.equal(capacity.entries.length, 5);
  assert.ok(capacity.reloadAfter <= capacity.entries.at(-1).date);
});

test("malformed timeline manifests fail closed, including nested unknown fields", () => {
  for (const schedule of [false, [], {}, {dailyTimes:[]}, {dailyTimes:["25:00"]}, {dailyTimes:["6:00"]}, {dailyTimes:["12:00","06:00"]}, {dailyTimes:["06:00","06:00"]}, {dailyTimes:["00:00","01:00","02:00","03:00","04:00"]}, {dailyTimes:["06:00"], timeZone:"Earth/Unknown"}, {dailyTimes:["06:00"], timeZone:"america/los_angeles"}, {dailyTimes:["06:00"],timeZone:"US/Pacific"}, {dailyTimes:["06:00"], execute:"untrusted"}]) {
    assert.equal(validTimelineSchedule(schedule), false);
    const decoded = decodeManifest(JSON.stringify({...newManifest("Schedule"),timeline:schedule}));
    assert.ok(decoded.error || !validateManifest(decoded.manifest,["main.jsx"]).valid);
  }
  assert.equal(decodeManifest(JSON.stringify({...newManifest("Schedule"),timeline:{dailyTimes:["06:00","22:00"],timeZone:"UTC"}})).error, undefined);
});

test("projected renders cannot mutate records or issue network/service requests even after replacing getenv", async () => {
  const result = await executePackageInNode({files:{"main.jsx":`
    $getenv = () => 'false';
    const writes = [$storage.setString('day','lost'),$storage.setJSON('object',{lost:true}),$storage.compareAndSetString('day','saved','lost'),$storage.compareAndSetJSON('object',{keep:true},{lost:true}),$storage.remove('day'),$storage.clear()];
    let blocked = 0;
    for(const call of [() => fetch('https://example.com'), () => $http.post('https://example.com',{}), () => $dataSource.request('example.plugin','read',{}), () => $health.stepCountToday()]) {
      try { await call(); } catch(error) { if(String(error).includes('[timeline_read_only]')) blocked++; }
    }
    $render(<text>{JSON.stringify({writes,blocked,day:$storage.getString('day'),object:$storage.getJSON('object')})}</text>);
  `}, environments:{"timeline-is-projection":"true"},fixtures:{storage:{day:"saved",object:{keep:true}}}});
  assert.equal(result.error,null);
  assert.deepEqual(JSON.parse(JSON.parse(result.tree).children[0]),{writes:[false,false,false,false,false,false],blocked:4,day:"saved",object:{keep:true}});
});

test("all scheduled theme phases and sizes match fixed-date native canonical trees", async () => {
  const fs = await import("node:fs");
  const template = new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Day Rhythm/", import.meta.url);
  const files = Object.fromEntries(["main.jsx", "widget.json"].map((name) => [name, fs.readFileSync(new URL(name, template), "utf8")]));
  const reference = JSON.parse(fs.readFileSync(new URL("parity/timeline-trees.json", import.meta.url), "utf8"));
  assert.equal(Object.keys(reference.entries).length,32);
  for(const [key, expected] of Object.entries(reference.entries)) {
    const [slot,family] = key.split("@");
    const result = await executePackageInNode({files,environments:{"widget-size":family,"timeline-date":"2026-01-01T12:00:00.000Z","timeline-slot":slot,"timeline-is-projection":"true"}});
    assert.equal(result.error,null,key);
    assert.equal(result.tree,expected,key);
  }
});


test("invalid typed schedules fail package preflight before script side effects", async () => {
  const manifest = {...newManifest("Invalid schedule"),timeline:{dailyTimes:["25:00"]}};
  const result = await executePackageInNode({files:{"widget.json":JSON.stringify(manifest),"main.jsx":"$storage.setString('bad','executed'); $render(<text>executed</text>);"}});
  assert.equal(result.tree,null);
  assert.match(result.error.message,/package:invalid_timeline/);
});
