import assert from "node:assert/strict";
import test from "node:test";
import type { Permission } from "../../preview-engine/src/types.js";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { newManifest } from "../../preview-engine/src/package/index.js";
import { defaultFixtures, parseMocks, permissionScenario, setResponse } from "../src/mockData.ts";

const run = (source: string, permissions: Permission[] = ["location", "calendar"], text = defaultFixtures) => executePackageInNode({
  files: { "main.jsx": source }, manifest: { ...newManifest("Location"), permissions }, fixtures: parseMocks(text),
});
const output = (result: Awaited<ReturnType<typeof run>>) => {
  assert.equal(result.error, null);
  return JSON.parse(JSON.parse(result.tree!).children[0]);
};

test("best-state location mocks cannot bypass the package permission", async () => {
  const result = await run(`
    let denied = 0;
    for(const call of [() => $location.current(), () => $location.requestAuthorization()]) {
      try { await call(); } catch(error) { if(String(error).includes('[permission_denied]')) denied++; }
    }
    $render(<text>{JSON.stringify({status:$location.authorizationStatus(),widget:$location.isAuthorizedForWidgetUpdates(),denied})}</text>);
  `, []);
  assert.deepEqual(output(result), { status: "undeclared", widget: false, denied: 2 });
});

test("widget authorization is independent of app authorization and mock coordinates", async () => {
  const text = permissionScenario(defaultFixtures, "location", "widgetDenied");
  const result = await run(`
    let message;
    try { await $location.current(); } catch(error) { message = String(error); }
    $render(<text>{JSON.stringify({status:$location.authorizationStatus(),widget:$location.isAuthorizedForWidgetUpdates(),message})}</text>);
  `, ["location"], text);
  const value = output(result);
  assert.equal(value.status, "authorizedWhenInUse");
  assert.equal(value.widget, false);
  assert.match(value.message, /widget_not_authorized/);
});

test("revoked or disabled location never returns the best-state coordinates", async () => {
  for (const scenario of ["denied", "unavailable"] as const) {
    const text = setResponse(permissionScenario(defaultFixtures, "location", scenario), "$location.current", { value: { latitude: 37, longitude: -122 } });
    const result = await run(`
      let received = false, message;
      try { await $location.current(); received = true; } catch(error) { message = String(error); }
      $render(<text>{JSON.stringify({received,widget:$location.isAuthorizedForWidgetUpdates(),message})}</text>);
    `, ["location"], text);
    const value = output(result);
    assert.equal(value.received, false);
    assert.equal(value.widget, false);
    assert.match(value.message, scenario === "denied" ? /permission_denied/ : /unavailable/);
  }
});

test("location and calendar reads share the bounded per-execution query budget", async () => {
  const source = `
    let allowed = 0, limited = 0;
    for(let index = 0; index < 10; index++) {
      try { if(index % 2) await $calendar.events(); else await $location.current(); allowed++; }
      catch(error) { if(String(error).includes('[query_limit]')) limited++; }
    }
    $render(<text>{JSON.stringify({allowed,limited})}</text>);
  `;
  for (let runIndex = 0; runIndex < 2; runIndex++) assert.deepEqual(output(await run(source)), { allowed: 8, limited: 2 });
});
