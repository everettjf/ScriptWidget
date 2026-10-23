import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { clockPeriod, clockPhase, swingDuration, swingDistance, swingPhase } from "../src/render/animation.js";

test("public clock phases match 128 actual native cases across timezones and DST", () => {
  const corpus = JSON.parse(fs.readFileSync(new URL("./parity/public-animation-phases.json",import.meta.url),"utf8"));
  assert.equal(corpus.length,128);
  for (const value of corpus) assert.ok(Math.abs(clockPhase(value)-value.angle)<0.00002,JSON.stringify(value));
});
test("signed custom periods keep the half-turn convention and finite bounds", () => {
  assert.equal(clockPeriod(-0.01),-0.25); assert.equal(clockPeriod(0),0.25);
  for (const value of [NaN,Infinity,-Infinity]) assert.equal(clockPeriod(value),10);
  for (const [interval,angle] of [[10,90],[-10,-90]]) assert.equal(clockPhase({type:"clock",interval,date:978307205000,timezone:"UTC"}),angle);
  assert.ok(Number.isFinite(clockPhase({type:"clock",interval:1e308,date:Date.now()})));
});
test("swing rests at zero, respects signed distance and handles extreme inputs", () => {
  for (const [time,position] of [[0,0],[0.5,10],[1,0],[1.5,-10],[2,0]]) assert.ok(Math.abs(swingPhase(time,1,10)-position)<0.00001);
  assert.equal(swingPhase(0.5,1,-10),-10);
  for(const value of [NaN,Infinity,-Infinity]) assert.equal(swingPhase(value,1,10),0);
  assert.ok(Number.isFinite(swingPhase(1e308,0.1,1e308)));
  assert.equal(swingDuration(-1),1);assert.equal(swingDuration(1e308),86400);assert.equal(swingDistance(1e308),10000);
});
test("invalid dates are static and invalid timezones use the local fallback", () => {
  for(const date of [NaN,Infinity,-Infinity,1e308,-1e308]) assert.equal(clockPhase({type:"clock",date}),0);
  assert.equal(clockPhase({type:"clockSecond",date:978307215000,timezone:"not/a/zone"}),clockPhase({type:"clockSecond",date:978307215000}));
  assert.equal(clockPhase({type:"unknown",date:Date.now()}),0);
});
