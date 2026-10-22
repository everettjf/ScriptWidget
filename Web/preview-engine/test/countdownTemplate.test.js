import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { executePackageInNode } from "../src/node.js";
const root = new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Countdown/", import.meta.url);
const filesFor = () => Object.fromEntries(["main.jsx", "widget.json", "lib/countdown.js"].map(path => [path, fs.readFileSync(new URL(path, root), "utf8")]));
async function run(parameter, {now="2026-03-08T12:00:00-07:00", timeZone="America/Los_Angeles", size="medium", storage={}, inspect=true}={}) {
  const files = filesFor();
  if (inspect) files["main.jsx"] = 'const $testRender=$render; $render=()=>{};\n' + files["main.jsx"] + '\n$testRender(<text>{JSON.stringify(moment)}</text>);';
  return executePackageInNode({files, environments:{"widget-size":size,"widget-param":parameter,"timeline-date":now}, fixtures:{storage}, timeZone});
}
function read(result) { assert.equal(result.error,null); return JSON.parse(JSON.parse(result.tree).children.join("")); }
const saved = values => ({"recordTemplate.config.v1": JSON.stringify({version:1,kind:"countdown",values})});
const configuration = {title:"My trip", targetDate:"2026-03-09", repeatYearly:false, accent:"blue"};

test("countdown uses calendar days across spring and fall DST changes", async () => {
  assert.equal(read(await run("2026-03-09 Trip")).number,"1");
  assert.equal(read(await run("2026-11-02 Trip", {now:"2026-11-01T00:30:00-07:00"})).number,"1");
  assert.equal(read(await run("2026-03-08 Trip")).summary,"Today");
  assert.equal(read(await run("2026-03-07 Trip")).summary,"1 day since");
});

test("date-only parameters remain the chosen day in negative and positive time zones", async () => {
  for (const [timeZone,now] of [["America/Los_Angeles","2026-07-01T23:30:00-07:00"],["Pacific/Auckland","2026-07-01T23:30:00+12:00"]]) {
    const value=read(await run("2026-07-02 Holiday",{timeZone,now}));
    assert.equal(value.date,"2026-07-02");assert.equal(value.number,"1");
  }
});

test("saved defaults survive rendering; parameters override without saving", async () => {
  const storage=saved(configuration);
  assert.equal(read(await run("",{storage})).title,"My trip");
  const custom=read(await run('{"title":"Birthday","accent":"rose"}',{storage}));
  assert.equal(custom.title,"Birthday");assert.equal(custom.date,"2026-03-09");assert.equal(custom.accent,"rose");
  assert.equal(JSON.parse(storage["recordTemplate.config.v1"]).values.title,"My trip");
  const empty=read(await run(""));assert.equal(empty.configured,false);assert.equal(empty.number,"—");
});

test("annual countdown keeps today and skips invalid leap-year occurrences", async () => {
  const storage=saved({...configuration,targetDate:"2024-02-29",repeatYearly:true});
  assert.equal(read(await run("",{storage})).date,"2028-02-29");
  const today=read(await run("",{storage,now:"2028-02-29T20:00:00-08:00"}));
  assert.equal(today.date,"2028-02-29");assert.equal(today.summary,"Today");
  assert.equal(read(await run("",{storage,now:"2028-03-01T00:01:00-08:00"})).date,"2032-02-29");
});

test("invalid dates, times, settings and corrupt saved values fail visibly", async () => {
  for (const parameter of ["2027-02-29 Nope","2026-04-31 Nope","2026-01-01T25:00:00 Nope","2026-03-08T02:30:00 Gap",'{"targetDate":"2026-02-30"}','{"repeatYearly":1}','{"accent":"red"}','{"unknown":true}']) {
    assert.ok((await run(parameter)).error,parameter);
  }
  assert.ok((await run("",{storage:{"recordTemplate.config.v1":"broken"}})).error);
});

test("legacy local-time parameters retain countdown and count-up behavior", async () => {
  const upcoming=read(await run("2026-03-08T13:30:00 Flight"));
  assert.equal(upcoming.number,"1h 30m");assert.equal(upcoming.unit,"until the moment");
  const past=read(await run("2026-03-08T11:30:00 Flight"));assert.equal(past.number,"30m");assert.equal(past.unit,"since the moment");
});

test("every declared family renders offline in light and dark appearances", async () => {
  for (const size of ["small","medium","large","extraLarge","extraLargePortrait","accessoryCircular","accessoryRectangular","accessoryInline"]) {
    for (const appearance of ["light","dark"]) {
      const result=await executePackageInNode({files:filesFor(),environments:{"widget-size":size,"widget-param":"2027-07-12 Summer trip"},preview:{appearance}});
      assert.equal(result.error,null,`${size}/${appearance}`);assert.ok(result.tree);
    }
  }
});

test("fixed-date countdown trees match actual native output for every family", async () => {
  const fixture=JSON.parse(fs.readFileSync(new URL("./parity/countdown-trees.json", import.meta.url),"utf8"));
  for (const [size,expected] of Object.entries(fixture.trees)) {
    const result=await run("2026-03-09 Trip",{now:"2026-03-08T12:00:00",timeZone:fixture.timeZone,size,inspect:false});
    assert.equal(result.error,null,size);assert.equal(result.tree,expected,size);
  }
});
