import test from "node:test";
import assert from "node:assert/strict";
import { EditorState } from "@codemirror/state";
import { history, undo, redo, isolateHistory } from "@codemirror/commands";
import { parseWidgetTheme, initializeWidgetTheme, editWidgetTheme, importWidgetTheme, exportWidgetTheme, widgetThemePresets } from "../src/widgetTheme.js";
import { parseVisualLayout } from "../src/visualLayout.js";

const apply = (source, edit) => EditorState.create({doc: source}).update(edit).state.doc.toString();
const starter = '// My comment\n"use strict";\nconst title = "Hello";\n$render(<vstack background="#fff" spacing="8"><text font="headline">Title</text><text>{title}</text><icon systemName="star.fill"/></vstack>);\n// Footer';
const themed = () => apply(starter, initializeWidgetTheme(starter));
test("theme initialization preserves directives, comments, logic and dynamic values", () => {
  const source = themed(), model = parseWidgetTheme(source);
  assert.equal(model.issue, ""); assert.deepEqual(model.tokens, widgetThemePresets.Meadow);
  assert.ok(source.indexOf('"use strict";') < source.indexOf("const widgetTheme"));
  assert.ok(source.includes('const title = "Hello";')); assert.ok(source.endsWith("// Footer"));
  assert.ok(source.includes('<text font={widgetTheme.bodyFont} color={widgetTheme.muted} fontDesign={widgetTheme.fontDesign}>{title}</text>'));
  const layout = parseVisualLayout(source);
  assert.ok(!layout.nodes[0].properties.some(value => value.name === "fontDesign"));
  assert.ok(layout.nodes.filter(node => node.component === "Text").every(node => node.properties.some(value => value.name === "fontDesign")));
  assert.equal(parseVisualLayout(source).issue, "");
  assert.throws(() => initializeWidgetTheme(source), /literal top-level/);
  const dynamic = '$render(<vstack background={getColor()}><text color={getInk()}>A</text></vstack>);';
  const next = apply(dynamic, initializeWidgetTheme(dynamic));
  assert.ok(next.includes('background={getColor()}')); assert.ok(next.includes('color={getInk()}'));
});
test("all presets update only literal ranges, round trip as JSON, and use normal undo/redo", () => {
  const source = themed();
  let state = EditorState.create({doc:source, extensions:[history()]});
  const target = {state,dispatch(transaction) { state = transaction.state; target.state = state; }};
  for (const tokens of Object.values(widgetThemePresets)) {
    assert.deepEqual(importWidgetTheme(exportWidgetTheme(tokens)).tokens, tokens);
    const before = state.doc.toString(), model = parseWidgetTheme(before);
    const edit = editWidgetTheme(model, before, tokens);
    if (!edit.changes.length) continue;
    target.dispatch(state.update({...edit, annotations:isolateHistory.of("full")}));
    const after = state.doc.toString();
    assert.deepEqual(parseWidgetTheme(after).tokens, tokens);
    assert.equal(undo(target), true); assert.equal(state.doc.toString(), before);
    assert.equal(redo(target), true); assert.equal(state.doc.toString(), after);
    assert.ok(after.includes('// My comment\n"use strict";')); assert.ok(after.endsWith("// Footer"));
  }
  assert.throws(() => editWidgetTheme(parseWidgetTheme(source), source + " ", widgetThemePresets.Paper), /changed/);
});
test("unsupported declarations, shadowing and writes preserve code and disable theme edits", () => {
  const source = themed();
  for (const suffix of ['widgetTheme.padding = 2;', 'widgetTheme.padding++;', 'delete widgetTheme.padding;', 'const alias = widgetTheme;', 'function f(widgetTheme) {}', 'widgetTheme["padding"];', 'widgetTheme.unknown;', 'widgetTheme.padding.call();', '({x: widgetTheme.padding} = obj);', '(widgetTheme.padding) = 2;', 'for (widgetTheme.padding of items) {}']) {
    const code = source + "\n" + suffix, model = parseWidgetTheme(code);
    assert.notEqual(model.issue, "", suffix); assert.equal(model.source, code);
    assert.throws(() => editWidgetTheme(model, code, widgetThemePresets.Paper));
  }
  for (const code of [source.replace('"padding": 16', '"padding": getPadding()'), source.replace('"padding": 16', '"padding": 16, padding: 2'), source.replace('const widgetTheme', 'let widgetTheme'), source.replace('"padding": 16', '...extra')]) assert.notEqual(parseWidgetTheme(code).issue, "");
  for (const code of ['function f() {$render(<vstack/>);}', 'if (ok) {$render(<vstack/>);}', '$render(<Custom/>);', '$render(<vstack/>);$render(<hstack/>);', 'const widgetTheme = {};']) assert.equal(parseWidgetTheme(code).canInitialize, false);
});
test("theme JSON and tokens reject unknown keys, unsafe values, versions and oversized input", () => {
  const value = JSON.parse(exportWidgetTheme(widgetThemePresets.Meadow));
  for (const tokens of [{...value.tokens, extra:1}, {...value.tokens, padding:-1}, {...value.tokens, spacing:33}, {...value.tokens, foreground:'url(https://example.test)'}, {...value.tokens, fontDesign:'custom'}, {...value.tokens, corner:Infinity}, JSON.parse('{"__proto__":1}')]) {
    assert.throws(() => importWidgetTheme(JSON.stringify({...value, tokens})));
  }
  for (const invalid of [{...value,formatVersion:2}, {...value,extra:1}, {...value,name:""}, {...value,name:"a".repeat(65)}]) assert.throws(() => importWidgetTheme(JSON.stringify(invalid)));
  assert.throws(() => importWidgetTheme(" ".repeat(4097)), /4 KiB/);
  assert.notEqual(parseWidgetTheme(" ".repeat(512 * 1024 + 1)).issue, "");
});
