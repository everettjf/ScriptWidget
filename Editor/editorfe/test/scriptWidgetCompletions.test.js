import test from "node:test";
import assert from "node:assert/strict";
import { scriptWidgetCompletionOptions, scriptWidgetCompletions } from "../src/scriptWidgetCompletions.js";

function context(text, explicit = false) {
  return {
    pos: text.length,
    explicit,
    state: { doc: { sliceString: (from, to) => text.slice(from, to) } },
    matchBefore(pattern) {
      const match = text.match(pattern);
      if (!match || match.index + match[0].length !== text.length) return null;
      return { from: match.index, to: text.length, text: match[0] };
    },
  };
}

test("component completions appear after an opening JSX bracket", () => {
  const result = scriptWidgetCompletions(context("const view = <VS"));
  assert.equal(result.from, "const view = <".length);
  assert.ok(result.options.some((option) => option.label === "VStack"));
});

test("component completions stay quiet in ordinary JavaScript", () => {
  assert.equal(scriptWidgetCompletions(context("const value")), null);
});

test("completion labels are unique", () => {
  const labels = scriptWidgetCompletionOptions.map((option) => option.label);
  assert.equal(new Set(labels).size, labels.length);
});

test("component properties are completed from the API schema", () => {
  const result = scriptWidgetCompletions(context("<Progress val"));
  assert.ok(result.options.some((option) => option.label === "value"));
  assert.ok(result.options.some((option) => option.label === "padding"));
});

test("enum values are completed from the API schema", () => {
  const result = scriptWidgetCompletions(context('<Progress style="cir'));
  assert.ok(result.options.some((option) => option.label === "circular"));
});

test("XML parser is completed in JavaScript", () => {
  const result = scriptWidgetCompletions(context("const feed = $xml.pa"));
  assert.equal(result.from, "const feed = $xml.".length);
  assert.ok(result.options.some((option) => option.label === "parse"));
});

test("data namespaces complete methods with return types and permission guidance", () => {
  for (const [namespace, method, detail] of [["health", "stepCountToday", "Promise<json>"], ["location", "current", "Promise<json>"], ["device", "battery", "json"], ["system", "locale", "string"]]) {
    const text = `const value = $${namespace}.`;
    const result = scriptWidgetCompletions(context(text));
    assert.equal(result.from, text.length);
    const option = result.options.find((item) => item.label === method);
    assert.ok(option, namespace);
    assert.equal(option.detail, detail);
    assert.ok(option.info.length > 20);
  }
  assert.equal(scriptWidgetCompletions(context("$unknown.")), null);
  assert.deepEqual(scriptWidgetCompletions(context("$dataSource.req")).options.map((item) => item.label), ["request"]);
});

test("package file presence and existing text readers are completed with bounded local semantics",()=>{
 const options=scriptWidgetCompletions(context("$file.")).options;
 assert.deepEqual(options.map(item=>item.label).sort(),["exists","read","readJSON"]);
 assert.equal(options.find(item=>item.label==="exists").detail,"boolean");
 assert.match(options.find(item=>item.label==="exists").info,/inside this package/);
});
