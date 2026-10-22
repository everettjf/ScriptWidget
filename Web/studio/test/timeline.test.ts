import assert from "node:assert/strict";
import test from "node:test";
import { newManifest } from "../../preview-engine/src/package/index.js";
import { timelinePreview, timelineInputValue } from "../src/timelinePreview.ts";

test("preview uses scheduled slot with its declared zone and marks fixed time as read-only", () => {
  const manifest = { ...newManifest("Theme"), timeline: {dailyTimes:["06:00","12:00","18:00","22:00"],timeZone:"UTC"} };
  const fixed = timelinePreview(manifest, "2026-01-01T13:00:00Z");
  assert.equal(fixed.environments["timeline-slot"], "1");
  assert.equal(fixed.environments["timeline-is-projection"], "true");
  assert.equal(fixed.environments["timeline-date"], "2026-01-01T13:00:00.000Z");
  const live = timelinePreview(manifest, "", new Date("2026-01-01T13:00:00Z"));
  assert.equal(live.environments["timeline-is-projection"], "false");
  assert.throws(() => timelinePreview(manifest, "invalid"), /valid timeline date/);
  assert.equal(timelineInputValue("invalid"), "");
});

test("fixed time is host preview state and does not rewrite package sources or clock globals", () => {
  const manifest = newManifest("Legacy");
  const before = JSON.stringify(manifest);
  const clock = Date.now;
  const projected = timelinePreview(manifest, "2026-01-01T00:00:00Z");
  assert.equal(projected.environments["timeline-slot"], "-1");
  assert.equal(JSON.stringify(manifest), before);
  assert.equal(Date.now, clock);
});
