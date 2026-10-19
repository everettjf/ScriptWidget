import assert from "node:assert/strict";
import test from "node:test";
import { hexColor, parseColor, parseFont, parseFrame, parsePadding, parseGradient, propReader, setPlatform, swiftDouble, systemBackground } from "../src/render/props.js";
import { FixedNode, FlexibleNode, SpacerNode, StackNode, TextNode } from "../src/render/layout.js";
import { lineHeight } from "../src/render/renderer.js";
import { deviceProfiles } from "../src/render/profiles.js";
import { symbolMetrics } from "../src/render/symbolMetrics.generated.js";
import { hyphenationPoints } from "../src/render/hyphenate.js";

const frame = (value) => parseFrame(propReader({ frame: value }));

test("frame parsing keeps the native quirks", () => {
  assert.deepEqual(frame("max"), { mode: "max", alignment: "center", width: 0, height: 0 });
  assert.deepEqual(frame("max,topLeading"), { mode: "max", alignment: "topLeading", width: 0, height: 0 });
  assert.deepEqual(frame("10,20,bottom"), { mode: "size", alignment: "bottom", width: 10, height: 20 });
  assert.equal(frame("max,20").mode, "height");
  assert.equal(frame("10,max").mode, "width");
  assert.equal(frame(30).mode, "size");
  assert.equal(frame("10, 20").mode, "none");
  assert.equal(frame(true).mode, "none");
});

test("padding accepts strings only", () => {
  assert.deepEqual(parsePadding(propReader({ padding: "12" })), [12, 12, 12, 12]);
  assert.deepEqual(parsePadding(propReader({ padding: "horizontal,20" })), [0, 20, 0, 20]);
  assert.deepEqual(parsePadding(propReader({ padding: "4,8,12,16" })), [4, 8, 12, 16]);
  assert.equal(parsePadding(propReader({ padding: 30 })), null);
  assert.equal(parsePadding(propReader({ padding: "1,2,3" })), null);
});

test("colors follow Color(hex:) and the iOS 26 system palette", () => {
  assert.deepEqual(hexColor("#ff0000"), [255, 0, 0, 1]);
  assert.deepEqual(hexColor("#80ff0000"), [255, 0, 0, 128 / 255]);
  assert.deepEqual(hexColor("#fff"), [1, 1, 1, 1 / 255]);
  assert.deepEqual(parseColor("blue"), [0, 136, 255, 1]);
  assert.deepEqual(parseColor("red,0.5"), [255, 56, 60, 0.5]);
  assert.equal(parseColor("nonsense"), null);
  assert.equal(parseColor("a,b,c"), null);
  assert.equal(parseGradient("gradient:{bad").type, "linear");
});

test("fonts and numbers parse like Swift", () => {
  assert.deepEqual(parseFont("title,bold"), { size: 28, lineHeight: 34, weight: 700, design: "default", textStyle: "title" });
  assert.deepEqual(parseFont("20,bold,rounded"), { size: 20, lineHeight: null, weight: 700, design: "rounded" });
  assert.equal(parseFont("custom,Menlo,15").family, "Menlo");
  assert.equal(parseFont("huge"), null);
  assert.equal(swiftDouble(" 1"), null);
  assert.equal(swiftDouble("1e3"), 1000);
  assert.equal(propReader({ a: 1 }).bool("a"), true);
  assert.equal(propReader({ a: 1.5 }).int("a"), null);
  assert.equal(propReader({ a: "yes" }).bool("a"), true);
});

test("single-line text heights match iOS measurements", () => {
  // Measured with BrowserPreviewParityTests snapshots on the iOS 27 simulator.
  const measured = { 34: 41, 28: 33.5, 22: 26.5, 20: 24, 17: 20.5, 16: 19.5, 15: 18, 13: 16, 12: 14.5, 11: 13.5, 10: 12, 14: 17, 24: 29, 30: 36, 40: 48, 50: 60, 60: 72 };
  for (const [size, height] of Object.entries(measured)) assert.equal(lineHeight(Number(size)), height, `font size ${size}`);
});

test("stacks give spacers only the leftover space", () => {
  const fakeMeasurer = { measure: (text, style, width) => ({ width: Math.min(width ?? Infinity, text.length * 10), lines: width === null ? 1 : Math.ceil((text.length * 10) / Math.max(width, 1)) }), ellipsisWidth: () => 10 };
  const style = { natural: 20, leading: 22, size: 17 };
  const label = new TextNode("abcdefghij", style, fakeMeasurer);
  const stack = new StackNode("h", [label, new SpacerNode("h"), new FixedNode(20, 20)], { alignment: "center", spacing: () => 0 });
  stack.place(0, 0, 200, 40);
  assert.equal(label.frame.width, 100);
  assert.equal(stack.children[1].frame.width, 80);
  const tight = new StackNode("h", [new FixedNode(150, 10), new TextNode("abcdefghij", style, fakeMeasurer)], { alignment: "center", spacing: () => 8 });
  tight.place(0, 0, 200, 20);
  // Truncated text reports the width it draws ("abc…"), as SwiftUI does.
  assert.equal(tight.children[1].frame.width, 40);
  assert.equal(new FlexibleNode().size(null, null)[0], 10);
});

test("text narrower than an ellipsis draws itself clipped when one line fits", () => {
  // Measured with case/narrow-text-* on the iOS 27 simulator: BEIJING in a
  // 9-point, one-line frame draws "Bl" cut at the edge, not a clipped "…".
  const measurer = { measure: (text) => ({ width: [...text].length * 6, lines: 1 }), ellipsisWidth: () => 10 };
  const style = { natural: 14, leading: 16, size: 12 };
  const oneLine = new TextNode("BEIJING", style, measurer).layout(9, 16);
  assert.deepEqual([oneLine.text, oneLine.clip, oneLine.width], ["BEIJING", true, 9]);
  // With room for more lines and not even the first character fitting, a
  // clipped "…" as before.
  assert.equal(new TextNode("BEIJING", style, measurer).layout(4, 100).text, "…");
});

