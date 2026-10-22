import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import { executePackageInNode } from "../src/node.js";
import { runtimeContract } from "../src/contract.js";
import { scriptWidgetAPI } from "../../../Editor/editorfe/src/scriptWidgetAPI.js";
import { parseRotation3D } from "../src/render/props.js";

test("material styles and budget align with native and Studio metadata", () => {
  const swift=fs.readFileSync(new URL("../../../Shared/ScriptWidgetRuntime/Widget/Component/Attributes/General/ScriptWidgetAttributeBackgroundModifier.swift",import.meta.url),"utf8");
  const cases=/case (ultraThin[^\n]*)/.exec(swift)[1].split(",").map(value=>value.trim());
  assert.deepEqual(scriptWidgetAPI.globalProperties.backgroundMaterial.values,["none",...cases]);
  assert.equal(runtimeContract.maximumMaterialBackgrounds,4);
});
test("four public material regions are allowed, five fail before drawing, ignored/none values stay compatible", async () => {
  for (const value of ["ultraThin","thin","regular","thick","ultraThick","none","unknown"]) {
    for (const count of [4,5]) {
      const source='$render(<vstack>'+`<text backgroundMaterial="${value}">A</text>`.repeat(count)+'</vstack>);';
      const result=await executePackageInNode({files:{"main.jsx":source}});
      if(count===5 && !["none","unknown"].includes(value)) { assert.equal(result.error?.kind,"resourceLimit"); assert.match(result.error.message,/4-material/); assert.equal(result.tree,null); }
      else { assert.equal(result.error,null); assert.ok(result.tree); }
    }
  }
  const ignored=await executePackageInNode({files:{"main.jsx":'$render(<vstack>'+ '<spacer backgroundMaterial="thin"/>'.repeat(5)+'</vstack>);'}});
  assert.equal(ignored.error,null);
});
test("material budgets do not depend on user-replaceable array/string prototype methods", async () => {
  const result=await executePackageInNode({files:{"main.jsx":'Array.prototype.includes=()=>false;String.prototype.toLowerCase=()=>"spacer";$render(<vstack>'+ '<text backgroundMaterial="thin">A</text>'.repeat(5)+'</vstack>);'}});
  assert.equal(result.error?.kind,"resourceLimit"); assert.match(result.error.message,/4-material/);
});
test("static 3D depth rejects malformed, nonfinite and zero axes without producing invalid CSS", () => {
  for(const value of ["nan,1,0,0","inf,1,0,0","5,inf,0,0","5,0,nan,0","5,0,0,0","5,bad,0,1","5,1,0","5,1,0,0,2"]) assert.equal(parseRotation3D(value),null,value);
  assert.deepEqual(parseRotation3D("365, 0, 2, 0"),{degree:5,x:0,y:1,z:0});
  assert.deepEqual(parseRotation3D("5,1e308,-1e308,0"),{degree:5,x:1,y:-1,z:0});
});
