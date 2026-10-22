import assert from "node:assert/strict";
import test from "node:test";
import { executePackageInNode } from "../src/node.js";
const run = (source, storage = {}) => executePackageInNode({ files: { "main.jsx": source }, fixtures: { storage } });
const value = (result) => { assert.equal(result.error, null); return JSON.parse(JSON.parse(result.tree).children[0]); };

test("compare-and-set strings rejects stale values and wrong types", async () => {
  const result = await run(`
    const first = $storage.compareAndSetString('count', '', '1');
    const stale = $storage.compareAndSetString('count', '', '2');
    const next = $storage.compareAndSetString('count', '1', '2');
    $storage.setJSON('object', {n: 1});
    const typeConflict = $storage.compareAndSetString('object', '', 'lost');
    $render(<text>{JSON.stringify({first,stale,next,typeConflict,count:$storage.getString('count'), object:$storage.getJSON('object')})}</text>);
  `);
  assert.deepEqual(value(result), { first: true, stale: false, next: true, typeConflict: false, count: "2", object: { n: 1 } });
});

test("JSON compare-and-set compares properties semantically and preserves types", async () => {
  const result = await run(`
    const inserted = $storage.compareAndSetJSON('state', {}, {b:2,a:1});
    const updated = $storage.compareAndSetJSON('state', {a:1,b:2}, {a:2});
    const stale = $storage.compareAndSetJSON('state', {a:1,b:2}, {a:3});
    $storage.setString('string', '{}');
    const typed = $storage.compareAndSetJSON('string', {}, {lost:true});
    $render(<text>{JSON.stringify({inserted,updated,stale,typed,state:$storage.getJSON('state'),string:$storage.getString('string')})}</text>);
  `);
  assert.deepEqual(value(result), { inserted: true, updated: true, stale: false, typed: false, state: { a: 2 }, string: "{}" });
});

test("all storage writes enforce UTF-8 and JSON byte budgets without mutating failures", async () => {
  const result = await run(`
    $storage.setString('keep','original');
    const key = '日'.repeat(86), huge = '日'.repeat(90000);
    const rejected = [$storage.setString(key,'v'),$storage.compareAndSetString(key,'','v'),$storage.remove(key),
      $storage.setString('keep',huge),$storage.compareAndSetString('keep','original',huge),
      $storage.setJSON('json',{huge}),$storage.compareAndSetJSON('json',{}, {huge}),$storage.setJSON('nan',{n:NaN})];
    $render(<text>{JSON.stringify({rejected,keep:$storage.getString('keep'),json:$storage.getJSON('json')})}</text>);
  `);
  assert.deepEqual(value(result), { rejected: Array(8).fill(false), keep: "original", json: {} });
});

test("storage mocks seed each run; response overrides cannot bypass CAS", async () => {
  const source = `const stale = $storage.compareAndSetString('n','old','lost'); $render(<text>{JSON.stringify({stale,n:$storage.getString('n')})}</text>);`;
  for (let index = 0; index < 2; index++) {
    const result = await executePackageInNode({ files: { "main.jsx": source }, fixtures: { storage: { n: "new" }, api: { "$storage.compareAndSetString": { value: true } } } });
    assert.deepEqual(value(result), { stale: false, n: "new" });
  }
});

test("unavailable atomic storage can be simulated without discarding saved history", async () => {
  const result = await executePackageInNode({ files: { "main.jsx": `
    const string = $storage.compareAndSetString('saved','history','lost');
    const json = $storage.compareAndSetJSON('state',{n:1},{n:2});
    $render(<text>{JSON.stringify({string,json,saved:$storage.getString('saved'),state:$storage.getJSON('state')})}</text>);
  ` }, fixtures: { storage: { saved: "history", state: { n: 1 } }, storageAtomicAvailable: false } });
  assert.deepEqual(value(result), { string: false, json: false, saved: "history", state: { n: 1 } });
});