test("the macOS profile uses macOS 26 SwiftUI metrics", () => {
  assert.equal(deviceProfiles.macos.platform, "macos");
  assert.deepEqual(deviceProfiles.macos.medium, [329, 170]);
  const previous = setPlatform("macos");
  try {
    // Measured by Tools/ScriptWidgetPreview with NSHostingController at 2x.
    const measured = { 10: 13, 13: 16, 15: 19, 16: 19, 17: 20, 20: 24, 30: 35, 60: 71, 16.5: 20, 20.5: 25 };
    for (const [size, height] of Object.entries(measured)) assert.equal(lineHeight(Number(size)), height, `font size ${size}`);
    assert.deepEqual(parseFont("body"), { size: 13, natural: 16, lineHeight: 16, weight: 400, gap: 1, design: "default", textStyle: "body" });
    assert.equal(parseFont("headline").weight, 700);
    assert.deepEqual(parseColor("primary"), [0, 0, 0, 0.847]);
    assert.deepEqual(parseColor("gray", "dark"), [152, 152, 157, 1]);
    assert.deepEqual(systemBackground("dark"), [46, 46, 46, 1]);
  } finally {
    setPlatform(previous);
  }
  assert.equal(lineHeight(13), 16);
  assert.deepEqual(parseColor("primary"), [0, 0, 0, 1]);
});

test("text pushes out orphans like TextKit; macOS breaks long words without hyphens", () => {
  const measurer = { measure: (text, style, width) => ({ width: Math.max(...text.split("\n").map((line) => line.length * 10)), lines: text.split("\n").length }), ellipsisWidth: () => 10 };
  const mac = { natural: 16, leading: 16, size: 13, hyphenate: false };
  // Push-out (TextKit .standard): two lines, the moved line fits, and the
  // first line stays at least 55% as wide as the new last line.
  assert.equal(new TextNode("October 18, 2026", mac, measurer).displayText(110), "October\n18, 2026");
  assert.equal(new TextNode("Hello from GitHubbb", mac, measurer).displayText(110), "Hello from GitHubbb");
  assert.equal(new TextNode("ab cdefgh ij", mac, measurer).displayText(90), "ab cdefgh ij");
  assert.equal(new TextNode("aaa bbb ccc ddd eee f", mac, measurer).displayText(70), "aaa bbb ccc ddd eee f");
  assert.equal(new TextNode("Rain · 58° today", mac, measurer).displayText(100), "Rain ·\n58° today");
  assert.equal(new TextNode("Wideness Size : small", mac, measurer).displayText(150), "Wideness\nSize\u00a0: small");
  assert.equal(new TextNode("SYSTEM", mac, measurer).displayText(30), "SYSTEM");
  assert.equal(new TextNode("TUE", mac, measurer).wrapsCharacters(10), true);
  const ios = { ...mac, hyphenate: true };
  // iOS text styles hyphenate at dictionary breaks; other fonts break
  // between characters.
  assert.equal(new TextNode("SYSTEM", ios, measurer).displayText(40), "SYS-\nTEM");
  assert.equal(new TextNode("Departure gate", ios, measurer).displayText(70), "Depar-\nture gate");
  assert.equal(new TextNode("Departure gate", mac, measurer).displayText(70), "Departure gate");
  assert.equal(new TextNode("SYSTEM", ios, measurer).displayText(20), "SYSTEM");
  assert.equal(new TextNode("把今天过得有意义", ios, measurer).displayText(30), "把今天过得有意义");
  // CJK characters are break units for push-out too: "今年还 / 剩" -> "今年 / 还剩".
  assert.equal(new TextNode("今年还剩", ios, measurer).displayText(30), "今年\n还剩");
});

test("SF Symbol metrics come from SwiftUI", () => {
  assert.deepEqual(symbolMetrics.hourglass, [0.825, 1.07]);
  assert.deepEqual(symbolMetrics.globe, [1.17, 1.17]);
});

test("symbol stand-ins are measured symbols drawn with well-formed SVG", async () => {
  const { symbolShapes } = await import("../src/render/symbolShapes.js");
  for (const [name, shape] of Object.entries(symbolShapes)) {
    assert.ok(symbolMetrics[name], `${name} has SwiftUI metrics`);
    const markup = shape("m1");
    assert.ok(markup.length > 0 && !markup.includes("undefined") && !markup.includes("NaN"), name);
    // Every mask a stand-in uses is defined with the id it was given.
    for (const [, id] of markup.matchAll(/url\(#([^)]+)\)/g)) assert.ok(markup.includes(`id="${id}"`), `${name} defines ${id}`);
  }
});

test("hyphenation follows the TeX patterns Apple uses", () => {
  const hyphenated = (word) => { let out = ""; let last = 0; for (const point of hyphenationPoints(word)) { out += `${word.slice(last, point)}-`; last = point; } return out + word.slice(last); };
  // Matched against CFStringGetHyphenationLocationBeforeIndex.
  assert.equal(hyphenated("Information"), "In-for-ma-tion");
  assert.equal(hyphenated("Departure"), "De-par-ture");
  assert.equal(hyphenated("ScriptWidget"), "Script-Wid-get");
  assert.equal(hyphenated("achiever"), "achiev-er");
  assert.equal(hyphenated("PROGRESS"), "PROGRESS");
  assert.deepEqual(hyphenationPoints("365"), []);
});
