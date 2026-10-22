import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { executePackageInNode } from "../../preview-engine/src/node.js";
import { exportPackage, importPackage } from "../../preview-engine/src/package/index.js";
import { EditorState } from "@codemirror/state";
import { parseVisualLayout, editVisualLayout } from "../../../Editor/editorfe/src/visualLayout.js";

test("Material Study matches 48 native family/mode/appearance trees and retains editable material values through export", async () => {
  const root=new URL("../../../Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Material Study/",import.meta.url);
  const source=fs.readFileSync(new URL("main.jsx",root),"utf8"), manifest=fs.readFileSync(new URL("widget.json",root),"utf8");
  const fixture=JSON.parse(fs.readFileSync(new URL("../../preview-engine/test/parity/material-study-trees.json",import.meta.url),"utf8"));
  assert.equal(fixture.source,source); assert.equal(Object.keys(fixture.examples).length,48);
  for(const family of ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]) {
    for(const mode of ["fullColor","accented","vibrant"]) for(const appearance of ["light","dark"] as const) {
      const result=await executePackageInNode({files:{"main.jsx":source,"widget.json":manifest},environments:{"widget-size":family,"widget-rendering-mode":mode},preview:{appearance}});
      assert.equal(result.error,null); assert.equal(result.tree,fixture.examples[`${family}-${mode}-${appearance}`].tree);
    }
  }
  const model=parseVisualLayout(source), card=model.nodes.find(node=>node.properties.some(property=>property.name==="backgroundMaterial"))!;
  const edit=editVisualLayout(model,source,{type:"property",id:card.id,name:"backgroundMaterial",value:"regular"});
  const changed=EditorState.create({doc:source}).update({changes:edit.changes}).state.doc.toString();
  assert.equal(changed,source.replace('backgroundMaterial="thin"','backgroundMaterial={"regular"}'));
  const exported=exportPackage({"main.jsx":changed,"widget.json":manifest}); assert.equal(exported.error,undefined);
  const imported=await importPackage(exported.bytes!); assert.equal(imported.error,undefined); assert.equal(imported.files["main.jsx"],changed);
});
