import assert from "node:assert/strict";
import test from "node:test";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { exportPackage, importPackage } from "../../preview-engine/src/package/index.js";
import { addSampleMocks, defaultFixtures, mockAPIs, parseMocks, permissionScenario, responseFor, setResponse } from "../src/mockData.ts";
import { createProject } from "../src/project.ts";
const execute = (source: string, fixtures = parseMocks(defaultFixtures)) => executePackageInNode({ files: { "main.jsx": source }, fixtures });

test("new projects can read healthy system samples and authorize without setup", async () => {
  const result = await execute(`
    const steps = await $health.stepCountToday();
    const energy = await $health.activeEnergyToday();
    const heart = await $health.heartRateLatest();
    const location = await $location.current();
    $render(<text>{JSON.stringify({ health: $health.isAvailable(), authorized: await $health.requestAuthorization(),
      locationAuthorized: await $location.requestAuthorization(), steps, energy, heart, location,
      battery: $device.battery(), memory: $system.memory() })}</text>);
  `);
  assert.equal(result.error, null);
  const output = JSON.parse(JSON.parse(result.tree!).children[0]);
  assert.equal(output.health, true);
  assert.equal(output.authorized, true);
  assert.equal(output.locationAuthorized, true);
  assert.equal(output.steps.value, 6840);
  assert.equal(output.steps.unit, "count");
  assert.equal(output.energy.unit, "kcal");
  assert.equal(output.heart.unit, "bpm");
  assert.equal(output.location.latitude, 37.3349);
  assert.equal(output.battery.level, 0.8);
  assert.equal(output.memory.physical, 8589934592);
});

test("every listed API returns its configured value with the right sync or async shape", async () => {
  const calls = mockAPIs.filter((api) => api.id !== "$device.isdarkmode").map((api) => `${JSON.stringify(api.id)}: await ${api.id}()`);
  const result = await execute(`$render(<text>{JSON.stringify({${calls.join(",")}})}</text>);`);
  assert.equal(result.error, null);
  const actual = JSON.parse(JSON.parse(result.tree!).children[0]);
  for (const api of mockAPIs.filter((item) => item.id !== "$device.isdarkmode")) assert.deepEqual(actual[api.id], api.value, api.id);
});

test("per-method editing preserves custom rules, false, zero, and legacy data", () => {
  const text = JSON.stringify({ fetch: [{ url: "https://example.com/custom", body: "custom" }], location: { latitude: 0, longitude: 0 }, health: false, custom: { keep: true }, api: { "$device.battery": { value: { level: 0, state: "charging" } } } });
  const added = parseMocks(addSampleMocks(text));
  const location = mockAPIs.find((item) => item.id === "$location.current")!;
  assert.deepEqual(responseFor(added, location).value, { latitude: 0, longitude: 0 });
  assert.deepEqual(added.fetch, JSON.parse(text).fetch);
  assert.deepEqual(added.custom, { keep: true });
  const updated = parseMocks(setResponse(JSON.stringify(added), "$system.brightness", { value: 0 }));
  assert.deepEqual(updated.api && (updated.api as Record<string, unknown>)["$device.battery"], { value: { level: 0, state: "charging" } });
  assert.deepEqual((updated.api as Record<string, unknown>)["$health.requestAuthorization"], { value: false });
  assert.throws(() => setResponse("{broken", "$device.name", { value: "x" }));
});

test("denied and unavailable scenarios update availability, authorization and query failures together", async () => {
  for (const group of ["health", "location"] as const) for (const mode of ["denied", "unavailable"] as const) {
    const method = group === "health" ? "stepCountToday" : "current";
    const result = await execute(`
      let message; try { await $${group}.${method}(); } catch(error) { message = String(error); }
      $render(<text>{JSON.stringify({ available: $${group}.isAvailable(), authorized: await $${group}.requestAuthorization(), message })}</text>);
    `, parseMocks(permissionScenario(defaultFixtures, group, mode)));
    assert.equal(result.error, null);
    const value = JSON.parse(JSON.parse(result.tree!).children[0]);
    assert.equal(value.available, mode === "denied");
    assert.equal(value.authorized, false);
    assert.match(value.message, mode === "denied" ? /permission denied/ : /unavailable/);
  }
});

test("invalid mock documents are diagnosed before execution", () => {
  for (const value of ["null", "[]", '{"api":[]}', '{"api":{"$device.name":{"value":1,"error":"x"}}}', '{"fetch":[null]}', '{"dataSource":[{"url":"https://example.com"}]}']) assert.throws(() => parseMocks(value));
});

test("project export contains no preview mocks or mock health values", async () => {
  const project = createProject("Mock example");
  assert.deepEqual(parseMocks(project.fixtures), parseMocks(defaultFixtures));
  const archive = exportPackage(project.files);
  assert.equal(archive.error, undefined);
  const imported = await importPackage(archive.bytes!);
  assert.equal(imported.error, undefined);
  assert.deepEqual(Object.keys(imported.files!).sort(), Object.keys(project.files).sort());
  assert.ok(!Object.keys(imported.files!).some((key) => /fixture|mock/i.test(key)));
});
