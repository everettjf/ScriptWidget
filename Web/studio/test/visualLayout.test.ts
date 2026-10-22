import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { EditorState } from "@codemirror/state";
import { exportPackage, importPackage, newManifest } from "../../preview-engine/src/package/index.js";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { parseVisualLayout, editVisualLayout } from "../../../Editor/editorfe/src/visualLayout.js";
import { parseWidgetTheme, editWidgetTheme, widgetThemePresets } from "../../../Editor/editorfe/src/widgetTheme.js";

test("visual edits survive Package 2.0 export/import with all unrelated source and binary files intact", async () => {
  const source = '// Keep comments\nconst day="Monday";\n$render(<vstack spacing="8"><text>Hello</text><text>{day}</text></vstack>);\n';
  const model = parseVisualLayout(source), layer = model.nodes.find(node => node.text === "Hello")!;
  const edit = editVisualLayout(model,source,{type:"text",id:layer.id,value:'Safe <text> "literal" & {day}'});
  const changed = EditorState.create({doc:source}).update({changes:edit.changes}).state.doc.toString();
  const files = {"main.jsx":changed,"widget.json":JSON.stringify(newManifest("Layout roundtrip")),"lib/helper.js":"// user code\nexport const keep=1;\n","image/custom.bin":new Uint8Array([1,2,3])};
  const archive = exportPackage(files); assert.equal(archive.error,undefined);
  const imported = await importPackage(archive.bytes!); assert.equal(imported.error,undefined);
  assert.equal(imported.files["main.jsx"],changed);
  assert.equal(imported.files["lib/helper.js"],files["lib/helper.js"]);
  assert.deepEqual(imported.files["image/custom.bin"],files["image/custom.bin"]);
  const result = await executePackageInNode({files:imported.files});
  assert.equal(result.error,null); assert.match(result.tree!,/Safe <text>/); assert.match(result.tree!,/Monday/);
  assert.equal(Object.keys(imported.files).length,4);
  assert.ok(!Object.keys(imported.files).some(path=>/visual|layout-model|selection/.test(path)));
});

test("source model IDs are local editor state and models are recomputed after external code changes", () => {
  const first = '$render(<text>Before</text>);', model = parseVisualLayout(first);
  const second = '// External edit\n$render(<text>After</text>);';
  assert.throws(()=>editVisualLayout(model,second,{type:"text",id:model.roots[0]!,value:"bad"}),/changed/);
  const updated = parseVisualLayout(second); assert.equal(updated.nodes[0]!.text,"After");
});

test("Layout Starter changes match the real native editor and JavaScriptCore renderer", async () => {
  const fixture = JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/layout-edit-trees.json",import.meta.url),"utf8"));
  const root = new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Layout Starter/",import.meta.url);
  const original = fs.readFileSync(new URL("main.jsx",root),"utf8");
  assert.equal(fixture.examples.before.source,original);
  let model = parseVisualLayout(original), selected = model.nodes.find(node=>node.text==="Make today yours")!;
  let edit = editVisualLayout(model,model.source,{type:"text",id:selected.id,value:"A calmer day"});
  let changed = EditorState.create({doc:model.source}).update({changes:edit.changes}).state.doc.toString();
  model = parseVisualLayout(changed);
  edit = editVisualLayout(model,changed,{type:"property",id:model.roots[0]!,name:"alignment",value:"trailing"});
  changed = EditorState.create({doc:changed}).update({changes:edit.changes}).state.doc.toString();
  assert.equal(changed,fixture.examples.after.source);
  for (const phase of ["before","after"]) {
    const result = await executePackageInNode({files:{"main.jsx":fixture.examples[phase].source,"widget.json":fs.readFileSync(new URL("widget.json",root),"utf8")},environments:{"widget-size":"medium"}});
    assert.equal(result.error,null); assert.equal(result.tree,fixture.examples[phase].tree,phase);
  }
});

test("themes edited in real native WKWebView render identically on Web and survive package export", async () => {
  const fixture = JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/theme-edit-trees.json",import.meta.url),"utf8"));
  assert.equal(fixture.formatVersion,1);
  assert.deepEqual(Object.keys(fixture.examples).sort(), Object.keys(widgetThemePresets).sort());
  const original = fixture.examples.Meadow.source as string;
  for (const [name, tokens] of Object.entries(widgetThemePresets)) {
    const model = parseWidgetTheme(original);
    assert.equal(model.issue, "");
    const edit = editWidgetTheme(model, original, tokens);
    const changed = EditorState.create({doc:original}).update(edit).state.doc.toString();
    assert.equal(changed, fixture.examples[name].source, name);
    const files = {"main.jsx":changed,"widget.json":JSON.stringify(newManifest("Theme parity")),"images/keep.bin":new Uint8Array([4,5,6])};
    const archive = exportPackage(files); assert.equal(archive.error, undefined);
    const imported = await importPackage(archive.bytes!); assert.equal(imported.error, undefined);
    assert.equal(imported.files["main.jsx"], changed); assert.deepEqual(imported.files["images/keep.bin"], files["images/keep.bin"]);
    const result = await executePackageInNode({files: imported.files, environments:{"widget-size":"medium"}});
    assert.equal(result.error,null); assert.equal(result.tree,fixture.examples[name].tree,name);
  }
});
